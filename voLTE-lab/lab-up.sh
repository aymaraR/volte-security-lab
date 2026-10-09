#!/bin/sh
# ============================================================================
# lab-up.sh — Levanta el laboratorio VoLTE completo en orden seguro.
#
# Uso (Ubuntu 22.04, Git Bash o WSL, parado en voLTE-lab/):
#   ./lab-up.sh
#
# Orden (cada paso espera al anterior con healthcheck sobre logs FRESCOS):
#   mongo+redis -> suscriptores LTE -> open5gs -> pyhss -> IMS provision ->
#   kamailio (P/I/S-CSCF) -> asterisk -> eNB1 -> eNB2 -> UE1 -> UE2 ->
#   baresip 1001/1002 -> plano de usuario via GTP (tun + keepalive)
#
# Lecciones integradas (no quitar):
# - wait_log usa 'docker logs --since' (sin esto, líneas viejas dan falsos OK).
# - RAN se reinicia por CONTENEDOR (restart), no por pkill: los sockets ZMQ
#   (REQ/REP) se cuelgan con reinicios de solo-proceso (TIME_WAIT/wedge).
# - 'rrc_inactivity_timer' con valores enormes ROMPE la RF de srsENB: NO tocar
#   (se deja el default 30s).
# - ogstun nace DOWN: hay que levantarlo (paso 13) o no hay breakout UPF.
# - baresip bindea la IP de eth0: hay que fijar sip_listen a la IP del tun
#   (cambia en cada attach!) o el RTP/SIP no entra al túnel GTP.
# - El MME rechaza Service Request (causa 9: srsUE pierde la GUTI): el plano
#   de usuario solo es usable en ventana CONNECTED post-attach. El keepalive
#   es SOLO-rutas (sin ping: el ping en IDLE acelera el detach/re-attach).
# - Paso 12 registra por bridge (sin rutas al tun); paso 13 conmuta a túnel.
#
# Notas:
# - No modifica el repo (las configs generadas de celda2 van a .lab-tmp/).
# - No hace commits. Idempotente: se puede re-ejecutar.
# - Requiere imágenes ya construidas (ver README de cada componente).
# ============================================================================
set -eu
cd "$(dirname "$0")"
# Git Bash/MSYS mutila los '-v SRC:DST' y '--add-host H:IP' (parte por ':').
# Esto lo desactiva; Docker Desktop entiende rutas /c/... sin conversión.
# En Linux real no tiene efecto.
export MSYS_NO_PATHCONV=1

log()  { echo "[lab-up] $*"; }
die()  { echo "[lab-up][ERROR] $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker no encontrado en PATH"
docker info >/dev/null 2>&1 || die "Docker daemon no responde (prende Docker Desktop)"
docker compose version >/dev/null 2>&1 || die "se requiere Docker Compose v2"

need_image() {
  docker image inspect "$1" >/dev/null 2>&1 || die "falta imagen $1 — constrúyela antes (ver README del componente)"
}

# Espera hasta $3 segundos a que $2 aparezca en logs NUEVOS de $1.
# $4 opcional: epoch 'since' (para acciones rápidas cuyo log nace ANTES del
# primer poll; sin esto hay carrera y falsos timeouts).
# (docker logs --since evita falsos positivos de sesiones anteriores.)
wait_log() {
  if [ $# -ge 4 ]; then T0=$4; else T0=$(date +%s); fi
  i=0
  while [ "$i" -lt "$3" ]; do
    if docker logs --since "$T0" "$1" 2>&1 | grep -q "$2"; then return 0; fi
    sleep 3; i=$((i + 3))
  done
  return 1
}

# Ejecuta $2 dentro de $1 hasta $3 s, éxito si el comando sale 0.
wait_exec_ok() {
  i=0
  while [ "$i" -lt "$3" ]; do
    if docker exec "$1" sh -c "$2" >/dev/null 2>&1; then return 0; fi
    sleep 2; i=$((i + 2))
  done
  return 1
}

log "== 0/13 chequeo de imágenes =="
need_image mongo:4.4
need_image redis:7.0-alpine
need_image open5gs-local:latest
need_image srsran-zmq:latest
need_image kamailio-ims:latest
need_image asterisk-ims:latest
need_image pyhss-local:latest
# El compose referencia la imagen upstream; la etiquetamos local (sin red).
docker tag pyhss-local:latest ghcr.io/nickvsnetworking/pyhss/pyhss:development 2>/dev/null || true
log "imágenes OK"

log "== 1/13 base: mongodb + redis =="
docker compose up -d mongodb redis
wait_exec_ok redis "redis-cli ping | grep -q PONG" 60 || die "redis no responde"
wait_exec_ok mongodb "mongo --quiet --eval 'db.runCommand({ping:1})' | grep -q '\"ok\" : 1'" 60 \
  || die "mongodb no responde"

log "== 2/13 suscriptores LTE en Mongo (idempotente, int32) =="
docker exec -i mongodb mongo --quiet open5gs <<'EOF'
function putSub(imsi, k) {
  db.subscribers.deleteOne({ imsi: imsi });
  db.subscribers.insertOne({
    imsi: imsi, msisdn: [], imeisv: [], mme_host: [], mme_realm: [], purge_flag: [],
    slice: [{ sst: NumberInt(1), default_indicator: true,
      session: [{ name: "srsapn", type: NumberInt(3), pcc_rule: [],
        ambr: { uplink: { value: NumberInt(1), unit: NumberInt(0) },
                downlink: { value: NumberInt(1), unit: NumberInt(0) } },
        qos: { index: NumberInt(9),
          arp: { priority_level: NumberInt(8), pre_emption_capability: NumberInt(1),
                 pre_emption_vulnerability: NumberInt(1) } } }] }],
    ambr: { uplink: { value: NumberInt(1), unit: NumberInt(0) },
            downlink: { value: NumberInt(1), unit: NumberInt(0) } },
    security: { k: k, amf: "8000", op: null,
      opc: "63bfa50ee6523365ff14c1f45f88737d", sqn: NumberLong(0) },
    schema_version: NumberInt(1), __v: 0 });
}
putSub("001010123456789", "00112233445566778899aabbccddeeff");
putSub("001010123456790", "00112233445566778899aabbccddeef0");
print("subs=" + db.subscribers.count());
EOF

log "== 3/13 EPC: open5gs =="
docker compose up -d open5gs
# restart (no solo start): garantiza daemons recién booteados y líneas de
# log frescas para el healthcheck (un start reutiliza estado viejo).
T0=$(date +%s)
docker restart open5gs
sleep 5
wait_log open5gs "MME initialize...done" 90 "$T0" || die "MME no inicializó (ver: docker logs open5gs)"

log "== 4/13 HSS IMS: pyhss hss/api/diameter =="
for c in pyhss_hss pyhss_api pyhss_diameter; do docker rm -f "$c" >/dev/null 2>&1 || true; done
T0=$(date +%s)
HSS_ENV="hss.ims.mnc070.mcc999.3gppnetwork.org"
docker run -d --name pyhss_hss --network volte-lab_volte-net --ip 172.20.0.10 \
  --user root --env-file ./pyhss/docker/.env -e CONTAINER_ROLE=hss \
  -e HSS_ORIGIN_HOST="$HSS_ENV" -e HSS_ORIGIN_REALM=ims.mnc070.mcc999.3gppnetwork.org \
  -e HSS_MCC=999 -e HSS_MNC=070 -e HSS_SCSCF_POOL=scscf.ims.mnc070.mcc999.3gppnetwork.org \
  -v volte-lab_pyhss_sqlite:/var/lib/pyhss pyhss-local:latest >/dev/null
docker run -d --name pyhss_api --network volte-lab_volte-net --ip 172.20.0.11 \
  --user root --env-file ./pyhss/docker/.env -e CONTAINER_ROLE=api \
  -e HSS_ORIGIN_HOST="$HSS_ENV" -e HSS_ORIGIN_REALM=ims.mnc070.mcc999.3gppnetwork.org \
  -e HSS_MCC=999 -e HSS_MNC=070 -e HSS_SCSCF_POOL=scscf.ims.mnc070.mcc999.3gppnetwork.org \
  -v volte-lab_pyhss_sqlite:/var/lib/pyhss pyhss-local:latest >/dev/null
docker run -d --name pyhss_diameter --network volte-lab_volte-net --ip 172.20.0.12 \
  --user root --env-file ./pyhss/docker/.env -e CONTAINER_ROLE=diameter -e LOGGING_LEVEL=INFO \
  -e HSS_ORIGIN_HOST="$HSS_ENV" -e HSS_ORIGIN_REALM=ims.mnc070.mcc999.3gppnetwork.org \
  -e HSS_MCC=999 -e HSS_MNC=070 -e HSS_SCSCF_POOL=scscf.ims.mnc070.mcc999.3gppnetwork.org \
  -v volte-lab_pyhss_sqlite:/var/lib/pyhss pyhss-local:latest >/dev/null
wait_log pyhss_diameter "Serving on" 90 "$T0" || die "pyhss_diameter no abrió 3868"

log "== 5/13 provision IMS en PyHSS (1000/1001/1002, idempotente) =="
docker exec -i pyhss_api python3 - <<'EOF'
import urllib.request, json
BASE = "http://127.0.0.1:8080"
want = {"1000": "999070000000001", "1001": "001010123456789", "1002": "001010123456790"}
have = {s["msisdn"]: s for s in json.loads(urllib.request.urlopen(BASE + "/ims_subscriber/list", timeout=15).read().decode())}
for msisdn, imsi in want.items():
    if msisdn not in have:
        req = urllib.request.Request(BASE + "/ims_subscriber/", data=json.dumps({"msisdn": msisdn, "imsi": imsi}).encode(),
                                     headers={"Content-Type": "application/json"}, method="PUT")
        urllib.request.urlopen(req, timeout=15).read()
        print("created", msisdn, flush=True)
    cur = json.loads(urllib.request.urlopen(BASE + "/ims_subscriber/ims_subscriber_msisdn/" + msisdn, timeout=15).read().decode())
    if not cur.get("ifc_path"):
        sid = cur["ims_subscriber_id"]
        req = urllib.request.Request(BASE + "/ims_subscriber/%d" % sid, data=json.dumps({"ifc_path": "default_ifc.xml"}).encode(),
                                     headers={"Content-Type": "application/json"}, method="PATCH")
        urllib.request.urlopen(req, timeout=15).read()
        print("ifc_path set for", msisdn, flush=True)
print("ims provisioning OK", flush=True)
EOF

log "== 6/13 IMS: kamailio (P:4060/I:5060/S:6060, sin puertos al host) =="
docker rm -f kamailio >/dev/null 2>&1 || true
docker run -d --name kamailio --network volte-lab_volte-net --ip 172.20.0.6 \
  --privileged --cap-add NET_ADMIN \
  --add-host "hss.ims.mnc070.mcc999.3gppnetwork.org:172.20.0.12" \
  -v "$PWD/kamailio/scscf/scscf.cfg:/usr/local/etc/kamailio/scscf.cfg" \
  -v "$PWD/kamailio/icscf/icscf.cfg:/usr/local/etc/kamailio/icscf.cfg" \
  -v "$PWD/kamailio/pcscf/pcscf.cfg:/usr/local/etc/kamailio/pcscf.cfg" \
  -v "$PWD/kamailio/scscf/scscf_diameter.xml:/usr/local/etc/kamailio/scscf_diameter.xml" \
  -v "$PWD/kamailio/icscf/icscf_diameter.xml:/usr/local/etc/kamailio/icscf_diameter.xml" \
  kamailio-ims:latest bash -c "sleep infinity" >/dev/null
sleep 3
for cfg in scscf icscf pcscf; do
  docker exec kamailio kamailio -c -f /usr/local/etc/kamailio/$cfg.cfg >/dev/null 2>&1 \
    || die "sintaxis $cfg.cfg inválida"
done
for cfg in scscf icscf pcscf; do
  docker exec -d kamailio bash -c "kamailio -DD -E -e -f /usr/local/etc/kamailio/$cfg.cfg > /tmp/$cfg.log 2>&1"
done
sleep 10
n=$(docker exec kamailio sh -c "ps -eo args | grep '[k]amailio -DD' | wc -l")
[ "$n" -ge 3 ] || die "no arrancaron los 3 CSCF (vivos: $n)"
# Herramientas para rutas/capturas (la imagen no las trae). Se instala acá
# para no robar tiempo de la ventana CONNECTED post-attach (paso 13).
docker exec kamailio apt-get update -qq >/dev/null 2>&1 || true
docker exec kamailio apt-get install -y -qq iproute2 tcpdump >/dev/null 2>&1 || true

log "== 7/13 TAS: asterisk =="
docker rm -f asterisk >/dev/null 2>&1 || true
docker run -d --name asterisk --network volte-lab_volte-net --ip 172.20.0.7 --privileged \
  -v "$PWD/asterisk/pjsip.conf:/etc/asterisk/pjsip.conf" \
  -v "$PWD/asterisk/extensions.conf:/etc/asterisk/extensions.conf" \
  asterisk-ims:latest bash -c "sleep infinity" >/dev/null
sleep 3
docker exec -d asterisk bash -c "asterisk > /dev/null 2>&1"
wait_exec_ok asterisk "asterisk -rx 'core show version' | grep -q Asterisk" 60 \
  || die "asterisk no partió"
log "esperando registro Asterisk en S-CSCF (hasta 90s)..."
i=0
while [ "$i" -lt 90 ]; do
  if docker exec asterisk asterisk -rx "pjsip show registrations" 2>/dev/null | grep -q Registered; then break; fi
  sleep 3; i=$((i + 3))
done
docker exec asterisk asterisk -rx "pjsip show registrations" 2>/dev/null | grep -q Registered \
  || die "asterisk no se registró (revisar SAR/SAA: logs kamailio + pyhss_diameter)"
log "asterisk Registered OK"

log "== 8/13 RAN: eNB1 (PCI 1) =="
docker compose up -d enb
T0=$(date +%s)
docker restart srsenb
sleep 8
docker exec -d srsenb bash -c "cd /root/enb-config && srsenb enb.conf > /tmp/enb.log 2>&1"
wait_log open5gs "Number of eNBs is now 1" 60 "$T0" || die "eNB1 sin S1 (ver /tmp/enb.log en srsenb)"

log "== 9/13 RAN: eNB2 (PCI 2, configs generadas en .lab-tmp/) =="
# Ojo: en Windows existen stubs de Microsoft Store (python3.exe/python.exe)
# que 'command -v' sí encuentra pero no ejecutan: se valida corriendo.
if python3 --version >/dev/null 2>&1; then PYBIN=python3;
elif py -3 --version >/dev/null 2>&1; then PYBIN="py -3";
elif python --version >/dev/null 2>&1; then PYBIN=python;
else die "se requiere python3 en el host para generar configs de celda2"; fi
mkdir -p .lab-tmp
$PYBIN - <<'EOF'
from pathlib import Path
src = Path("srsran/enb-config"); dst = Path(".lab-tmp/enb2-config"); dst.mkdir(parents=True, exist_ok=True)
enb = (src/"enb.conf").read_text()
enb = enb.replace("enb_id = 0x19B", "enb_id = 0x19C")
enb = enb.replace("gtp_bind_addr = 172.20.0.4", "gtp_bind_addr = 172.20.0.14")
enb = enb.replace("s1c_bind_addr = 172.20.0.4", "s1c_bind_addr = 172.20.0.14")
enb = enb.replace("tx_port0=tcp://*:2000,rx_port0=tcp://172.20.0.5:2001",
                  "tx_port0=tcp://*:2002,rx_port0=tcp://172.20.0.8:2003")
(dst/"enb.conf").write_text(enb)
rr = (src/"rr.conf").read_text()
rr = rr.replace("cell_id = 0x01;", "cell_id = 0x02;").replace("pci = 1;", "pci = 2;").replace("dl_earfcn = 3350;", "dl_earfcn = 3400;")
(dst/"rr.conf").write_text(rr)
for f in ["sib.conf", "rb.conf"]:
    (dst/f).write_text((src/f).read_text())
ue = Path("srsran/ue-config/ue.conf").read_text()
ue = ue.replace("tx_port=tcp://*:2001,rx_port=tcp://172.20.0.4:2000,id=ue,",
                "tx_port=tcp://*:2003,rx_port=tcp://172.20.0.14:2002,id=ue2,")
ue = ue.replace("dl_earfcn = 3350", "dl_earfcn = 3400")
ue = ue.replace("imsi = 001010123456789", "imsi = 001010123456790")
ue = ue.replace("k    = 00112233445566778899aabbccddeeff", "k    = 00112233445566778899aabbccddeef0")
ue = ue.replace("imei = 353490069873319", "imei = 353490069873320")
ud = Path(".lab-tmp/ue2-config"); ud.mkdir(parents=True, exist_ok=True)
(ud/"ue.conf").write_text(ue)
b2 = Path(".lab-tmp/baresip2"); b2.mkdir(parents=True, exist_ok=True)
bsrc = Path("srsran/baresip-config")
for f in ["contacts", "uuid"]:
    (b2/f).write_bytes((bsrc/f).read_bytes())
# config SIN líneas sip_listen activas (la IP del tun cambia en cada attach;
# el paso 13 la fija por contenedor; una stale rompería el bind de baresip)
cfg = "".join(l for l in (bsrc/"config").read_text().splitlines(keepends=True)
              if not l.startswith("sip_listen"))
(b2/"config").write_text(cfg)
acc = (bsrc/"accounts").read_text()
acc = acc.replace("1001@ims.mnc070.mcc999.3gppnetwork.org", "1002@ims.mnc070.mcc999.3gppnetwork.org")
acc = acc.replace("999070000000002", "999070000000003").replace("ue1001pass123", "ue1002pass123")
lines = [l if not (l.startswith("<sip:1002@") and "answermode" not in l) else l.rstrip() + ";answermode=auto"
         for l in acc.splitlines()]
(b2/"accounts").write_text("\n".join(lines) + "\n")
print("cell2 configs OK")
EOF
docker rm -f srsenb2 >/dev/null 2>&1 || true
T0=$(date +%s)
docker run -d --name srsenb2 --network volte-lab_volte-net --ip 172.20.0.14 \
  --privileged --cap-add NET_ADMIN \
  -v "$PWD/.lab-tmp/enb2-config:/root/enb2-config" \
  srsran-zmq:latest bash -c "sleep infinity" >/dev/null
sleep 3
docker exec -d srsenb2 bash -c "cd /root/enb2-config && srsenb enb.conf > /tmp/enb2.log 2>&1"
wait_log open5gs "Number of eNBs is now 2" 60 "$T0" || die "eNB2 sin S1 (ver /tmp/enb2.log en srsenb2)"

# Attach con reintentos: la sincronización RF/ZMQ es flaky (~50% 1er intento).
# Cada intento parte de AMBOS contenedores reiniciados (par fresco eNB+UE:
# reinicios de un solo lado dejan sockets ZMQ cuelgados).
# Uso: attach_ue <cont_ue> <dir_ue> <imsi> <log_ue> <cont_enb> <dir_enb> <log_enb>
attach_ue() {
  C="$1"; D="$2"; IMSI="$3"; LOG="$4"; ENB="$5"; ED="$6"; ELOG="$7"
  n=1
  while [ "$n" -le 3 ]; do
    log "attach $C intento $n/3..."
    T0=$(date +%s)
    docker restart "$ENB" >/dev/null 2>&1 || true
    sleep 8
    docker exec -d "$ENB" sh -c "cd $ED && srsenb enb.conf > /tmp/$ELOG 2>&1"
    sleep 15
    docker restart "$C" >/dev/null 2>&1 || true
    sleep 8
    docker exec -d "$C" sh -c "cd $D && srsue ue.conf > /tmp/$LOG 2>&1"
    if wait_log open5gs "$IMSI] Attach complete" 150 "$T0"; then
      log "$C attached OK"; return 0
    fi
    n=$((n + 1))
  done
  return 1
}

# Keepalive de plano de usuario: SOLO repone rutas del tun (se pierden en cada
# re-attach). Deliberadamente SIN ping: el ping en IDLE dispara Service
# Request (rechazado, causa 9) y acelera el detach/re-attach. Se inicia en el
# paso 13 (fase túnel); el paso 12 los detiene para registrar por bridge.
net_keepalive() {
  docker exec -d "$1" sh -c 'while true; do ip route add 172.20.0.6/32 dev tun_srsue 2>/dev/null; ip route add 172.20.0.7/32 dev tun_srsue 2>/dev/null; sleep 15; done'
}
stop_keepalive() {
  docker exec "$1" pkill -f tun_srsue >/dev/null 2>&1 || true
}

log "== 10/13 UE1 (IMSI ...789) =="
docker compose up -d ue >/dev/null 2>&1 || true
attach_ue srsue /root/ue-config "001010123456789" ue.log srsenb /root/enb-config enb.log || die "UE1 no hizo attach en 3 intentos"

log "== 11/13 UE2 (IMSI ...790) =="
docker rm -f srsue2 >/dev/null 2>&1 || true
docker run -d --name srsue2 --network volte-lab_volte-net --ip 172.20.0.8 \
  --privileged --cap-add NET_ADMIN \
  -v "$PWD/.lab-tmp/ue2-config:/root/ue2-config" \
  srsran-zmq:latest bash -c "sleep infinity" >/dev/null
sleep 3
attach_ue srsue2 /root/ue2-config "001010123456790" ue2.log srsenb2 /root/enb2-config enb2.log || die "UE2 no hizo attach en 3 intentos"

log "== 12/13 SIP: baresip 1001 (UE1) + 1002 (UE2) =="
# Ojo: quitar sip_listen stale de corridas previas (IP de tun vieja). Sin
# línea activa, baresip bindea 0.0.0.0 y registra por el bridge (eth0).
docker exec srsue sh -c "grep -a -v '^sip_listen' /root/.baresip/config > /tmp/c.def; cp /tmp/c.def /root/.baresip/config"
# Este paso DEBE ir por bridge: borrar rutas al tun que forcing el tráfico
# al plano GTP (aún no levantado). El paso 13 las repone.
docker exec srsue sh -c "ip route del 172.20.0.6/32 dev tun_srsue 2>/dev/null; ip route del 172.20.0.7/32 dev tun_srsue 2>/dev/null; true"
docker exec srsue2 sh -c "ip route del 172.20.0.6/32 dev tun_srsue 2>/dev/null; ip route del 172.20.0.7/32 dev tun_srsue 2>/dev/null; true"
docker exec srsue pkill -x baresip >/dev/null 2>&1 || true
docker exec srsue2 bash -c "mkdir -p /root/.baresip" >/dev/null 2>&1 || true
docker cp .lab-tmp/baresip2/accounts srsue2:/root/.baresip/accounts
docker cp .lab-tmp/baresip2/config srsue2:/root/.baresip/config
docker exec srsue2 bash -c "touch /root/.baresip/contacts /root/.baresip/uuid"
docker exec srsue2 pkill -x baresip >/dev/null 2>&1 || true
sleep 1
docker exec -d srsue bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1"
docker exec -d srsue2 bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip2.log 2>&1"
sleep 14
docker exec srsue sh -c "grep -a -q '200 OK' /tmp/baresip.log" || die "1001 no se registró"
docker exec srsue2 sh -c "grep -a -q '200 OK' /tmp/baresip2.log" || die "1002 no se registró"
log "1001 y 1002 registrados OK (ojo: vía bridge; el paso 13 los pasa al túnel)"

log "== 13/13 plano de usuario via GTP =="
# ogstun nace DOWN en cada arranque de open5gs: sin esto no hay breakout UPF.
docker exec open5gs ip addr add 10.45.0.1/16 dev ogstun 2>/dev/null || true
docker exec open5gs ip link set ogstun up
# Retorno IMS <-> EPC.
docker exec kamailio ip route add 10.45.0.0/24 via 172.20.0.3 2>/dev/null || true
docker exec asterisk ip route add 10.45.0.0/24 via 172.20.0.3 2>/dev/null || true
# Recién acá se encienden los keepalive (fase túnel).
net_keepalive srsue
net_keepalive srsue2
sleep 6
# baresip debe bindear la IP ACTUAL del tun (cambia en cada attach).
set_sip_listen() {
  TUN=$(docker exec "$1" sh -c "ip -o addr show tun_srsue 2>/dev/null | grep -a -oE 'inet [0-9.]+' | cut -d' ' -f2") || die "sin tun en $1"
  [ -n "$TUN" ] || die "sin tun en $1"
  docker exec -e TUN="$TUN" "$1" sh -c "grep -a -v '^sip_listen' /root/.baresip/config > /tmp/c.new; printf 'sip_listen\t\t%s:5060\n' \"\$TUN\" >> /tmp/c.new; cp /tmp/c.new /root/.baresip/config"
  log "sip_listen $1 = $TUN:5060"
}
set_sip_listen srsue
set_sip_listen srsue2
docker exec srsue pkill -x baresip >/dev/null 2>&1 || true
docker exec srsue2 pkill -x baresip >/dev/null 2>&1 || true
sleep 1
docker exec -d srsue bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1"
docker exec -d srsue2 bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip2.log 2>&1"
sleep 16
docker exec srsue sh -c "grep -a -q '200 OK' /tmp/baresip.log" || die "1001 no se registró via túnel"
docker exec srsue2 sh -c "grep -a -q '200 OK' /tmp/baresip2.log" || die "1002 no se registró via túnel"
log "plano de usuario configurado (validar RTP con llamada de prueba)"

log "================ RESUMEN ================"
docker ps --format "table {{.Names}}\t{{.Status}}"
log "UE1: $(docker exec srsue sh -c 'ip -o addr show tun_srsue 2>/dev/null | grep inet' || echo sin-tun)"
log "UE2: $(docker exec srsue2 sh -c 'ip -o addr show tun_srsue 2>/dev/null | grep inet' || echo sin-tun)"
log "Lab UP. Pruebas:"
log "  1001->1000 (echo): docker exec -d srsue sh -c 'export HOME=/root; baresip -f /root/.baresip -e \"/dial 1000@ims.mnc070.mcc999.3gppnetwork.org\"'"
log "  1001->1002       : mismo comando con /dial 1002@ims.mnc070.mcc999.3gppnetwork.org"
log "Apagado ordenado: ./lab-down.sh"
