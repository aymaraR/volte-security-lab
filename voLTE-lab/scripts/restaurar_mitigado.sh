#!/bin/sh
# Restaura el estado mitigado + autenticacion IMS (D2) para V7 y deja
# baresip registrado por el tunel. Versionado (ya no depende de .lab-tmp).
set -eu
cd "$(dirname "$0")/.."

docker compose up -d kali >/dev/null 2>&1 || true

# Mantener el bearer LTE vivo durante el reinicio de Kamailio/Asterisk.
for c in srsue srsue2; do
  docker exec -d "$c" sh -c 'while true; do ip route add 172.20.0.6/32 dev tun_srsue 2>/dev/null; ip route add 172.20.0.7/32 dev tun_srsue 2>/dev/null; ping -I tun_srsue -c 1 -W 1 10.45.0.1 >/dev/null 2>&1; sleep 5; done'
done

sh parches/aplicar.sh

# Volver al path GTP para la verificacion final.
docker exec kamailio sh -c "ip route add 10.45.0.0/24 via 172.20.0.3 2>/dev/null || true"
docker exec asterisk sh -c "ip route add 10.45.0.0/24 via 172.20.0.3 2>/dev/null || true"
for c in srsue srsue2; do
  TUN=$(docker exec "$c" sh -c "ip -o addr show tun_srsue 2>/dev/null | grep -oE 'inet [0-9.]+' | cut -d' ' -f2")
  [ -n "$TUN" ] || { echo "$c sin tun"; continue; }
  docker exec "$c" sh -c "ip route add 172.20.0.6/32 dev tun_srsue 2>/dev/null || true; ip route add 172.20.0.7/32 dev tun_srsue 2>/dev/null || true"
  docker exec -e TUN="$TUN" "$c" sh -c 'grep -v "^sip_listen" /root/.baresip/config > /tmp/c.new; printf "sip_listen\t\t%s:5060\n" "$TUN" >> /tmp/c.new; cp /tmp/c.new /root/.baresip/config'
  docker exec "$c" pkill -x baresip >/dev/null 2>&1 || true
done
sleep 2
docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1"
docker exec -d srsue2 sh -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip2.log 2>&1"
sleep 18
echo '--- 1001 ---'; docker exec srsue sh -c "grep -a -E '200 OK|401|403' /tmp/baresip.log | tail -n 3" || true
echo '--- 1002 ---'; docker exec srsue2 sh -c "grep -a -E '200 OK|401|403' /tmp/baresip2.log | tail -n 3" || true
