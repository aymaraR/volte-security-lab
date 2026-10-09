#!/bin/sh
# ============================================================================
# lab-restore-bridge.sh — deja el lab en estado OPERATIVO tras un paso 13 fallido.
#
# Por que existe: el paso 13 de lab-up.sh (registro SIP via tunel GTP) falla de
# forma sistémica en este lab, y es una limitación DOCUMENTADA (ver README.md
# "Solucion de problemas frecuentes" y la seccion "Plano GTP" de kali.md):
# el MME rechaza el Service Request -> "Removed Session" + "Attach complete"
# -> el UPF asigna una IP nueva de tun_srsue cada ~60-90 s. Como la IP cambia
# entre que se lee y se escribe 'sip_listen', baresip queda con una IP muerta y
# falla con "Network is unreachable".
#
# El registro por BRIDGE (logica del paso 12 de lab-up.sh) no depende de esa IP
# y funciona siempre. Es el estado soportado para los vectores V1/V2/V3/V7, que
# no necesitan el plano de usuario.
#
# Es idempotente: se puede re-ejecutar cada vez que el paso 13 falle.
# ============================================================================
set -eu
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1

log() { echo "[restore-bridge] $*"; }
ql()  { "$@" >/dev/null 2>&1 || true; }

log "1/5 quitando lineas sip_listen stale (la IP del tun ya caduco)"
for c in srsue srsue2; do
  docker exec "$c" sh -c 'grep -a -v "^sip_listen" /root/.baresip/config > /tmp/c.def; cp /tmp/c.def /root/.baresip/config' \
    >/dev/null 2>&1 || true
done

log "2/5 borrando rutas al tun (fuerza el trafico SIP por eth0/bridge)"
for c in srsue srsue2; do
  docker exec "$c" sh -c 'ip route del 172.20.0.6/32 dev tun_srsue 2>/dev/null; ip route del 172.20.0.7/32 dev tun_srsue 2>/dev/null; true' \
    >/dev/null 2>&1 || true
done

log "3/5 reiniciando baresip"
docker exec srsue  pkill -x baresip >/dev/null 2>&1 || true
docker exec srsue2 pkill -x baresip >/dev/null 2>&1 || true
sleep 1
docker exec -d srsue  bash -c 'export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1'
docker exec -d srsue2 bash -c 'export HOME=/root; baresip -f /root/.baresip > /tmp/baresip2.log 2>&1'

log "4/5 esperando REGISTER 200 OK (hasta 60s)"
i=0; ok1=0; ok2=0
while [ "$i" -lt 60 ]; do
  docker exec srsue  grep -a -q '200 OK' /tmp/baresip.log  2>/dev/null && ok1=1
  docker exec srsue2 grep -a -q '200 OK' /tmp/baresip2.log 2>/dev/null && ok2=1
  [ "$ok1" = 1 ] && [ "$ok2" = 1 ] && break
  sleep 3; i=$((i + 3))
done
[ "$ok1" = 1 ] || { log "ERROR: 1001 no se registro"; exit 1; }
[ "$ok2" = 1 ] || { log "ERROR: 1002 no se registro"; exit 1; }
log "   1001 y 1002 registrados por bridge OK"

log "5/5 estado final"
docker exec asterisk asterisk -rx 'pjsip show registrations' 2>/dev/null \
  | grep -a -E 'Registered|Objects found' || log "   (asterisk sin registro en S-CSCF)"
docker ps --format 'table {{.Names}}\t{{.Status}}'
log "Lab OPERATIVO por bridge. Llamada de prueba:"
log "  docker exec -d srsue sh -c 'export HOME=/root; baresip -f /root/.baresip -e \"/dial 1000@ims.mnc070.mcc999.3gppnetwork.org\"'"
log "NOTA: si se necesita el plano de usuario (V4/V6), el tunel solo es usable"
log "      en la ventana CONNECTED post-attach, y la IP hay que releerla."