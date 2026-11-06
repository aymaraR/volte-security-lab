#!/bin/sh
# Aceptacion D5: verifica attach, IMS auth, GTP y evidencia.
set -eu
cd "$(dirname "$0")/.."

fail=0
ok() { echo "[OK] $*"; }
bad() { echo "[FAIL] $*"; fail=1; }

for c in srsue srsue2 srsenb srsenb2 open5gs kamailio asterisk pyhss_hss pyhss_api pyhss_diameter; do
  docker ps --format '{{.Names}}' | tr -d '\r' | grep -qx "$c" && ok "contenedor $c" || bad "contenedor $c ausente"
done

for c in srsue srsue2; do
  TUN=$(docker exec "$c" sh -c "ip -o addr show tun_srsue 2>/dev/null | grep -oE 'inet [0-9.]+' | cut -d' ' -f2" || true)
  [ -n "$TUN" ] && ok "$c tun=$TUN" || bad "$c sin tun"
done

for c in srsue srsue2; do
  OUT=$(docker exec "$c" sh -c "ping -I tun_srsue -c 5 -W 1 10.45.0.1" 2>/dev/null || true)
  echo "$OUT" | grep -q '0% packet loss' && ok "$c ping 0% loss" || bad "$c ping con perdida"
done

docker exec srsue sh -c "ip route get 172.20.0.6" | grep -q tun_srsue \
  && ok "UE1 ruta IMS por tunel" || bad "UE1 ruta IMS no usa tunel"

docker exec srsue sh -c "grep -a -q '200 OK' /tmp/baresip.log" \
  && ok "1001 REGISTER 200" || bad "1001 sin 200"
docker exec srsue2 sh -c "grep -a -q '200 OK' /tmp/baresip2.log" \
  && ok "1002 REGISTER 200" || bad "1002 sin 200"

docker exec asterisk asterisk -rx "pjsip show registrations" 2>/dev/null | grep -qi 'Registered' \
  && ok "Asterisk registrado" || bad "Asterisk sin registro"

docker logs --since 10m open5gs 2>&1 | grep -qE 'No Bearer|Attach Reject' \
  && bad "Open5GS reporta No Bearer/Attach Reject" || ok "Open5GS sin No Bearer/Attach Reject"

python3 results/verificar.py >/tmp/verificar_aceptacion.log 2>&1 \
  && ok "integridad $(grep -c 'OK' /tmp/verificar_aceptacion.log) lineas" \
  || { bad "integridad"; cat /tmp/verificar_aceptacion.log; }

if [ "$fail" -eq 0 ]; then
  echo "ACEPTACION: PASS"
else
  echo "ACEPTACION: FAIL"
  exit 1
fi
