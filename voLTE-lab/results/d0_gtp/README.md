# D0 — Estabilización LTE/GTP-U (2026-11-04)

Estado: **GTP-U operativo y llamada 1001→1000 por el túnel validada**.

## Cambios aplicados

| Archivo | Cambio |
|---|---|
| `voLTE-lab/lab-up.sh` | `ogstun` UP antes del attach; keepalive ICMP cada 10 s desde el attach; rutas al túnel en el paso 13 |
| `voLTE-lab/open5gs-config/sgwu.yaml` | SGW-U GTP-U bind/advertise en `172.20.0.3` (antes `127.0.0.6`, inalcanzable desde el eNB) |
| `voLTE-lab/docker-compose.yml` | monta `sgwu.yaml` en `/etc/open5gs/sgwu.yaml` |
| `voLTE-lab/srsran/Dockerfile.cierre` + `patches/fix_ebi.py` | workaround srsUE: fuerza EBI 5/PTI 1 antes de `setup_if_addr` |
| `srsran-zmq:latest` | imagen recompilada con el workaround de EBI |

## Validación

- `./lab-up.sh` completó **13/13** y ambos UE quedaron con `tun_srsue`:
  - UE1 `10.45.0.2/24`
  - UE2 `10.45.0.3/24`
- `ping -I tun_srsue 10.45.0.1`: 600/600, **0 % pérdida**, 600.7 s, RTT 0–331 ms.
- Sin `No Bearer : EBI[9]`, sin `Can't deliver SDU`, sin `Service request` ni detach durante 15 min de logs.
- Captura GTP-U en S1-U (`open5gs:eth0`, UDP/2152):
  - 168 paquetes, 37.15 s (ping bidireccional).
  - TEIDs UL `0x5019` (UE1) y `0x761a` (UE2); DL `0x1` por eNB.
- Llamada **1001 → 1000** por el túnel:
  - `1 active channel` / `1 active call` en Asterisk (`Echo()`).
  - Audio SRTP (AES_CM_128_HMAC_SHA1_80), PCMU 64 kbps, duración 15 s.
  - Captura GTP-U de la llamada: 254 181 bytes.

## Evidencia

| Archivo | Contenido |
|---|---|
| `gtp_ping_1001-1002.pcap` | GTP-U de pings UE1/UE2 |
| `gtp_dial_1001-1000.pcap` | GTP-U de la llamada 1001→1000 |
| `gtp_teids.txt` / `gtp_dial_teids.txt` | TEIDs y direcciones internas/externas |
| `gtp_capinfos.txt` / `gtp_dial_capinfos.txt` | resumen de capturas |
| `ping_stability_ue1.log` | ping de estabilidad (600 s) |
| `baresip_dial_1001-1000.log` | registro TLS, call established, SRTP, audio |
| `asterisk_channels_post_call.txt` | estado de canales |
| `open5gs_attach.txt` | attach/modify bearer sin errores |
| `open5gs_gtpu.txt` | `ogstun` y sockets GTP-U |
| `ue1_tun_rutas.txt`, `ue2_tun_rutas.txt` | IP y rutas del túnel |

## Reproducir

```bash
cd voLTE-lab
# imagen base (si no existe)
docker build -t srsran-zmq:latest ./srsran
# imagen con el workaround EBI
docker build -f srsran/Dockerfile.cierre -t srsran-zmq:latest ./srsran
./lab-up.sh
```

## Pendiente D1+

- Evidencia de autenticación LTE (S1AP/NAS).
- Autenticación IMS real (`ims_auth` + 401/200).
- V7 con BYE en el pcap.
- Integridad/manifiesto y reproducción limpia.
