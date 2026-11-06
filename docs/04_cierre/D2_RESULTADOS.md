# D2 — Resultados de autenticación IMS (2026-11-04)

**Objetivo D2:** resolver la autenticación IMS con challenge/respuesta real y dejar evidencia.  
**Resultado:** **D2 completado**. `REGISTER → 401 → REGISTER autenticado → 200 OK`; password incorrecta → `401`.  
**Integración:** `lab-up.sh` completó **13/13** con la autenticación IMS activa; 1001 y 1002 quedaron `200 OK` y con GTP operativo.

---

## 1. Secuencia válida

Captura: `voLTE-lab/results/d2_ims_auth/ims_auth_clean.pcap`.

| Frame | Mensaje | Δ |
|---|---|---|
| 5 | REGISTER inicial | t0 |
| 6 | 401 Unauthorized (`algorithm=MD5`, `qop=auth`) | +126.006 ms |
| 7 | REGISTER con Authorization (IMPI `001010123456789@ims...`) | +3.230 ms |
| 8 | 200 OK | +123.389 ms |

- 401→200: **126.619 ms**
- REGISTER→200: **252.625 ms**
- Algoritmo: **MD5** (fallback de laboratorio)
- IMPI: `001010123456789@ims.mnc070.mcc999.3gppnetwork.org`
- **1002** también verificó `200 OK` con su IMPI (`baresip2_valid.log`).

## 2. Prueba negativa

`ims_auth_negative.pcap`:

- Con password incorrecta, baresip recibe **401** y no obtiene 200 para el nuevo binding.
- Al restaurar la credencial correcta: **200 OK** (`baresip_valid.log`).
- `baresip_negative.log` conserva el 401 del cliente.

## 3. Implementación

| Componente | Cambio |
|---|---|
| S-CSCF | `ims_auth.so`, Cx a `hss.ims...`, challenge MD5, `av_check_only_impu=1`, ruta MAR |
| Kamailio | `kamailio/Dockerfile.cierre` compila `ims_auth.so` (la imagen base no lo traía) |
| PyHSS | fallback IMPU→IMSI en `Answer_16777216_303`; AuC/Subscriber para 1001/1002 |
| PyHSS | `provision_ims_auth.py` invocado desde `lab-up.sh` paso 5 |
| baresip | `auth_user=IMPI`, `auth_pass=Ki` |
| Asterisk | 1000 exento de challenge como TAS interno |

## 4. Evidencia

Directorio: `voLTE-lab/results/d2_ims_auth/`

- `ims_auth_clean.pcap`, `ims_auth_negative.pcap`
- `ims_auth_sequence.txt`, `ims_auth_detail.txt`
- `ims_auth_negative_sequence.txt`
- `ims_auth_metrics.csv`
- `baresip_valid.log`, `baresip_negative.log`
- `pyhss_state.txt`, `pyhss_aka_vector.txt`, `pyhss_impu_fallback.txt`
- `scscf_auth_config.txt`, `accounts_auth.txt`
- `SHA256SUMS.txt` (verificado)

## 5. Limitaciones

- **MD5** es fallback para baresip; la VoLTE real usa AKA. La plataforma `ims_auth` ya está habilitada para conmutar a `AKAv1-MD5` con un cliente compatible.
- Asterisk 1000 se considera nodo interno de confianza.
- El contenedor Kamailio del lab usa `sleep infinity` + 3 `docker exec`; un `docker restart kamailio` exige relanzar los 3 CSCF y reponer la ruta `10.45.0.0/24`.

## 6. Criterio de salida D2

| Criterio | Estado |
|---|---|
| Challenge 401 con `WWW-Authenticate` | ✅ |
| REGISTER autenticado con IMPI | ✅ |
| 200 OK | ✅ |
| Prueba negativa con password incorrecta | ✅ 401 |
| Restauración de credencial válida | ✅ 200 |
| Evidencia + hashes | ✅ |
