# D3 — Cierre de V7 y sustitución de V4 (2026-11-04)

**Objetivo D3:** cerrar V7 con evidencia en el cable (BYE + respuesta) y formalizar que V4 se sustituye por V7.  
**Resultado:** **D3 completado**. V7 vulnerable `1 -> 0`; V7 mitigado `1 -> 1`; ambos pcaps contienen el BYE.

---

## 1. Resultado V7

| Escenario | Canales PJSIP | BYE en pcap | Respuesta | Veredicto |
|---|---|---|---|---|
| Vulnerable | 1 → 0 | 4 | 4 × `200 OK` | **VULNERABLE** |
| Mitigado | 1 → 1 | 3 | 3 × `403` | **MITIGADO** |

### Vulnerable
- Call-ID `85f8e593ca1eca47`; CSeq `31848`; R-URI `sip:172.20.0.7:5061`.
- BYE de `.99 -> .6 -> .7`; `200 OK` de `.7 -> .6 -> .99`.
- Evidencia: `v7_vuln_dialog_20261104T131504Z.pcap`, `v7_vuln_attack_20261104T131504Z.pcap`.

### Mitigado
- Call-ID `cb99d061afd06aa3`; CSeq `55281`; R-URI `sip:172.20.0.7:5061`.
- BYE de `.99 -> .6`; `403` de `.6 -> .99`; llamada sigue.
- Evidencia: `v7_mit_dialog_20261104T131837Z.pcap`, `v7_mit_attack_20261104T131837Z.pcap`.

## 2. Corrección del método de evidencia

`vectores/v7_cierre.sh` implementa:

1. captura del diálogo (INVITE/200/ACK);
2. extracción de Call-ID/tags/CSeq/Contact;
3. segunda captura durante el BYE;
4. validación obligatoria de `BYEs >= 1` y respuesta;
5. veredicto solo si el pcap y los canales coinciden.

Esto corrige el defecto de los pcaps antiguos (`BYEs=0`).

## 2bis. Re-ejecución limpia D5

Sobre el laboratorio reconstruido desde volúmenes vacíos se repitieron ambos estados:

| Escenario | Timestamp | Canales | BYE | Respuesta |
|---|---|---|---|---|
| Mitigado | `20261104T134934Z` | 1 → 1 | 3 | 3×403 |
| Vulnerable | `20261104T135125Z` | 1 → 0 | 4 | 4×200 |

Después se restauró D2+mitigado con `scripts/restaurar_mitigado.sh` y 1001/1002 volvieron a `200 OK`.

## 3. V4: sustitución formal- V4 (EEA0/EEA2) **no se ejecuta** en el cierre.
- Se declara **“Sustituido por V7 a solicitud de la empresa”**.
- `vectores/v4_cipher.sh` queda como anexo opcional.
- V7 pasa a ser el vector obligatorio de cierre.

## 4. Evidencia

Directorio: `voLTE-lab/results/v7_d3/`

- `v7_vuln_dialog_*.pcap`, `v7_vuln_attack_*.pcap`
- `v7_mit_dialog_*.pcap`, `v7_mit_attack_*.pcap`
- `v7_vuln_metrics_*.txt`, `v7_mit_metrics_*.txt`
- `v7_bye_packets.txt`
- `v7_metrics.csv`, `v7_channels.txt`
- `README.md`
- `SHA256SUMS.txt` (verificado)

## 5. Criterio de salida D3

| Criterio | Estado |
|---|---|
| V7 vulnerable con BYE en pcap | ✅ 4 BYE + 4×200 |
| V7 vulnerable 1→0 | ✅ |
| V7 mitigado con BYE en pcap | ✅ 3 BYE |
| V7 mitigado 403 y 1→1 | ✅ 3×403 |
| V4 marcado como sustituido | ✅ |
| Evidencia con hashes | ✅ |

## 6. Siguiente: D4/D5

- Consolidar métricas/capturas y reparar `hashes.txt`.
- Actualizar informe final y matriz de trazabilidad.
- Reproducción limpia completa del laboratorio.
