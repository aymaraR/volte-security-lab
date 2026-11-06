# D5 — Reproducción limpia del laboratorio (2026-11-04)

**Objetivo:** verificar que el laboratorio se reconstruye desde cero con la evidencia y los cambios de cierre.  
**Resultado:** **D5 completado**. `lab-up.sh` **13/13** desde volúmenes eliminados; `scripts/aceptacion.sh` **PASS**; integridad **OK**.

---

## 1. Incidencia detectada y corregida

La primera corrida limpia falló en el paso 8 (`eNB1 sin S1`) porque `docker compose down -v` no elimina los contenedores manuales `srsenb2`/`srsue2` creados por `lab-up.sh` en corridas anteriores. El MME seguía viendo 2 eNB y el healthcheck que espera “1” daba falso negativo.

Corrección en `lab-up.sh`:

```sh
docker rm -f srsenb2 srsue2 >/dev/null 2>&1 || true
```

Comentario agregado en el script. Con esa corrección, la segunda corrida limpia pasó.

---

## 2. Secuencia limpia ejecutada

```bash
cd voLTE-lab
docker compose down -v
docker ps -a --format '{{.Names}}' \
  | grep -E '^(srsue|srsue2|srsenb|srsenb2|open5gs|kamailio|asterisk|kali|pyhss_hss|pyhss_api|pyhss_diameter|mongodb|redis)$' \
  | xargs -r docker rm -f
./lab-up.sh
sh scripts/aceptacion.sh
python3 results/verificar.py
```

Resultado de `lab-up`:

- `srsue attached OK`
- `srsue2 attached OK`
- `1001 y 1002 registrados OK`
- `sip_listen srsue = 10.45.0.2:5060`
- `sip_listen srsue2 = 10.45.0.3:5060`
- `plano de usuario configurado`
- **13/13**

## 3. Aceptación

`scripts/aceptacion.sh` ejecutó:

- contenedores requeridos;
- `tun_srsue` en UE1/UE2;
- ping a `10.45.0.1` con **0 % pérdida**;
- ruta IMS por túnel;
- `1001` y `1002` con `200 OK`;
- Asterisk registrado;
- Open5GS sin `No Bearer`/`Attach Reject`;
- verificador de integridad.

Salida final:

```text
ACEPTACION: PASS
```

## 4. Integridad

Después de agregar los logs de reproducción:

```text
MANIFEST.csv: 123 archivos
hashes.txt: 123 entradas
OK: 79
FALTANTES: 0
DIFERENTES: 0
```

## 5. Evidencia de D5

Directorio: `voLTE-lab/results/reproduccion/`

- `down_20261104T133100Z.log`
- `rm_20261104T133100Z.log`
- `lab-up_20261104T133100Z.log`
- `aceptacion_20261104T133100Z.log`
- `v7_clean_20261104T134934Z.log` (V7 mitigado + vulnerable + restauración D2)
- `restauracion_d2_despues_v7.txt` (1001/1002 200; Asterisk registrado)
- `aceptacion_post_v7_*.log` (aceptación final posterior a V7: PASS)
- `aceptacion_extendido_*.log` (aceptación final con V6/AKA/V5 extendidos: PASS)
- `aceptacion_final_*.log` (aceptación final tras restaurar V5: PASS)
- `.last_ts`

## 6. Criterio de salida D5

| Criterio | Estado |
|---|---|
| Volúmenes eliminados | ✅ |
| Contenedores manuales residuales eliminados | ✅ |
| `lab-up.sh` 13/13 | ✅ |
| Aceptación PASS | ✅ |
| Integridad OK | ✅ |
| V7 D3 conservado | ✅ (`results/v7_d3/`) |

## 7. V7 en la corrida limpia

Sobre el laboratorio limpio se repitieron ambos estados:

| Escenario | Timestamp | Canales | BYE | Respuesta |
|---|---|---|---|---|
| Mitigado | `20261104T134934Z` | 1 → 1 | 3 | 3×403 |
| Vulnerable | `20261104T135125Z` | 1 → 0 | 4 | 4×200 |

Después se restauró D2+mitigado con `scripts/restaurar_mitigado.sh`; 1001/1002 volvieron a `200 OK`. Esto también valida que `parches/aplicar.sh` conserva `ims_auth`.

## 8. Reproducción completa

```bash
cd voLTE-lab
docker compose down -v
docker rm -f srsenb2 srsue2 2>/dev/null || true
./lab-up.sh
sh scripts/aceptacion.sh
python3 results/verificar.py
```
