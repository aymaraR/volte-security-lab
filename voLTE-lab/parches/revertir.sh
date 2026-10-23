#!/bin/sh
# ============================================================================
# revertir.sh — Deshace las contramedidas de parches/aplicar.sh y vuelve al
# estado vulnerable (UDP sin TLS/SRTP, sin pike, sin binding de identidad).
# Requiere lab UP. Restaura los archivos desde parches/vulnerable/.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[revertir] $*"; }

for c in kamailio asterisk srsue srsue2; do
  docker ps --format "{{.Names}}" | tr -d '\r' | grep -qx "$c" \
    || { log "ERROR: contenedor $c no corre"; exit 1; }
done

cp parches/vulnerable/pcscf.cfg kamailio/pcscf/pcscf.cfg
cp parches/vulnerable/scscf.cfg kamailio/scscf/scscf.cfg
cp parches/vulnerable/pjsip.conf asterisk/pjsip.conf
cp parches/vulnerable/accounts srsran/baresip-config/accounts
cp parches/vulnerable/config srsran/baresip-config/config
# baresip2: igual que 1001 pero con 1002/answermode (se regenera en lab-up);
# aquí basta volver a la versión vulnerable de accounts/config.
sed 's|1001@ims.mnc070.mcc999.3gppnetwork.org|1002@ims.mnc070.mcc999.3gppnetwork.org|; s|999070000000002|999070000000003|; s|ue1001pass123|ue1002pass123|; s|;regint=3600|;regint=3600;answermode=auto|' \
  parches/vulnerable/accounts > .lab-tmp/baresip2/accounts
cp parches/vulnerable/config .lab-tmp/baresip2/config
log "archivos restaurados al estado vulnerable"

# Kamailio: quitar tls.cfg/certs no es necesario (solo se usan si pcscf los carga).
docker exec kamailio pkill -f 'kamailio -DD' >/dev/null 2>&1 || true
sleep 3
for cfg in scscf icscf pcscf; do
  docker exec -d kamailio bash -c "kamailio -DD -E -e -f /usr/local/etc/kamailio/$cfg.cfg > /tmp/$cfg.log 2>&1"
done
sleep 10
log "Kamailio reiniciado (vulnerable)"

docker exec asterisk asterisk -rx "core stop now" >/dev/null 2>&1 || true
docker restart asterisk >/dev/null
sleep 3
docker exec -d asterisk bash -c "asterisk > /dev/null 2>&1"
sleep 8
log "Asterisk reiniciado (vulnerable)"

# baresip: modo bridge (V1/V2/V3/V7 no necesitan el túnel).
for c in srsue srsue2; do
  docker exec "$c" pkill -f tun_srsue >/dev/null 2>&1 || true
done
sleep 1
docker exec srsue pkill -x baresip >/dev/null 2>&1 || true
docker exec srsue2 pkill -x baresip >/dev/null 2>&1 || true
docker cp .lab-tmp/baresip2/accounts srsue2:/root/.baresip/accounts >/dev/null
docker cp .lab-tmp/baresip2/config srsue2:/root/.baresip/config >/dev/null
sleep 1
docker exec -d srsue bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1"
docker exec -d srsue2 bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip2.log 2>&1"
sleep 14
log "1001: $(docker exec srsue sh -c "grep -a '200 OK' /tmp/baresip.log | tail -n 1" || true)"
log "1002: $(docker exec srsue2 sh -c "grep -a '200 OK' /tmp/baresip2.log | tail -n 1" || true)"
log "revertido. Re-ejecutar V1/V2/V3/V7 para reproducir el estado vulnerable."
