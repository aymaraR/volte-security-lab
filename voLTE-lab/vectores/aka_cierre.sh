#!/bin/sh
# ============================================================================
# aka_cierre.sh - IMS-AKA real (RAND/AUTN -> RES -> Digest AKAv1-MD5).
#
# Usa el IMPU 1003 y su IMPI 001010123456791. El cliente corre dentro de
# pyhss_hss porque ese contenedor ya tiene MILENAGE/PyCryptodome. baresip
# (1001/1002, MD5) no se toca.
#
# Evidencia: results/aka_d3/aka_{client,cx,sip}_*.{log,pcap} + metrics.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT=results/aka_d3
ABS=$(pwd)/$OUT
mkdir -p "$OUT"
CAP_CX="akacx_$$"
CAP_SIP="akasip_$$"
cleanup() {
  docker rm -f "$CAP_CX" "$CAP_SIP" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for c in pyhss_hss kamailio pyhss_diameter; do
  test "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" = "true" || {
    echo "contenedor $c no esta UP"; exit 1; }
done

docker cp scripts/ims_aka_client.py pyhss_hss:/tmp/ims_aka_client.py >/dev/null

docker run -d --name "$CAP_CX" --net=container:pyhss_diameter \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 20 tcpdump -i eth0 -s0 -w /cap/aka_cx_$TS.pcap 'tcp port 3868' >/cap/aka_cx_$TS.log 2>&1" >/dev/null
docker run -d --name "$CAP_SIP" --net=container:kamailio \
  --cap-add NET_RAW --cap-add NET_ADMIN -v "$ABS:/cap" kali-lab:latest \
  sh -c "timeout 20 tcpdump -i any -s0 -w /cap/aka_sip_$TS.pcap 'udp port 6060' >/cap/aka_sip_$TS.log 2>&1" >/dev/null
sleep 1

docker exec pyhss_hss python3 /tmp/ims_aka_client.py 2>&1 | tee "$OUT/aka_client_$TS.log"
sleep 2
docker rm -f "$CAP_CX" "$CAP_SIP" >/dev/null 2>&1 || true

# Campos SIP relevantes (401, Authorization, 200).
docker run --rm -v "$ABS:/cap" kali-lab:latest tshark -r "/cap/aka_sip_$TS.pcap" \
  -Y 'sip' -T fields -e frame.number -e ip.src -e ip.dst -e sip.CSeq \
  -e sip.Authorization -e sip.WWW-Authenticate 2>/dev/null \
  > "$OUT/aka_sip_fields_$TS.txt" || true

# Valores Cx: RAND||AUTN y XRES que entrega el HSS.
docker run --rm -v "$ABS:/cap" kali-lab:latest tshark -r "/cap/aka_cx_$TS.pcap" \
  -Y 'diameter.cmd.code == 303' -T fields \
  -e frame.number -e diameter.3GPP-SIP-Authenticate -e diameter.3GPP-SIP-Authorization \
  2>/dev/null > "$OUT/aka_cx_values_$TS.txt" || true

ALG=$(grep -o 'algorithm=[A-Za-z0-9-]*' "$OUT/aka_client_$TS.log" | head -n1 | cut -d= -f2)
RAND=$(grep -o '^RAND=.*' "$OUT/aka_client_$TS.log" | head -n1 | cut -d= -f2)
AUTN=$(grep -o '^AUTN=.*' "$OUT/aka_client_$TS.log" | head -n1 | cut -d= -f2)
RES=$(grep -o '^RES=.*' "$OUT/aka_client_$TS.log" | head -n1 | cut -d= -f2)
R1=$(grep -o 'REGISTER_1_STATUS=[0-9]*' "$OUT/aka_client_$TS.log" | head -n1 | cut -d= -f2)
R2=$(grep -o 'REGISTER_2_STATUS=[0-9]*' "$OUT/aka_client_$TS.log" | head -n1 | cut -d= -f2)
VERDICT=$(grep -q 'RESULT=PASS' "$OUT/aka_client_$TS.log" && echo PASS || echo FAIL)

cat > "$OUT/aka_metrics_$TS.txt" <<EOF
mode=aka
timestamp=$TS
impi=001010123456791@ims.mnc070.mcc999.3gppnetwork.org
impu=sip:1003@ims.mnc070.mcc999.3gppnetwork.org
algorithm=${ALG:-unknown}
register_1_status=${R1:-0}
register_2_status=${R2:-0}
rand=${RAND:-}
autn=${AUTN:-}
res=${RES:-}
verdict=$VERDICT
EOF

# D2 no debe verse afectado.
docker exec srsue sh -c "grep -a '200 OK' /tmp/baresip.log | tail -n 1" >> "$OUT/aka_metrics_$TS.txt" 2>/dev/null || true
echo "[aka] $VERDICT - evidencia en $OUT"
test "$VERDICT" = PASS
