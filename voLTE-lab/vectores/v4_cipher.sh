#!/bin/sh
# ============================================================================
# v4_cipher.sh — V4 Robustez del cifrado radio (CVSS 7.5, MITRE T1040).
# Objetivo: demostrar EEA0 (claro, RTP legible) vs EEA2 (AES-CTR-128, ilegible).
# Modos: check (estado actual) / capture (captura ogstun en llamada activa) /
#   compare (guía + captura comparativa EEA0 vs EEA2 conmutando enb.conf).
# Requiere: lab UP + plano de usuario GTP (lab-up.sh paso 13, ogstun UP).
#   El plano solo es usable en ventana CONNECTED post-attach (Service Request
#   causa 9 en IDLE); hacer la llamada justo antes de capturar.
# Uso: ./v4_cipher.sh
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v4] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}
mkdir -p results; touch results/hashes.txt 2>/dev/null || true

show_state() {
  log "EEA preferido eNB (config repo):"
  grep -a "eea_pref_list\|eia_pref_list" srsran/enb-config/enb.conf || true
  log "EEA efectivo en eNB vivo:"
  docker exec srsenb sh -c "grep -a -h 'eea_pref_list' /root/enb-config/enb.conf 2>/dev/null" || true
  log "SecurityMode negociado (log eNB en vivo):"
  docker exec srsenb sh -c "strings /tmp/enb.log 2>/dev/null | grep -a -iE 'eea|SecurityMode|security.*mode|cipher' | tail -n 5" || true
  log "ogstun (plano GTP) en open5gs:"
  docker exec open5gs sh -c "ip link show ogstun 2>&1 | head -n 2; ip -o addr show ogstun 2>/dev/null" || true
}

capture_ogstun() {
  # $1 = etiqueta (eea0|eea2), $2 = duración
  TAG="$1"; DUR="$2"
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  log "Capture [$TAG] en ogstun durante llamada activa ($DUR s)..."
  log ">> Inicie AHORA una llamada VoLTE (1001->1000) y manténgala $DUR s."
  docker exec -d open5gs sh -c "timeout $DUR tcpdump -i ogstun -w /tmp/v4_${TAG}_$TS.pcap udp > /tmp/v4cap.log 2>&1"
  sleep "$DUR"; sleep 3
  docker cp open5gs:/tmp/v4_${TAG}_$TS.pcap "/tmp/v4_${TAG}_$TS.pcap"
  cp "/tmp/v4_${TAG}_$TS.pcap" "results/v4_cipher_${TAG}_$TS.pcap"
  docker cp "/tmp/v4_${TAG}_$TS.pcap" "kali:/root/results/v4_cipher_${TAG}_$TS.pcap" 2>/dev/null || true
  # Kali tiene el volumen results/ montado; normalizar ruta para análisis:
  docker exec kali sh -c "ls -la /root/results/v4_cipher_${TAG}_$TS.pcap" 2>/dev/null || log "(pcap en ./results/ del host)"
  log "--- streams RTP [$TAG] ---"
  docker exec kali sh -c "tshark -r /root/results/v4_cipher_${TAG}_$TS.pcap -q -z rtp,streams 2>/dev/null | head -n 8" || \
    tshark -r "results/v4_cipher_${TAG}_$TS.pcap" -q -z rtp,streams 2>/dev/null | head -n 8 || true
  H=$(docker exec kali sh -c "sha256sum /root/results/v4_cipher_${TAG}_$TS.pcap 2>/dev/null | cut -d' ' -f1" || sha256sum "results/v4_cipher_${TAG}_$TS.pcap" | cut -d' ' -f1)
  echo "$H  v4_cipher_${TAG}_$TS.pcap  V4  $(date -u +%Y-%m-%dT%H:%M:%SZ)  captura ogstun [$TAG] ${DUR}s" >> results/hashes.txt
  log "hash registrado: v4_cipher_${TAG}_$TS.pcap"
}

MODE=$(ask MODE "Modo: check (ver estado) / capture (ogstun, requiere GTP) / compare (EEA0 vs EEA2)" "check")
case "$MODE" in
  check)
    show_state
    log "Contramedida: encryption_algo EEA0 -> EEA2 (AES-CTR 128) en enb.conf (eea_pref_list = EEA2, EEA1, EEA0)."
    ;;
  capture)
    show_state
    DUR=$(ask DUR "Duración captura ogstun (s)" "60")
    capture_ogstun "current" "$DUR"
    ;;
  compare)
    show_state
    DUR=$(ask DUR "Duración por captura (s)" "60")
    log "Paso 1/2: captura con config ACTUAL (típicamente EEA0 = vulnerable)..."
    capture_ogstun "eea0" "$DUR"
    log "Paso 2/2: conmutar a EEA2. Edite srsran/enb-config/enb.conf:"
    log "  eea_pref_list = EEA2, EEA1, EEA0   (y eia_pref_list = EIA2, EIA1, EIA0)"
    log "  Luego: docker restart srsenb srsue (NO pkill: los sockets ZMQ se cuelgan) + re-attach + re-registrar (lab-up.sh pasos 8-13)."
    printf "¿Ya conmutó a EEA2 y re-registró? (yes/no) [no]: "
    read -r ans || ans=""
    [ -n "$ans" ] || ans="no"
    if [ "$ans" = "yes" ]; then
      show_state
      capture_ogstun "eea2" "$DUR"
      log "VEREDICTO esperado: eea0 -> RTP g711U legible/reconstruible; eea2 -> payload cifrado ininteligible."
      log "Comparar: tshark -r results/v4_cipher_eea0_*.pcap -q -z rtp,streams  VS  eea2."
    else
      log "Comparativa parcial guardada (eea0). Complete el paso EEA2 y repita en modo capture."
    fi
    ;;
  *) log "ERROR: modo $MODE inválido"; exit 1 ;;
esac
log "Contramedida: encryption_algo EEA0 -> EEA2 (AES-CTR 128) en enb.conf."
