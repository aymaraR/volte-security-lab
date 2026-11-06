# D4 — Métricas, capturas e integridad (2026-11-04)

**Objetivo:** consolidar métricas, ordenar capturas y dejar un set verificable.  
**Resultado:** **D4 completado**. `MANIFEST.csv` + `hashes.txt` + `verificar.py` cubren **123 archivos**; verificación: **123 OK, 0 faltantes, 0 diferencias**.

---

## 1. Métricas

Archivo: `voLTE-lab/results/metrics.csv` — **33 filas** con:

- D0: 600 pings, 0 % pérdida, 600.7 s, 0 detach, llamada 15 s, TEIDs.
- D1: attach 413.257 ms, AKA 33.550 ms, security mode 26.189 ms, EEA0/EIA2/EBI 5.
- D2: 401→200 126.619 ms, REGISTER→200 252.625 ms, negativa 401.
- D3: V7 vulnerable 1→0 (4 BYE/4×200); mitigado 1→1 (3 BYE/3×403).
- V1/V2/V3: métricas de referencia del set final.

Cada fila incluye `evidence_file` y `sha256`.

## 2. Capturas

- D0: `d0_gtp/gtp_ping_1001-1002.pcap`, `gtp_dial_1001-1000.pcap`.
- D1: `d1_lte_auth/s1ap_attach.pcap`.
- D2: `d2_ims_auth/ims_auth_clean.pcap`, `ims_auth_negative.pcap`.
- D3: `v7_d3/v7_{vuln,mit}_{dialog,attack}_*.pcap`.
- V1/V2/V3/V5: set histórico final en la raíz de `results/`.

## 3. Integridad

| Elemento | Resultado |
|---|---|
| `MANIFEST.csv` | 123 archivos |
| `hashes.txt` | regenerado desde el manifiesto |
| `hashes_historico.txt` | conserva el registro previo |
| `verificar.py` / `verificar.sh` | 123 OK / 0 faltantes / 0 diferencias |

Correcciones:

- V5: hash actual recalculado; el antiguo no coincidía con el archivo presente.
- V3: referencia corregida a `...T015138Z`.
- V7 histórico: se conserva, pero el cierre usa `v7_d3/` con BYE en el pcap.
- Línea histórica malformada de V7: preservada en `hashes_historico.txt`, no en el manifiesto actual.

## 4. Documentos actualizados

- `docs/04_cierre/INFORME_CIERRE.md`
- `docs/04_cierre/D0_RESULTADOS.md` … `D3_RESULTADOS.md`
- `voLTE-lab/results/README.md`
- V4 marcado como **sustituido por V7** en README, arquitectura, vectores y runbook.

## 5. Verificación

```bash
cd voLTE-lab
python3 results/verificar.py
# o: sh results/verificar.sh
```
