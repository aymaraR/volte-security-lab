# Plan de cierre técnico y documental
## VoLTE Security Lab — GTP-U, autenticación LTE/IMS, V7 y evidencia reproducible

**Estado de ejecución:** **D0–D5 completados** el 2026-11-04. Ver `D0_RESULTADOS.md` … `D5_REPRODUCCION.md`, `INFORME_CIERRE.md` y `voLTE-lab/results/`.

**Fecha de emisión:** 2026-11-04  
**Alcance:** laboratorio aislado `voLTE-lab` (red 172.20.0.0/24). Sin redes reales.  
**Objetivo:** cerrar los pendientes técnicos y dejar un paquete de evidencia verificable, reproducible y defendible ante la empresa/comité.

---

## 0. Resumen ejecutivo

El cierre se organiza en **cinco workstreams** sobre una **ruta crítica de 72 horas** (MVP) y un **cierre formal de 5 días hábiles**:

1. **GTP-U estable + llamada por el túnel** (no por el bridge).
2. **Autenticación LTE demostrada + autenticación IMS resuelta** (401/200 y prueba negativa).
3. **V7 cerrado con evidencia en el cable**, asumiendo que **V4 se sustituye por V7** por solicitud de la empresa.
4. **Métricas, capturas y manifiesto de integridad** completos.
5. **Informe actualizado + reproducción limpia** del laboratorio.

La prioridad absoluta es **V7 + GTP + evidencias verificables**. V6 y V5 no bloquean el cierre; V4 no se ejecuta: se documenta como sustituido.

---

## 1. Supuestos y decisiones de alcance

| Tema | Decisión |
|---|---|
| V4 (cifrado radio) | **Sustituido por V7** según solicitud de la empresa. No se persigue EEA0/EEA2. Se conserva el script como anexo opcional. |
| V7 (BYE forjado) | Pasa a ser vector obligatorio de cierre. Debe tener evidencia **vulnerable y mitigada**. |
| V6 (GTP-U injection) | Cerrado en alcance extendido: vulnerable + mitigado (ver 10.5). |
| V5 (rogue eNodeB) | Vulnerable condicionado: PCI 7 + attach OK en corrida 154002Z; sensible a ZMQ (ver 10.5). |
| Autenticación IMS | MD5 baseline + IMS-AKA real con 1003 (ver 10.5). |
| Ventana | MVP 72 h; cierre documental 5 días hábiles. |
| Evidencia | Todo archivo final vive en `voLTE-lab/results/` y se registra con SHA-256 + metadatos. |

---

## 2. Diagnóstico de partida (verificado en el repositorio)

### 2.1 Bloqueos técnicos

| Hallazgo | Impacto | Acción |
|---|---|---|
| Docker Desktop estaba detenido al momento de la auditoría | No se puede levantar el lab | Arrancarlo como primera acción del D0 |
| `lab-up.sh` levanta `ogstun` recién en el paso 13, después de ambos attach y del registro por bridge | El UE queda IDLE; el primer tráfico dispara `Service Request` rechazado (causa 9) y se pierde la ventana GTP | Subir `ogstun` antes del attach y mantener tráfico keepalive desde el attach |
| El keepalive actual solo repone rutas, no mantiene el bearer activo | El UE vuelve a IDLE a los ~30 s | Keepalive con ICMP/UDP cada 10 s, iniciado inmediatamente después del attach |
| El P-CSCF guarda `IMPU -> IP` y aplica el filtro también a `REGISTER` | Un re-registro desde la IP del túnel (10.45.0.x) choca con la IP del bridge (172.20.0.5) y recibe 403 | Excluir `REGISTER` del filtro; actualizar el binding solo con 2xx |
| El S-CSCF no carga `ims_auth` y el Dockerfile no compila ese módulo | El 200 OK actual no demuestra autenticación IMS | Agregar `ims_auth` al build y al `scscf.cfg`; provisionar AuC/Subscriber en PyHSS |
| PyHSS no recibe AuC/Subscriber LTE en el script de provisión | En un clon limpio no hay vectores AKA para 1001/1002 | Provisionar `auc` + `subscriber` con K/OPc/AMF/SQN coherentes con MongoDB |
| Los `.pcapng` de V7 tienen `BYEs=0` según el propio `hashes.txt` | La evidencia no prueba el BYE en el cable; solo prueba el estado de canales | Corregir `v7_bye.sh` para capturar durante el ataque y exigir `BYE >= 1` + respuesta |
| `hashes.txt` tiene líneas partidas (28–31) y un hash de V5 que no coincide con el archivo actual | El verificador no puede validar el set | Recalcular y reconstruir el manifiesto; no borrar historia, marcarla como archivada |
| `results/README.md` cita `v3_...T015102Z`, que no existe; el archivo real es `...T015138Z` | Referencia rota en el informe | Corregir referencia y reconciliar narrativa |
| No hay informe final en el repositorio | No hay entregable documental | Crear/actualizar el informe y anexo de reproducción |

### 2.2 Estado de evidencia actual

- Set final presente: V1 vulnerable/mitigado, V2 vulnerable/mitigado, V3 vulnerable/mitigado, V5, V7 vulnerable/mitigado, baseline.
- Los hashes de los archivos presentes coinciden **salvo** el V5 `v5_rogue_20261002T133213Z.log` (hash registrado `1bb709...` vs. real `bf7904...`): recalcular y dejar constancia del cambio.
- V7 actual: los pcaps describen `BYEs=0`; el veredicto `1->0` se apoya en Asterisk, no en el paquete BYE. **Esto no es suficiente para cerrar V7.**

---

## 3. Definición de terminado (Definition of Done)

El cierre se considera logrado solo si se cumplen todos estos criterios:

| # | Criterio | Evidencia mínima |
|---|---|---|
| D1 | Túnel GTP estable ≥ 10 min, IP de `tun_srsue` sin cambios, 0 detach/re-attach | ping 0 % pérdida + logs `Attach complete` sin `Detach` |
| D2 | Llamada 1001→1000 durante ≥ 60 s **por el túnel** | SIP 200 + RTP + captura GTP-U en S1-U + `ip route get` por `tun_srsue` |
| D3 | Autenticación LTE visible en NAS | `Authentication Request/Response` + `Security Mode Command/Complete` + `Attach Accept` |
| D4 | Autenticación IMS con challenge y respuesta | REGISTER → 401 → REGISTER con credenciales → 200; prueba negativa rechazada |
| D5 | V7 vulnerable con BYE en el cable | pcap con INVITE, 200, ACK, BYE y 200 al BYE; canales 1→0 |
| D6 | V7 mitigado con BYE rechazado | pcap con BYE y 403/481; canales 1→1; llamada sigue |
| D7 | Métricas completas | CSV consolidado con todas las métricas de la sección 6 |
| D8 | Integridad verificable | `MANIFEST.csv` + `hashes.txt` reparado + verificador que pasa 100 % |
| D9 | Informe actualizado | secciones de GTP, autenticación, V7, V4 sustituido, métricas y anexo de reproducción |
| D10 | Reproducción limpia | clon/volumen limpio → `lab-up.sh` → pruebas → hashes OK, ejecutado dos veces |

---

## 4. Ruta crítica y calendario

### 4.1 MVP 72 horas

| Ventana | Hito | Entregable | Criterio de salida |
|---|---|---|---|
| D0 (04-nov) AM | Preflight y congelamiento | rama/worktree, inventario, Docker arriba | `docker info` OK; evidencia actual auditada |
| D0 PM | GTP estabilizado | parche `lab-up.sh` + keepalive + `ogstun` temprano | ping 10 min, 0 detach |
| D1 AM | Llamada por GTP | pcap S1-U + SIP/RTP + métricas | llamada 60 s, 0 % pérdida |
| D1 PM | Autenticación LTE | pcap S1AP/NAS + tabla de tiempos | auth + security mode visibles |
| D2 AM | Autenticación IMS | `ims_auth` + PyHSS AuC/Subscriber + 401/200 | positiva y negativa |
| D2 PM | V7 vulnerable | pcap con BYE + 200; canales 1→0 | `BYEs >= 1` |
| D3 AM | V7 mitigado | pcap con BYE + 403/481; canales 1→1 | llamada sigue |
| D3 PM | Métricas + integridad | CSV, manifiesto, verificador | 100 % hashes OK |

### 4.2 Cierre formal 5 días hábiles

- **D4:** informe, figuras, tablas, matriz de trazabilidad.
- **D5:** reproducción limpia completa + buffer para incidencias + tag `v1.0-cierre`.

---

## 5. Plan de trabajo detallado

### Workstream A — Estabilizar LTE/GTP-U y demostrar llamada por ese recorrido

**Objetivo:** que el UE mantenga el bearer por defecto y que SIP/RTP viajen por `tun_srsue` → GTP-U → UPF, no por el bridge.

#### A1. Preflight (D0, 1 h)

```bash
docker info
docker compose version
docker images | grep -E 'srsran|open5gs|kamailio|asterisk|pyhss'
git status --short
git switch -c cierre-v7-gtp
```

- Verificar que existen las imágenes; si no, construir (60–90 min) y dejar el build corriendo en paralelo a la auditoría.
- Crear snapshot del estado actual: `git diff > /tmp/pre-cierre.diff` y copiar `results/` a una carpeta externa de respaldo.

#### A2. Correcciones de estabilización (D0, 3–4 h)

1. **Subir `ogstun` antes del attach** (paso 3 de `lab-up.sh`, no paso 13):
   ```bash
   docker exec open5gs sh -c 'ip addr add 10.45.0.1/16 dev ogstun 2>/dev/null || true; ip link set ogstun up'
   ```
2. **Keepalive activo desde el attach**, no desde el paso 13:
   ```bash
   # tras cada attach exitoso, antes de que expire rrc_inactivity_timer (30 s)
   docker exec -d srsue sh -c 'while true; do ping -I tun_srsue -c 1 -W 1 10.45.0.1 >/dev/null 2>&1; sleep 10; done'
   ```
   Hacer lo mismo para `srsue2`.
3. **Mantener las rutas al túnel** durante todo el ciclo (no borrarlas en el paso 12 si se va a usar GTP):
   ```bash
   ip route add 172.20.0.6/32 dev tun_srsue
   ip route add 172.20.0.7/32 dev tun_srsue
   ```
4. **No reiniciar baresip dos veces** (bridge y luego túnel) en la corrida de cierre: registrar directamente por túnel. Dejar el registro por bridge solo como fallback documentado.
5. **P-CSCF:** permitir que `REGISTER` actualice el binding aunque venga de otra IP; no aplicar el filtro de identidad a `REGISTER`. El filtro se mantiene para INVITE/BYE, que es donde aporta la contramedida V3/V7.
6. **No tocar `rrc_inactivity_timer`** con valores enormes. Si se pierde la ventana CONNECTED, reiniciar el par eNB+UE y repetir; no perseguir el `Service Request` en caliente.

#### A3. Verificación de estabilidad (D0–D1)

```bash
# IP y ruta
docker exec srsue sh -c 'ip -o addr show tun_srsue; ip route get 172.20.0.6; ip route get 172.20.0.7'

# 10 minutos de plano de usuario
docker exec srsue sh -c 'ping -I tun_srsue -c 600 -i 1 10.45.0.1'

# No debe haber detach/re-attach
docker logs --since 15m open5gs 2>&1 | grep -E 'Attach complete|Detach|Service Request|Attach Reject'
```

**Criterio de salida:** IP de túnel estable, 0 % pérdida, 0 detach en 10 min, `ip route get 172.20.0.6` muestra `dev tun_srsue`.

#### A4. Evidencia de GTP-U y llamada (D1)

Punto de captura correcto:

- **GTP-U (S1-U):** `srsenb` o `open5gs` sobre `eth0`, puerto **2152**.
- **Plano interno (ya decapsulado):** `ogstun` o `tun_srsue`.
- **No** capturar GTP-U en `ogstun`: allí ya no está el encabezado GTP.

```bash
# Captura GTP-U en el eNB durante la llamada
docker exec -d srsenb sh -c 'timeout 90 tcpdump -i eth0 -s 0 -w /tmp/gtpu_call.pcap udp port 2152'

# Llamada 1001 -> 1000 (echo)
docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/dial 1000@ims.mnc070.mcc999.3gppnetwork.org'"

# Captura interna en el UPF (opcional, para ver RTP decapsulado)
docker exec -d open5gs sh -c 'timeout 60 tcpdump -i ogstun -s 0 -w /tmp/ogstun_call.pcap udp'

# Colgar
docker exec srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/hangup'"
```

Análisis mínimo:

```bash
tshark -r /tmp/gtpu_call.pcap -Y 'gtp' -T fields -e frame.time_epoch -e ip.src -e ip.dst -e gtp.teid -e gtp.message
tshark -r /tmp/gtpu_call.pcap -q -z rtp,streams
tshark -r /tmp/ogstun_call.pcap -q -z rtp,streams
```

**Criterio de salida:** SIP 200, RTP bidireccional, TEID de subida y bajada distintos, llamada ≥ 60 s, 0 % pérdida, y `P-CSCF` ve el origen `10.45.0.x` (no 172.20.0.5).

---

### Workstream B — Demostrar autenticación LTE y resolver autenticación IMS

#### B1. Autenticación LTE (D1, 2–3 h)

1. Activar captura S1AP/NAS en `enb.conf`:
   ```ini
   [pcap]
   s1ap_enable = true
   s1ap_filename = /tmp/enb_s1ap.pcap
   ```
   Reiniciar `srsenb` (contenedor, no `pkill`) y repetir el attach.
2. Alternativa/complemento: `tcpdump -i eth0 -s 0 -w /tmp/s1ap.pcap sctp port 36412` en el eNB.
3. En el UE, conservar `/tmp/ue_nas.pcap` y `/tmp/ue_mac.pcap` (ya configurados en `ue.conf`).
4. Secuencia esperada en NAS:
   - `Attach Request`
   - `Authentication Request` / `Authentication Response`
   - `Security Mode Command` / `Security Mode Complete`
   - `Attach Accept` / `Attach Complete`
5. Verificar coherencia de credenciales:
   - K/OPc de MongoDB (`001010123456789`) = K/OPc usados por el UE (`ue.conf`).
   - AMF `8000`, SQN inicial `0`.
   - Sin `MAC failure`, sin `Authentication Reject`.

**Evidencia:** pcap S1AP/NAS + salida `tshark` filtrada + tabla con:
`attach_attempts`, `attach_time_ms`, `auth_req_to_resp_ms`, `security_mode_to_complete_ms`, `eea`, `eia`, `resultado`.

**Opcional (rigor):** crear un suscriptor de prueba con K incorrecta, intentar attach y documentar el rechazo; restaurar de inmediato. No tocar 1001/1002.

#### B2. Autenticación IMS (D2, 4–6 h)

**Hallazgo:** el S-CSCF actual no carga `ims_auth`; el `save()` no genera un challenge 401. El 200 OK observado no demuestra autenticación IMS. Además, el Dockerfile no compila `ims_auth`.

Pasos:

1. **Agregar `ims_auth` al build** de Kamailio:
   ```dockerfile
   make include_modules="... ims_auth ..." cfg
   ```
   Reconstruir `kamailio-ims:latest` (15–30 min).
2. **Provisionar PyHSS** con los datos LTE que faltan (en un clon limpio no existen):
   - `AuC` por IMSI con `ki`, `opc`, `amf=8000`, `sqn=0`.
   - `Subscriber` con `imsi`, `auc_id`, APN por defecto y lista de APNs.
   - `IMS_SUBSCRIBER` con `msisdn`, `imsi`, `ifc_path=default_ifc.xml`.
   - Verificar con la API (`/auc/...`, `/subscriber/...`, `/ims_subscriber/...`).
3. **Configurar `ims_auth` en `scscf.cfg`**:
   - `loadmodule "ims_auth.so"`
   - `modparam("ims_auth", "name", "sip:172.20.0.6:6060")`
   - `modparam("ims_auth", "registration_default_algorithm", "AKAv1-MD5")`
   - `modparam("ims_auth", "cxdx_dest_realm", "ims.mnc070.mcc999.3gppnetwork.org")`
   - Ruta `REGISTER` con `ims_www_authenticate()`, `ims_www_challenge()`, `ims_www_resync_auth()` y `save()` solo tras autenticación exitosa.
4. **Decidir algoritmo según cliente:**
   - Si el cliente soporta AKA: `AKAv1-MD5` (preferido, coherente con VoLTE).
   - Si baresip no soporta AKA: usar `MD5`/Digest-MD5 y **declararlo como limitación del laboratorio**. No afirmar “IMS AKA” si se usó MD5.
5. **Pruebas:**
   - REGISTER sin credenciales → `401 Unauthorized` con `WWW-Authenticate`.
   - REGISTER con credenciales correctas → `200 OK`.
   - REGISTER con password incorrecta → `401/403`, nunca 200.
   - Verificar `MAR/MAA` en Diameter Cx y `saa_return_code=1`.
6. **Corregir el binding del P-CSCF** para que el REGISTER legítimo desde 10.45.0.x no sea rechazado por el mapping previo del bridge.

**Evidencia:** pcap SIP (401 + REGISTER autenticado + 200 + intento negativo), logs de Kamailio/PyHSS, consulta API de suscriptor, tabla `challenge_code`, `auth_time_ms`, `register_time_ms`, `resultado`.

---

### Workstream C — Cerrar V7 y su evidencia (V4 sustituido)

**Objetivo:** demostrar que un BYE forjado termina una llamada activa (vulnerable) y que la contramedida lo rechaza (mitigado), con el BYE **presente en el pcap**.

#### C1. Problema actual de la evidencia

Los pcaps de V7 registran `BYEs=0`: el script `v7_bye.sh` detiene `tcpdump` antes de enviar el BYE. El veredicto `1->0` se apoya en `core show channels`, no en el paquete. Para el comité esto es evidencia indirecta.

#### C2. Corrección del script (D2)

Reordenar la captura en dos fases:

1. **Fase diálogo:** capturar el INVITE/200/ACK; detener; extraer `Call-ID`, `From-tag`, `To-tag`, `CSeq` y `Contact`.
2. **Fase ataque:** iniciar una segunda captura; enviar el BYE forjado; esperar 5 s; detener; copiar el pcap.
3. Exigir en la validación:
   ```bash
   tshark -r v7_attack.pcap -Y 'sip.Method == "BYE"' | wc -l          # >= 1
   tshark -r v7_attack.pcap -Y 'sip.CSeq.method == "BYE" && sip.Status-Code == 200' | wc -l  # >= 1 (vulnerable)
   ```
4. Si `BYEs=0`, el script debe salir con error y **no** registrar el hash como evidencia válida.

#### C3. Corrida vulnerable (D2)

1. `sh parches/revertir.sh` (estado vulnerable).
2. `lab-up.sh` con GTP estable.
3. Llamada 1001→1000 activa.
4. Ejecutar V7 con captura en dos fases.
5. Verificar:
   - `BYE` en pcap con `Call-ID`, tags y `CSeq` correctos.
   - `200 OK` al BYE.
   - Asterisk: canales `1 -> 0`.
   - Tiempo BYE→cierre < 1 s.
6. Evidencia:
   - `v7_bye_..._vuln_dialog.pcapng`
   - `v7_bye_..._vuln_attack.pcapng`
   - `v7_vuln_metrics.csv`
   - `v7_vuln_asterisk.txt` (`core show channels` antes/después)

#### C4. Corrida mitigada (D3)

1. `sh parches/aplicar.sh` (TLS + binding + pike).
2. Repetir la llamada y el ataque.
3. Para el BYE mitigado se pueden usar los tags capturados en la fase vulnerable (modelo realista: el atacante ya conoce el diálogo).
4. Verificar:
   - BYE presente en pcap.
   - Respuesta `403`/`481`, sin `200 OK` al BYE.
   - Asterisk: canales `1 -> 1`; la llamada sigue.
5. Evidencia:
   - `v7_bye_..._mit_dialog.pcapng`
   - `v7_bye_..._mit_attack.pcapng`
   - `v7_mit_metrics.csv`
   - `v7_mit_asterisk.txt`

#### C5. V4: cierre administrativo

- Actualizar todas las matrices (README raíz, `docs/03_arquitectura/03_ataques_a_implementar.md`, `kali.md`, `results/README.md`) para que V4 diga:
  **“Sustituido por V7 a solicitud de la empresa”**, no “bloqueado/pendiente”.
- Mantener `vectores/v4_cipher.sh` como anexo opcional, sin usarlo como criterio de cierre.
- En el informe, agregar un párrafo de justificación del cambio de alcance y su aprobación.

---

### Workstream D — Métricas, capturas e integridad del set

#### D1. Métricas a consolidar

Crear `results/metrics.csv` con esquema único:

```text
test_id,vector,scenario,timestamp_utc,metric,value,unit,source,evidence_file,sha256,result
```

Métricas mínimas:

| ID | Métrica | Escenario | Criterio |
|---|---|---|---|
| M01 | `attach_attempts` | LTE | 1 (ideal) |
| M02 | `attach_time_ms` | LTE | < 15 000 |
| M03 | `auth_req_resp_ms` | LTE | < 1 000 |
| M04 | `security_mode_ms` | LTE | < 1 000 |
| M05 | `eea` / `eia` | LTE | valores negociados |
| M06 | `gtp_stability_min` | GTP | ≥ 10 |
| M07 | `gtp_ping_loss_pct` | GTP | 0 |
| M08 | `detach_count` | GTP | 0 |
| M09 | `ims_challenge_code` | IMS | 401 |
| M10 | `ims_register_time_ms` | IMS | < 2 000 |
| M11 | `ims_negative_result` | IMS | 401/403, nunca 200 |
| M12 | `call_setup_ms` | Llamada | < 3 000 |
| M13 | `call_duration_s` | Llamada | ≥ 60 |
| M14 | `rtp_loss_pct` | Llamada | < 1 |
| M15 | `rtp_jitter_ms` | Llamada | < 30 |
| M16 | `gtp_teid_ul/dl` | GTP | 2 TEID distintos |
| M17 | `v7_bye_count` | V7 | ≥ 1 |
| M18 | `v7_terminate_ms` | V7 vulnerable | < 1 000 |
| M19 | `v7_channels_before/after` | V7 | 1/0 vulnerable; 1/1 mitigado |
| M20 | `v7_mitigated_response` | V7 mitigado | 403/481 |

Si se conservan V1/V2/V3 para el informe, mantener sus métricas ya existentes y referenciarlas; no recalcular todo si el alcance es V7.

#### D2. Capturas mínimas del set final

| ID | Punto de captura | Filtro | Duración | Propósito |
|---|---|---|---|---|
| C1 | `srsenb` eth0 | `sctp port 36412` | attach | NAS/S1AP auth LTE |
| C2 | `srsenb`/`open5gs` eth0 | `udp port 2152` | llamada 60 s | GTP-U, TEID |
| C3 | `srsue` `tun_srsue` | `udp` | llamada 60 s | SIP/RTP interno |
| C4 | `kamailio` any | `udp/tcp port 4060/5060/6060/5061` | registro + llamada | IMS auth/call |
| C5 | `kamailio` any | SIP | V7 diálogo | INVITE/200/ACK |
| C6 | `kamailio` any | SIP | V7 ataque | BYE + respuesta |
| C7 | `open5gs`/`srsenb` | GTP-U | llamada | prueba de túnel |

Reglas:
- `-s 0` para no truncar.
- Nombres con timestamp UTC y escenario: `v7_bye_1001-to-1000_<TS>_vuln_attack.pcapng`.
- Cada captura se analiza con `capinfos` y `tshark` antes de registrarla.

#### D3. Reparación de integridad

1. Recalcular SHA-256 de todos los archivos presentes en `results/`.
2. Reparar `hashes.txt`:
   - Unir las líneas partidas 28–31.
   - Recalcular el hash de V5 y dejar nota: `hash actualizado; el anterior correspondía a una copia archivada`.
   - No borrar entradas históricas: marcarlas `archivado` si el archivo no está en el set.
3. Crear `results/MANIFEST.csv`:

```text
file,vector,scenario,timestamp_utc,size_bytes,sha256,status,source_command,notes
```

4. Crear `results/verificar.sh`:
   - Recalcula hashes.
   - Compara contra `MANIFEST.csv`.
   - Falla con código ≠ 0 si hay diferencias.
   - Imprime resumen `OK / FALTANTE / DIFERENTE`.
5. Corregir `results/README.md`:
   - `v3_...T015102Z` → `v3_...T015138Z`.
   - Reconciliar “2 800 × 403” vs. “2 963 × 403” con el valor real del pcap.
   - Aclarar que V7 viejo tenía `BYEs=0` y fue reemplazado por el nuevo set.
6. Empaquetar el set final:
   ```bash
   tar -czf resultados_cierre_<fecha>.tar.gz results/
   sha256sum resultados_cierre_<fecha>.tar.gz
   ```

---

### Workstream E — Informe y reproducción completa

#### E1. Actualización del informe

Secciones mínimas a tocar:

1. **Arquitectura y path de la llamada:** explicar bridge vs. GTP-U y por qué el cierre exige GTP.
2. **LTE:** attach, autenticación EPS-AKA, Security Mode, algoritmos.
3. **IMS:** REGISTER, 401, credenciales, 200, Cx MAR/MAA; aclarar algoritmo usado.
4. **V7:** procedimiento, captura en dos fases, resultados vulnerable/mitigado, métricas.
5. **V4:** justificación de sustitución por V7 y aprobación de la empresa.
6. **Métricas:** tabla consolidada y figuras (RTT, pérdida, tiempos).
7. **Integridad:** manifiesto, hashes, comando de verificación.
8. **Limitaciones:** ZMQ, 2 UEs, IMS-AKA sin IPsec, V5 vulnerable condicionado (no estable al 100 %).
9. **Anexo de reproducción:** commit/tag, comandos, tiempos, salidas esperadas.

Agregar matriz de trazabilidad:

```text
Objetivo -> Prueba -> Comando -> Evidencia -> Métrica -> Resultado -> Conclusión
```

#### E2. Reproducción limpia (D5)

```bash
# 1. Partir de un estado limpio (sin volúmenes)
docker compose down -v

# 2. Reconstruir si cambió Dockerfile/kamailio
docker build -t kamailio-ims:latest ./kamailio
docker build -t srsran-zmq:latest ./srsran
# ... demás imágenes según corresponda

# 3. Levantar
./lab-up.sh

# 4. Pruebas de aceptación
sh scripts/aceptacion.sh   # a crear: attach + auth + GTP + IMS + llamada + V7

# 5. Verificar integridad
sh results/verificar.sh
```

Registrar:
- commit/tag exacto;
- duración de `lab-up`;
- incidencias y reintentos;
- diferencias respecto de la corrida de referencia;
- hash del paquete final.

**Criterio de salida:** dos reproducciones consecutivas con los mismos resultados y hashes verificables; si algo es no determinista (RF ZMQ), documentarlo y añadir reintento controlado.

---

## 6. Matriz de evidencias del cierre

| Vector/Objetivo | Evidencia | Estado actual | Acción |
|---|---|---|---|
| GTP-U estable | pcap S1-U + ping + logs | No existe | Generar en D0–D1 |
| Llamada por GTP | pcap S1-U + SIP/RTP + métricas | No existe | Generar en D1 |
| Auth LTE | pcap S1AP/NAS | No existe | Generar en D1 |
| Auth IMS | pcap 401/200 + logs Cx | No existe | Implementar y generar D2 |
| V7 vulnerable | pcap diálogo + pcap ataque | Parcial (`BYEs=0`) | Rehacer D2 |
| V7 mitigado | pcap ataque + 403/481 | Parcial (`BYEs=0`) | Rehacer D3 |
| V4 | — | Bloqueado | Marcar “sustituido por V7” |
| V1/V2/V3 | pcaps/csv/wav | Presentes | Mantener y verificar hashes |
| Integridad | `MANIFEST.csv` + `verificar.sh` | Incompleto | Reparar D3–D4 |
| Informe | documento actualizado | No existe en repo | Crear/actualizar D4 |

---

## 7. Riesgos y contingencias

| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Docker/imágenes no disponibles | Media | Alto | Arrancar Docker ya; construir en paralelo; no borrar volúmenes hasta el final |
| GTP vuelve a IDLE por hueco > 30 s | Alta | Alto | Keepalive desde el attach; si se pierde, reiniciar UE y repetir |
| `Service Request` causa 9 persiste | Media | Alto | Documentar ventana CONNECTED; no cambiar `rrc_inactivity_timer` a valores extremos; reiniciar par eNB+UE |
| P-CSCF rechaza REGISTER desde túnel | Alta | Medio | Excluir REGISTER del filtro idmap; actualizar binding con 2xx |
| `ims_auth` no compila o no está en la imagen | Media | Alto | Agregar al `include_modules`; rebuild; validar `kamailio -c` |
| baresip no soporta AKA | Media | Medio | Usar MD5 y declararlo; o cliente PJSIP/SIPp con AKA si el alcance lo exige |
| PyHSS sin AuC/Subscriber | Alta | Alto | Provisionar por API; verificar en clon limpio |
| V7 sin BYE en pcap | Alta | Alto | Captura en dos fases; validar `BYEs>=1`; no aceptar solo canales |
| Evidencia inconsistente | Alta | Alto | Manifiesto + verificador + recalcular V5 + corregir README |
| Tiempo insuficiente | Media | Alto | Priorizar GTP + auth + V7 + integridad; V5/V6 se ejecutaron al final en alcance extendido |

---

## 8. Checklist operativo de cierre

### D0 — Hoy

- [ ] Arrancar Docker Desktop y verificar `docker info`.
- [ ] Crear rama `cierre-v7-gtp` y respaldar `results/`.
- [ ] Auditar hashes y reparar `hashes.txt` (o dejar script listo).
- [ ] Parchear `lab-up.sh`: `ogstun` temprano + keepalive con ping desde attach.
- [ ] Verificar rutas al túnel y P-CSCF idmap para REGISTER.
- [ ] Levantar lab y validar 10 min de GTP estable.

### D1

- [ ] Capturar GTP-U en S1-U y llamada 1001→1000 por túnel.
- [ ] Capturar S1AP/NAS y demostrar auth LTE.
- [ ] Medir attach/auth/security mode.
- [ ] Registrar evidencia y hashes.

### D2

- [ ] Rebuild Kamailio con `ims_auth`.
- [ ] Provisionar AuC/Subscriber en PyHSS.
- [ ] Configurar challenge IMS y validar 401→200 + negativa.
- [ ] Corregir `v7_bye.sh` a captura en dos fases.
- [ ] Ejecutar V7 vulnerable con `BYEs>=1`.

### D3

- [ ] Aplicar parches y ejecutar V7 mitigado.
- [ ] Consolidar `metrics.csv`.
- [ ] Crear `MANIFEST.csv` y `verificar.sh`.
- [ ] Corregir `results/README.md` y referencias V3/V5/V7.

### D4–D5

- [ ] Actualizar informe y matriz de trazabilidad.
- [ ] Reproducción limpia completa.
- [ ] Verificar hashes y empaquetar.
- [ ] Tag `v1.0-cierre` y entrega.

---

## 9. Primeras acciones inmediatas (siguiente bloque de trabajo)

1. **Arrancar Docker Desktop** y confirmar que las imágenes existen.
2. **Congelar el estado actual** con rama y respaldo de `results/`.
3. **Aplicar el parche de GTP** (`ogstun` temprano + keepalive con ping + rutas).
4. **Levantar el lab** y ejecutar la prueba de 10 minutos.
5. **Recién después** tocar IMS auth y V7.

> Regla de oro: no se declara cerrado un vector si la evidencia no está en el cable y el hash no verifica. El estado de canales de Asterisk es corroboración, no prueba única.


---

## 10. Ampliacion de alcance (2026-11-04)

La empresa pidio considerar **V5 y V6 dentro del scope** como objetivos opcionales a dejar listos si el tiempo lo permite. Se agrega tambien la evaluacion de **IMS-AKA real**. Ninguno de estos bloquea el cierre D0-D5 ya verificado.

### 10.1 IMS-AKA real

**Valor:** alto para fidelidad 3GPP y defensa tecnica; medio para la aceptacion actual.

- Aporta autenticacion mutua basada en SIM (RAND/AUTN/RES), CK/IK y alineacion con TS 33.203.
- Evita la objecion "Digest-MD5 no es VoLTE" y habilita una futura fase de IPsec/Gm seguro.
- No cambia V7 ni GTP; es una dimension separada de autenticacion.

**Costo/riesgo:** baresip 1.0.0 probablemente no soporta AKAv1-MD5. Requiere un cliente compatible (SIPp/PJSIP/Linphone) o un modulo AKA; 1-2 dias si aparece friccion con Cx/IPsec.

**Decision recomendada:** mantener MD5 como baseline estable y agregar AKA como **prueba adicional** con SIPp/PJSIP, sin reemplazar baresip. Si no hay cliente compatible en la ventana, documentarlo como trabajo futuro.

### 10.2 V6 - GTP-U injection

**Prioridad: alta.** Ahora que GTP-U esta estable, es el vector extendido con mayor factibilidad.

DoD propuesto:

1. Descubrir el TEID DL real desde una captura S1-U (`eth0:2152`), no desde `ogstun`.
2. Inyectar 5 paquetes GTP-U desde Kali `.99` hacia el eNB `.4:2152` con TEID DL e IP interna de la UE.
3. Verificar respuesta/ICMP o paquete observado en S1-U, con pcap y metrica.
4. Mitigar con filtro GTP-U en el eNB (solo SGW-U `.3`) o allowlist de TEID/IP y re-ejecutar: 0 hits.
5. Evidencia en `results/v6_d3/` y hash.

### 10.3 V5 - Rogue eNodeB

**Prioridad: media.** Resultado final: vulnerable condicionado (PCI 7 + attach OK) con reproducibilidad sensible a ZMQ; ver 10.5.

DoD propuesto:

1. Repetir con una secuencia controlada: detener eNB legitimo, arrancar rogue en los mismos puertos ZMQ/PLMN/TAC, UE fresco y ventana amplia.
2. Verificar en MME/S1AP el `CellID`/PCI del rogue y el attach del IMSI.
3. Si no se logra atraccion, registrar el resultado negativo con metodologia y limitacion ZMQ; no etiquetarlo como mitigado.
4. Contramedida propuesta: allowlist de eNB/PCI y deteccion de PCI inesperado.

### 10.4 Orden recomendado

1. **V6** (determinista y apoyado en D0).
2. **IMS-AKA** (valor alto, costo medio).
3. **V5** (mayor dependencia de RF/ZMQ).

El cierre D0-D5 y el commit/tag `v1.0-cierre` no dependen de estos tres; se agregan como anexo extendido si se completan.


### 10.5 Resultados de la ampliacion (2026-11-04)

- **V6:** CERRADO. TEID downlink 0x00000002; 5 inyecciones con 5 respuestas
  ICMP de la UE; mitigado con filtro `tc` (solo SGW-U .3) y 0 respuestas.
  Evidencia en `results/v6_d3/`, script `vectores/v6_gtp_cierre.sh`.
- **IMS-AKA real:** CERRADO. 1003/IMPI 001010123456791 obtiene 401
  `AKAv1-MD5` y 200 con RES binario; evidencia en `results/aka_d3/`.
  Script `vectores/aka_cierre.sh` y `scripts/ims_aka_client.py`.
- **V5:** VULNERABLE CONDICIONADO. Tres corridas con reinicio de contenedor
  no sincronizaron; con eNB2 apagado y reinicio de proceso, PCI 7 + attach OK
  (UE IP 10.45.0.8). Evidencia `results/v5_d3/v5_success_20261104T154002Z.log`.

Detalle consolidado: `docs/04_cierre/EXTENDIDO_V5_V6_AKA.md`.
