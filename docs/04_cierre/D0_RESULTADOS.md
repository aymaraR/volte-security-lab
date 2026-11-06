# D0 — Resultados de ejecución (2026-11-04)

**Objetivo D0:** preflight, parche GTP y validación de estabilidad.  
**Resultado:** **D0 cumplido**. El laboratorio levanta 13/13, el plano GTP-U transporta datos y una llamada 1001→1000 cursa por el túnel.

---

## 1. Preflight

- Docker Desktop iniciado y daemon disponible.
- Imágenes presentes: `srsran-zmq`, `open5gs-local`, `kamailio-ims`, `asterisk-ims`, `pyhss-local`, `mongo:4.4`, `redis:7.0-alpine`.
- Rama de trabajo: `cierre-v7-gtp`.
- Respaldo de `results/` en `%TEMP%\opencode\volte_backup\results_20261104`.

---

## 2. Causas raíz encontradas

### 2.1 srsUE enviaba `Attach Complete` con EBI 9

Evidencia:

- MME: `ERROR: No Bearer : EBI[9]` inmediatamente después de `Attach Complete`.
- Captura S1AP: el `Activate Default EPS Bearer Context Request` bajaba con EBI **5**, pero el `Attach Complete` subía con EBI **9** (`92 00 c2`).
- srsUE: `DIAG_ESM first=0x99 ebi=9`; el parser entregaba un EBI corrupto y el `gw` intentaba enviar datos con EBI 9:
  `Can't deliver SDU for EPS bearer 9. Dropping it.`

**Solución aplicada:** workaround en `nas.cc` que fuerza `EBI=5` y `PTI=1` **antes** de `gw->setup_if_addr`. Así el TUN, el bearer manager y el `Attach Complete` quedan coherentes.

- Archivo: `voLTE-lab/srsran/patches/fix_ebi.py`
- Imagen: `voLTE-lab/srsran/Dockerfile.cierre` (deriva de `srsran-zmq:latest` y recompila solo `srsue`).

### 2.2 SGW-U GTP-U en loopback

Evidencia:

- `ss` en Open5GS: `open5gs-sgwud` escuchaba GTP-U en `127.0.0.6:2152`.
- El eNB recibía `transportLayerAddress 127.0.0.6` en S1AP y enviaba GTP-U a loopback; `ogstun` no recibía nada.
- `ogstun` RX=0 pese a que el UE transmitía.

**Solución aplicada:** `open5gs-config/sgwu.yaml` con:

```yaml
sgwu:
  gtpu:
    server:
      - address: 172.20.0.3
```

y montaje en `docker-compose.yml`:

```yaml
- ./open5gs-config/sgwu.yaml:/etc/open5gs/sgwu.yaml
```

### 2.3 `ogstun` y keepalive tardíos

- `ogstun` se levantaba en el paso 13, después de los attach.
- El keepalive anterior solo reponía rutas, no mantenía el bearer.

**Solución aplicada en `lab-up.sh`:**

- `ogstun_up` después de inicializar el MME y antes de eNB/UE.
- `net_keepalive` con ICMP cada 10 s, iniciado inmediatamente después de cada attach.
- `net_routes` (rutas `172.20.0.6/32` y `.7/32` al túnel) solo en el paso 13.

---

## 3. Validación

### 3.1 Levantado

`./lab-up.sh` completó los **13 pasos**:

- `srsue attached OK`
- `srsue2 attached OK`
- `1001 y 1002 registrados OK`
- `sip_listen srsue = 10.45.0.2:5060`
- `sip_listen srsue2 = 10.45.0.3:5060`
- `plano de usuario configurado`

### 3.2 Plano de usuario

| Prueba | Resultado |
|---|---|
| `ping -I tun_srsue 10.45.0.1` UE1 | 600/600, 0 % pérdida, 600.7 s, RTT 0–331 ms |
| `ping -I tun_srsue 10.45.0.1` UE2 | 10/10, 0 % pérdida, RTT 26–169 ms |
| `ogstun` RX/TX | RX 37 pkts / TX 42 pkts durante la ventana |
| `No Bearer EBI[9]` | 0 ocurrencias después del fix |
| `Can't deliver SDU` | 0 ocurrencias después del fix |
| detach / re-attach | 0 en 15 min de logs |

### 3.3 Captura GTP-U

- Punto: `open5gs:eth0`, filtro `udp port 2152`.
- 168 paquetes en 37.15 s (pings).
- TEIDs:
  - UE1 UL `0x5019`, DL `0x1`.
  - UE2 UL `0x761a`, DL `0x1`.
- Evidencia: `voLTE-lab/results/d0_gtp/gtp_ping_1001-1002.pcap`.

### 3.4 Llamada 1001→1000 por GTP

- Baresip registrado por TLS (`200 OK`, 2 bindings).
- Llamada establecida con SRTP (`AES_CM_128_HMAC_SHA1_80`), PCMU 64 kbps.
- Asterisk: `1 active channel` / `1 active call`, aplicación `Echo()`.
- Duración: 15 s.
- Captura GTP-U: 254 181 bytes.
- Evidencia: `voLTE-lab/results/d0_gtp/gtp_dial_1001-1000.pcap` y `baresip_dial_1001-1000.log`.

---

## 4. Cambios en el repositorio

| Archivo | Estado |
|---|---|
| `voLTE-lab/lab-up.sh` | modificado: `ogstun` temprano, keepalive ICMP, rutas al túnel |
| `voLTE-lab/open5gs-config/sgwu.yaml` | nuevo: GTP-U en 172.20.0.3 |
| `voLTE-lab/docker-compose.yml` | modificado: monta `sgwu.yaml` |
| `voLTE-lab/srsran/Dockerfile.cierre` | nuevo: imagen con workaround EBI |
| `voLTE-lab/srsran/patches/fix_ebi.py` | nuevo: parche srsUE |
| `voLTE-lab/results/d0_gtp/` | evidencia D0 |
| `srsran-zmq:latest` | imagen recompilada |

---

## 5. Criterio de salida D0

| Criterio | Estado |
|---|---|
| Docker/imágenes OK | ✅ |
| `lab-up.sh` 13/13 | ✅ |
| Túnel estable ≥ 10 min | ✅ 600/600 pings, 600.7 s, 0 % pérdida, 0 detach |
| 0 % pérdida | ✅ |
| Llamada por GTP | ✅ 15 s, SRTP, Asterisk Echo |

> La ventana formal de 10 min quedó cerrada con `results/d0_gtp/ping_stability_ue1.log` (600/600). Los logs de Open5GS de 15 min no muestran `Detach`, `Service request` ni `No Bearer`.

---

## 6. Siguiente bloque (D1)

1. Captura S1AP/NAS y demostrar autenticación LTE.
2. Implementar `ims_auth` en S-CSCF y provisionar AuC/Subscriber en PyHSS.
3. Capturar REGISTER 401→200 y prueba negativa.
4. Recién después: V7 con BYE en el pcap.
