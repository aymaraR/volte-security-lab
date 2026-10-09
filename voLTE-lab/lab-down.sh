#!/bin/sh
# ============================================================================
# lab-down.sh — Apaga el laboratorio VoLTE en orden seguro (inverso a lab-up).
#
# Uso (desde Git Bash o WSL, parado en voLTE-lab/):
#   ./lab-down.sh
#
# Orden: cuelga llamadas -> baja SIP -> para RAN (UEs antes que eNBs, evita
# sockets ZMQ colgados) -> IMS -> HSS -> EPC -> base. NO borra volúmenes
# (Mongo/Redis/SQLite persisten) ni imágenes.
# ============================================================================
set -eu
cd "$(dirname "$0")"
# Ver lab-up.sh: evita que Git Bash/MSYS mutile argumentos con ':'.
export MSYS_NO_PATHCONV=1

log() { echo "[lab-down] $*"; }

# docker.exe en Windows emite CRLF: se filtra \r antes de comparar.
exists() { docker ps -a --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx "$1"; }
running() { docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -qx "$1"; }
ql() { # quiet: ignora errores
  "$@" >/dev/null 2>&1 || true
}

log "== 1/6 colgar llamadas y bajar clientes SIP =="
running srsue  && ql docker exec srsue pkill -x baresip
running srsue2 && ql docker exec srsue2 pkill -x baresip
# keepalives del plano de usuario (loops con 'tun_srsue' en su cmdline)
running srsue  && ql docker exec srsue pkill -f tun_srsue
running srsue2 && ql docker exec srsue2 pkill -f tun_srsue
if running asterisk; then
  ql docker exec asterisk asterisk -rx "channel request hangup all"
  sleep 2
  ql docker exec asterisk asterisk -rx "core stop now"
  sleep 3
fi

log "== 2/6 bajar RAN: UEs primero, luego eNBs =="
running srsue  && ql docker exec srsue pkill -x srsue
running srsue2 && ql docker exec srsue2 pkill -x srsue
sleep 3
running srsenb  && ql docker exec srsenb pkill -x srsenb
running srsenb2 && ql docker exec srsenb2 pkill -x srsenb
sleep 2

log "== 3/6 bajar IMS (kamailio) =="
running kamailio && ql docker exec kamailio pkill -x kamailio
sleep 2

log "== 4/6 detener contenedores manuales =="
for c in srsue2 srsenb2 kamailio asterisk pyhss_hss pyhss_api pyhss_diameter; do
  if running "$c"; then docker stop "$c" >/dev/null 2>&1 || true; log "stop $c"; fi
done

log "== 5/6 detener stack compose (open5gs, ran, base) =="
docker compose stop open5gs enb ue mongodb redis >/dev/null 2>&1 || true
# Verificar que realmente pararon (reintentar con stop directo si no).
i=0
while [ "$i" -lt 30 ]; do
  left=$(docker ps --format "{{.Names}}" 2>/dev/null | tr -d '\r' | grep -acE "^(open5gs|srsenb|srsue|mongodb|redis)$" || true)
  [ "$left" -eq 0 ] && break
  sleep 2; i=$((i + 2))
done
if [ "$left" -ne 0 ]; then
  log "forzando stop directo..."
  docker stop open5gs srsenb srsue mongodb redis >/dev/null 2>&1 || true
fi

log "== 6/6 estado final (volúmenes e imágenes intactos) =="
docker ps --format "table {{.Names}}\t{{.Status}}"
log "Lab DOWN. Para re-levantar: ./lab-up.sh"
log "Limpieza total (opcional, BORRA DBs): docker compose down -v"
