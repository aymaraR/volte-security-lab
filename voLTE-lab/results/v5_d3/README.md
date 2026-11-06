# V5 â€” Rogue eNodeB (alcance extendido)

**Fecha:** 2026-11-04  
**MecÃ¡nica:** takeover de los puertos ZMQ del eNB1 (`172.20.0.4`),
PCI legÃ­timo 1 â†’ PCI falso 7, cell_id `0x09`, eNB2 detenido y UE1 reiniciado
como **proceso** (no `docker restart`).

## Resultado

| Corrida | UE antes | Durante rogue | Veredicto |
|---|---|---|---|
| `20261104T144013Z` | PCI 1, attach OK | sin `Found Cell` | fallo de sincronizaciÃ³n |
| `20261104T150149Z` | PCI 1, attach OK | sin `Found Cell` | fallo de sincronizaciÃ³n |
| `20261104T152449Z` | PCI 1, attach OK | sin `Found Cell` | fallo de sincronizaciÃ³n |
| `20261104T154002Z` | PCI 1, attach OK | **PCI 7, attach OK, IP 10.45.0.8** | **VULNERABLE** |

Evidencia de la corrida efectiva:
- `v5_success_20261104T154002Z.log`: UE `Found Cell PCI=7`, `Network attach
  successful IP 10.45.0.8`; MME `[001010123456789] Attach complete`; eNB rogue
  con `RACH ... pci=7 ... User 0x46 connected`.
- `results/v5_rogue_20261104T144013Z.log` a `...152449Z.log`: fallos previos.

## ConclusiÃ³n

**V5 es vulnerable en el laboratorio**, pero la reproducibilidad es sensible a
ZMQ/PHY: funciona cuando el eNB falso arranca primero y el UE se reinicia como
proceso, con eNB2 apagado. No se debe presentar como ataque estable al 100 %.

## Contramedida

No validada todavÃ­a. Propuesta: allowlist de `enb_id`/PCI en el MME o control
de admisiÃ³n, detecciÃ³n de PCI inesperado para la misma PLMN/TAC y alerta por
cambio de CellID/ECGI.

## ReproducciÃ³n

```sh
# detener eNB2/UE2 para evitar interferencia
docker stop srsenb2 srsue2
# ejecutar el takeover (proceso, no reinicio de contenedor)
sh vectores/v5_rogue.sh
```
