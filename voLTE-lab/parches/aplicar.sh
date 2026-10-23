#!/bin/sh
# ============================================================================
# aplicar.sh — Fase 4 (contramedidas) para V1, V2, V3 y V7.
#   V1: TLS en Gm (P-CSCF:5061) + SRTP/SDES en la media.
#   V2: pike (rate-limit por IP) en el S-CSCF.
#   V3/V7: binding identidad IMPU <-> IP de origen registrada en el P-CSCF
#          (solo se acepta el 2xx del REGISTER autenticado).
# Requiere lab UP. Deja backup en parches/vulnerable/ (revertir.sh).
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[parche] $*"; }

for c in kamailio asterisk srsue srsue2 kali; do
  docker ps --format "{{.Names}}" | tr -d '\r' | grep -qx "$c" \
    || { log "ERROR: contenedor $c no corre"; exit 1; }
done

# --- 1. Certificado TLS del P-CSCF (autofirmado, SAN IP+DNS) ---
mkdir -p kamailio/tls
if [ ! -f kamailio/tls/tls.crt ]; then
  log "generando certificado TLS autofirmado..."
  openssl req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes \
    -keyout kamailio/tls/tls.key -out kamailio/tls/tls.crt \
    -subj "/CN=pcscf.ims.mnc070.mcc999.3gppnetwork.org" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "subjectAltName=DNS:pcscf.ims.mnc070.mcc999.3gppnetwork.org,IP:172.20.0.6" \
    >/dev/null 2>&1
fi
[ -s kamailio/tls/tls.crt ] && [ -s kamailio/tls/tls.key ] || { log "ERROR: cert TLS"; exit 1; }
log "certificado OK: $(openssl x509 -in kamailio/tls/tls.crt -noout -subject 2>/dev/null)"

# --- 2. Configs Kamailio / Asterisk ---
cp parches/pcscf.cfg kamailio/pcscf/pcscf.cfg
cp parches/scscf.cfg kamailio/scscf/scscf.cfg
cp parches/pjsip.conf asterisk/pjsip.conf
docker exec kamailio mkdir -p /etc/kamailio/tls
docker cp kamailio/tls/tls.crt kamailio:/etc/kamailio/tls/tls.crt >/dev/null
docker cp kamailio/tls/tls.key kamailio:/etc/kamailio/tls/tls.key >/dev/null
docker cp parches/tls.cfg kamailio:/etc/kamailio/tls.cfg >/dev/null

# --- 3. baresip (UE1 y UE2): TLS + SRTP obligatorio ---
patch_baresip() {
  D="$1"
  cp kamailio/tls/tls.crt "$D/tls.crt"
  sed -i 's|;transport=udp>|;transport=tls>|; s|172.20.0.6:4060;transport=udp|172.20.0.6:5061;transport=tls|' "$D/accounts"
  sed -i '/;mediaenc=/! s|;regint=3600|;mediaenc=srtp-mand;regint=3600|' "$D/accounts"
  sed -i 's|^#module[[:space:]]*srtp.so|module\t\t\tsrtp.so|' "$D/config"
  grep -q '^sip_cafile' "$D/config" || printf 'sip_cafile\t\t/root/.baresip/tls.crt\n' >> "$D/config"
  sed -i '/^sip_listen/d' "$D/config"
}
patch_baresip srsran/baresip-config
patch_baresip .lab-tmp/baresip2
log "baresip parcheado: $(grep -a '^<sip:1001@' srsran/baresip-config/accounts)"

# --- 4. Validar sintaxis ANTES de reiniciar ---
docker exec kamailio kamailio -c -f /usr/local/etc/kamailio/pcscf.cfg >/dev/null \
  || { log "ERROR sintaxis pcscf.cfg"; exit 1; }
docker exec kamailio kamailio -c -f /usr/local/etc/kamailio/scscf.cfg >/dev/null \
  || { log "ERROR sintaxis scscf.cfg"; exit 1; }
log "sintaxis Kamailio OK (TLS + pike + htable)"

# --- 5. Reiniciar Kamailio (P/I/S-CSCF) ---
docker exec kamailio pkill -f 'kamailio -DD' >/dev/null 2>&1 || true
sleep 3
for cfg in scscf icscf pcscf; do
  docker exec -d kamailio bash -c "kamailio -DD -E -e -f /usr/local/etc/kamailio/$cfg.cfg > /tmp/$cfg.log 2>&1"
done
sleep 10
n=$(docker exec kamailio sh -c "ps -eo args | grep '[k]amailio -DD' | wc -l")
[ "$n" -ge 3 ] || { log "ERROR: solo $n CSCF vivos"; exit 1; }
log "Kamailio reiniciado ($n CSCF)"

# --- 6. Reiniciar Asterisk con SRTP ---
docker exec asterisk asterisk -rx "core stop now" >/dev/null 2>&1 || true
docker restart asterisk >/dev/null
sleep 3
docker exec -d asterisk bash -c "asterisk > /dev/null 2>&1"
sleep 8
docker exec asterisk asterisk -rx "module show like srtp" | grep -q Running \
  || { log "ERROR: res_srtp no cargó"; exit 1; }
docker exec asterisk asterisk -rx "pjsip show endpoint ue-endpoint" | grep -qi "media_encryption.*sdes" \
  || { log "ERROR: ue-endpoint sin SRTP"; exit 1; }
log "Asterisk OK: res_srtp Running + ue-endpoint media_encryption=sdes"

# --- 7. Reiniciar baresip (UE1/UE2) con TLS+SRTP ---
docker exec srsue pkill -x baresip >/dev/null 2>&1 || true
docker exec srsue2 pkill -x baresip >/dev/null 2>&1 || true
docker exec -i srsue2 sh -c "cat > /root/.baresip/accounts" < .lab-tmp/baresip2/accounts
docker exec -i srsue2 sh -c "cat > /root/.baresip/config" < .lab-tmp/baresip2/config
docker exec -i srsue2 sh -c "cat > /root/.baresip/tls.crt" < .lab-tmp/baresip2/tls.crt
sleep 1
docker exec -d srsue bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1"
docker exec -d srsue2 bash -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip2.log 2>&1"

# --- 8. Verificacion ---
sleep 18
log "--- 1001 ---"; docker exec srsue sh -c "grep -a '200 OK' /tmp/baresip.log | tail -n 1" || true
log "--- 1002 ---"; docker exec srsue2 sh -c "grep -a '200 OK' /tmp/baresip2.log | tail -n 1" || true
log "--- TLS listener ---"; docker exec kamailio sh -c "ss -ltnp 2>/dev/null | grep 5061" || true
log "--- Asterisk registrations ---"; docker exec asterisk asterisk -rx "pjsip show registrations" | grep -i registered || true
log "mitigaciones aplicadas. Re-ejecutar V1, V2, V3 y V7 para validar."
