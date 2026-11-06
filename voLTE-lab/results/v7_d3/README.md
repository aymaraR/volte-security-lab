# V7 — SIP BYE forjado: cierre con evidencia en el cable

**Fecha:** 2026-11-04  
**Alcance:** V7 sustituye a V4 (cifrado radio) por solicitud de la empresa.  
**Resultado:** **V7 cerrado**: vulnerable con BYE en el pcap y llamada `1 -> 0`; mitigado con BYE en el pcap, `403` y llamada `1 -> 1`.

## 1. Por qué se rehizo la evidencia

Los pcaps anteriores de V7 tenían `BYEs=0`: el script detenía `tcpdump` antes de enviar el BYE. El veredicto dependía de `core show channels`, no del paquete.

El nuevo `vectores/v7_cierre.sh` captura en **dos fases**:

1. **Diálogo:** INVITE / 200 / ACK; extrae `Call-ID`, `From-tag`, `To-tag`, `CSeq` y `Contact`.
2. **Ataque:** inicia una segunda captura, envía el BYE, espera la respuesta y recién entonces cierra.

La validación exige `BYEs >= 1` y respuesta en el pcap. Si no, el script falla.

## 2. V7 vulnerable

| Campo | Valor |
|---|---|
| Escenario | `vuln` |
| Timestamp | `20261104T131504Z` |
| Call-ID | `85f8e593ca1eca47` |
| From-tag | `4775414dff317b20` |
| To-tag | `650bd547-e9f6-4210-b52a-af596b8752d0` |
| CSeq BYE | `31848` |
| R-URI | `sip:172.20.0.7:5061` |
| Canales PJSIP | **1 -> 0** |
| BYE en pcap | **4** |
| `200 OK` al BYE | **4** |
| `403/481` | 0 |

Evidencia:

- `v7_vuln_dialog_20261104T131504Z.pcap`
- `v7_vuln_attack_20261104T131504Z.pcap`
- `v7_vuln_metrics_20261104T131504Z.txt`

En el ataque se ve `BYE 172.20.0.99 -> 172.20.0.6`, reenvío a `172.20.0.7` y `200 OK` de vuelta. El estado vulnerable se generó con `parches/revertir.sh`; por diseño de ese script, la llamada vulnerable corre por bridge.

## 3. V7 mitigado

| Campo | Valor |
|---|---|
| Escenario | `mit` |
| Timestamp | `20261104T131837Z` |
| Call-ID | `cb99d061afd06aa3` |
| From-tag | `245dd0254436f4ed` |
| To-tag | `1ea4c17c-adb9-460b-bdfc-4a81e2073fbf` |
| CSeq BYE | `55281` |
| R-URI | `sip:172.20.0.7:5061` |
| Canales PJSIP | **1 -> 1** |
| BYE en pcap | **3** |
| `200 OK` al BYE | 0 |
| `403/481` | **3** |

Evidencia:

- `v7_mit_dialog_20261104T131837Z.pcap`
- `v7_mit_attack_20261104T131837Z.pcap`
- `v7_mit_metrics_20261104T131837Z.txt`

La contramedida es el binding IMPU↔IP de origen en el P-CSCF (más TLS en Gm). El atacante `.99` no es el origen registrado; el P-CSCF responde `403` y la llamada sigue.

## 3bis. Re-ejecución en la reproducción limpia D5

Sobre el laboratorio recién reconstruido desde volúmenes vacíos:

| Escenario | Timestamp | Canales | BYE | Respuesta |
|---|---|---|---|---|
| Mitigado | `20261104T134934Z` | 1 → 1 | 3 | 3×403 |
| Vulnerable | `20261104T135125Z` | 1 → 0 | 4 | 4×200 |

`scripts/restaurar_mitigado.sh` restauró después la configuración D2+mitigada y verificó `1001/1002 200 OK`. Esto valida además que `parches/aplicar.sh` conserva `ims_auth`.

## 4. Resumen de paquetes

`v7_bye_packets.txt` muestra:

```text
VULNERABLE: BYE .99 -> .6 -> .7; 200 OK de .7 -> .6 -> .99
MITIGADO:   BYE .99 -> .6; 403 de .6 -> .99
```

## 5. Evidencia y hashes

Directorio: `voLTE-lab/results/v7_d3/`

- `v7_*_dialog_*.pcap`
- `v7_*_attack_*.pcap`
- `v7_*_metrics_*.txt`
- `v7_bye_packets.txt`
- `v7_metrics.csv`
- `v7_channels.txt`
- `SHA256SUMS.txt` (verificado)

## 6. Reproducir

```bash
cd voLTE-lab
docker compose up -d kali
# estado vulnerable
sh parches/revertir.sh
sh vectores/v7_cierre.sh vuln

# estado mitigado (restaurar la configuracion D2+mitigada del backup)
sh scripts/restaurar_mitigado.sh
sh vectores/v7_cierre.sh mit
```

> El backup `d3_mitigado_backup/` conserva la configuración con TLS + binding + `ims_auth` de D2. Así V7 mitigado no pierde la autenticación IMS ya validada.

## 7. V4

V4 no se ejecuta: queda **sustituido por V7** según solicitud de la empresa. El script `v4_cipher.sh` se conserva como anexo opcional, pero no es criterio de cierre.
