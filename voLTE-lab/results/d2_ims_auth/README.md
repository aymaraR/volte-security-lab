# D2 — Autenticación IMS resuelta (REGISTER 401 → 200)

**Fecha:** 2026-11-04  
**Resultado:** **D2 cumplido**. El S-CSCF exige challenge IMS, baresip responde con las credenciales del IMPI y obtiene `200 OK`. Credencial incorrecta → `401`, sin `200`; al restaurar la correcta vuelve `200 OK`.  
**Integración:** `lab-up.sh` completó **13/13** con autenticación IMS; 1001 y 1002 quedaron `200 OK` y el túnel GTP operativo.

## 1. Flujo observado

Captura: `ims_auth_clean.pcap` (S-CSCF, UDP/6060; el tramo Gm UE↔P-CSCF sigue en TLS).

| Frame | Mensaje | Δ |
|---|---|---|
| 5 | REGISTER inicial | — |
| 6 | **401 Unauthorized** (`Digest ... algorithm=MD5, qop="auth"`) | +126.006 ms |
| 7 | REGISTER con `Authorization` (IMPI `001010123456789@ims...`) | +3.230 ms |
| 8 | **200 OK (REGISTER)** | +123.389 ms |

- **401 → 200:** 126.619 ms.
- **REGISTER inicial → 200:** 252.625 ms.
- Algoritmo de desafío: **MD5** (fallback de laboratorio; ver limitaciones).
- IMPI autenticado: `001010123456789@ims.mnc070.mcc999.3gppnetwork.org`.
- **1002** también verificó `200 OK` con su IMPI (`baresip2_valid.log`).

## 2. Cambios aplicados

### S-CSCF
- `kamailio/scscf/scscf.cfg`: carga `ims_auth.so`, parámetros Cx, `registration_default_algorithm=MD5`, `av_check_only_impu=1`, challenge y rutas MAR.
- `kamailio/Dockerfile.cierre`: compila `ims_auth.so` (la imagen base no lo traía) y lo instala en `/usr/local/lib64/kamailio/modules/`.
- `1000` (Asterisk/TAS) queda exento del challenge como nodo interno de confianza del laboratorio.

### PyHSS
- `pyhss/lib/diameter.py`: fallback IMPU→IMSI en `Answer_16777216_303`. El primer REGISTER sin `Authorization` usa `1001` como private identity; PyHSS lo traduce al IMSI real y busca AuC/Subscriber.
- `pyhss/provision_ims_auth.py`: crea APN, AuC y Subscriber para `001010123456789` y `001010123456790` con K/OPc/AMF coherentes con MongoDB/UE.
- Invocado desde `lab-up.sh` paso 5.
- Imagen `pyhss-local:latest` reconstruida con el fallback.

### baresip
- `srsran/baresip-config/accounts`: `auth_user=IMPI` y `auth_pass=Ki` para 1001; `.lab-tmp/baresip2/accounts` para 1002.
- Esto permite Digest-MD5 contra PyHSS (PyHSS usa el Ki como password digest).

## 3. Prueba negativa

`ims_auth_negative.pcap` + `baresip_negative.log`:

- Se cambió temporalmente `auth_pass` a `wrongpass`.
- baresip recibió **401 Unauthorized** y no obtuvo `200` para el nuevo binding.
- La captura incluye un `200` previo de **remove binding** con la credencial válida; después del cambio solo hay `401` repetidos.
- Al restaurar la credencial correcta: **200 OK** (`baresip_valid.log`).

## 4. Evidencia

| Archivo | Contenido |
|---|---|
| `ims_auth_clean.pcap` | REGISTER → 401 → REGISTER autenticado → 200 |
| `ims_auth_negative.pcap` | password incorrecta → 401 repetidos |
| `ims_auth_sequence.txt` | Secuencia y timestamps |
| `ims_auth_detail.txt` | `WWW-Authenticate`, `Authorization`, IMPI, algoritmo |
| `ims_auth_negative_sequence.txt` | Secuencia negativa |
| `ims_auth_metrics.csv` | Métricas de desafío/respuesta |
| `baresip_valid.log` | 200 OK final |
| `baresip_negative.log` | 401 con password incorrecta |
| `pyhss_state.txt` | APN/AUC/Subscriber/IMS subscriber |
| `pyhss_aka_vector.txt` | Vector AKA generado por PyHSS |
| `pyhss_impu_fallback.txt` | Fallback IMPU→IMSI |
| `scscf_auth_config.txt` | Configuración `ims_auth` |
| `accounts_auth.txt` | Cuenta baresip con IMPI/Ki |
| `SHA256SUMS.txt` | Integridad |

## 5. Limitaciones y notas

- **MD5 es un fallback de laboratorio** para interoperar con baresip. La VoLTE de producción usa **AKAv1-MD5/IMS-AKA**; la infraestructura `ims_auth` ya está habilitada y puede conmutarse a AKA con un cliente que lo soporte.
- Asterisk/TAS `1000` se considera nodo interno y no se le exige challenge; documentado como decisión de laboratorio.
- El contenedor `kamailio` de `lab-up.sh` se crea con `sleep infinity` y los 3 CSCF se lanzan por `docker exec`. **No hacer `docker restart kamailio` sin relanzar los 3 procesos**; usar `lab-up.sh` o relanzar scscf/icscf/pcscf y reponer la ruta `10.45.0.0/24`.
- El slice de autenticación usa un único `AUC`/`SUBSCRIBER` por IMSI; el `IMS_SUBSCRIBER` (servicio) sigue mapeando MSISDN→IMSI.

## 6. Reproducir

```bash
cd voLTE-lab
# imágenes de cierre
docker build -f kamailio/Dockerfile.cierre -t kamailio-ims:latest ./kamailio
docker build -f pyhss/docker/Dockerfile -t pyhss-local:latest ./pyhss
# levantar (lab-up provisiona APN/AUC/Subscriber)
./lab-up.sh
```

La evidencia se captura en el netns de `kamailio`:

```bash
docker exec -d kamailio sh -c \
  "timeout 20 tcpdump -i any -s0 -w /tmp/ims_auth.pcap 'udp port 6060'"
# reiniciar baresip para forzar REGISTER
```
