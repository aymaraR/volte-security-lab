# kali.md — Runbook del contenedor atacante (Kali)

Contenedor: `kali` (`172.20.0.99`, red `volte-net`).
Entrar: `docker exec -it kali bash` (desde PowerShell/WSL con el lab UP).

> OJO OPERATIVA: `lab-up.sh` NO levanta kali y `docker compose down` lo
> ELIMINA. Tras un reset: `docker compose up -d kali` (en `voLTE-lab/`).

Scripts interactivos por vector (preguntan parámetros, muestran el
recomendado probado entre []): `vectores/v1_mitm.sh` … `vectores/v7_bye.sh`.

> NOTA DE RED: el bridge Docker es un switch, NO un hub. El modo promiscuo
> NO ve tráfico unicast ajeno: para MITM hay que hacer ARP spoofing (V1).
> Para capturas propias (baseline) basta `tshark`/`tcpdump` en el origen.

## 0. Inventario verificado (Fase B + sesión 2026-10-02)

| Herramienta | Versión | Uso / notas 2026-10-02 |
|---|---|---|
| arpspoof (dsniff) | dsniff 2.5 | V1 MITM (2 pares: señalización + media) |
| inviteflood | 2.0 | V2 INVITE flood. SOLO INVITE (no tiene modo REGISTER). Sintaxis: `inviteflood eth0 USER DOMINIO IP COUNT -D PUERTO`. Origen puerto 9/discard -> decodificar con `-d udp.port==9,sip`. Tasa ~540 pps |
| sipp | 3.3 | V2 REGISTER flood (`attacks/v2_dos_ims/register_flood.xml`). Sin TTY **exige** `TERM=xterm ... -bg`; el padre sale con rc=99 aunque funcione: esperar fin por `-m`, no por rc |
| python3-scapy | 2.7.01 | V3 spoof, V6 inyección |
| sipsak | 0.9.8.1 | **NO USAR contra S-CSCF**: no responde OPTIONS y sipsak sale mudo (rc=0, sin salida). Reemplazo: `attacks/v2_dos_ims/sip_probe.py` (REGISTER + `rport`, mide RTT real y status) |
| tshark | 4.6.6 | Capturas y análisis (`-z rtp,streams`). OJO: `-f` es BPF — `or rtp` es INVÁLIDO (mata la captura en silencio); usar `-f "udp"` |
| sipvicious (svmap/svwar) | 0.3.3 | Recon SIP (V2/V7) |
| tcpdump | 4.99.6 | Capturas rápidas |
| rtpbreak | — | NO disponible. Reemplazo: `attacks/v1_mitm_sip/rtp_to_wav.py` (stdlib puro, validado bit-idéntico a `audioop` en 256/256 valores μ-law + A-law) |

Limitaciones del contenedor kali (verificadas 2026-10-02, NO asumir):
`pgrep`/`pkill`/`ps` NO existen (solo `pidof` + `kill` builtin) — los
scripts usan `kallikill()` (barrido `/proc/cmdline`). El `python3` es ≥3.13:
**sin `audioop`** (eliminado) — los helpers deben ser stdlib puro.

Topología (IPs fijas):
`mongodb .2 | open5gs .3 | srsenb .4 | srsue .5 | kamailio .6 (P:4060/I:5060/S:6060)`
`asterisk .7 | redis .9 | pyhss .10/.11/.12 | srsenb2 .14 | srsue2 .8 | kali .99`
Usuarios IMS: `1000` (Asterisk TAS/echo) / `1001` (UE1) / `1002` (UE2).

## Metodología por vector (tesis §4, 4 fases)

1. Reconocimiento pasivo (captura baseline, puertos/protocolos).
2. Análisis de configuración (parámetros inseguros).
3. Explotación activa (ataque + evidencia + logs).
4. Validación de contramedida (mitigación + re-ejecución).
Toda evidencia `.pcapng/.csv/.wav` va a `results/` con SHA-256 en `results/hashes.txt`:
formato `<sha256>  <archivo>  <vector>  <timestamp-UTC>  <descripción>`.

## Baseline (Fase B) — comandos ejecutados

```bash
# En srsue: registrar y llamar al echo 1000
docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip > /tmp/baresip.log 2>&1"
docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/dial 1000@ims.mnc070.mcc999.3gppnetwork.org'"
# En srsue: capturar RTP propio (el bridge no hace flood a kali)
docker exec -d srsue sh -c "timeout 20 tcpdump -i eth0 -w /tmp/base-rtp.pcapng udp"
docker cp srsue:/tmp/base-rtp.pcapng results/baseline_rtp_1001-1000.pcapng
# En kali: analizar (decode-as porque sin SIP no hay heurística RTP)
docker cp results/baseline_rtp_1001-1000.pcapng kali:/tmp/base.pcapng
docker exec kali tshark -r /tmp/base.pcapng -d udp.port==2820,rtp -d udp.port==12904,rtp -q -z rtp,streams
# Resultado: 2 streams g711U, 897 pkt c/u, 0% loss, delta 20ms.
# Hash:
docker exec kali sha256sum /root/results/baseline_rtp_1001-1000.pcapng
# -> 0aab32cc7800ad74cba488c257ed7289cfd695d720e3d78920338c4b070ac4c2
```

## V1 — Intercepción SIP/SDP+RTP (CVSS 9.1, T1557) — COMPLETADO 2026-10-02

`vectores/v1_mitm.sh` (DUR=70) + llamada 1001→1000 durante la ventana.
Hallazgo clave: envenenar solo UE↔P-CSCF captura señalización pero el RTP
va directo UE↔Asterisk — el script envenena **2 pares** (señalización .5↔.6
+ media .5↔.7) y captura todo UDP.
Resultado: 2 INVITE + 4 SDP en claro (`c=172.20.0.5`, `c=172.20.0.7`),
**14024 RTP (g711U, ambos sentidos)**, wav 140.2s reconstruido.
Veredicto: **VULNERABLE** (SDP en claro, sin TLS).
Evidencia: `results/v1_mitm_sip_20261002T043055Z.pcapng` +
`results/v1_audio_20261002T043055Z.wav` (+ hashes `V1`/`V1-audio`).
Pendiente fase 4: TLS obligatorio en P-CSCF (`tls.so` ya compilado en la
imagen) → re-ejecutar → se espera 0 INVITE en claro.

## V2 — DoS sobre IMS (CVSS 8.6, T1498) — COMPLETADO 2026-10-02 (3 modos)

Sonda legítima: `sip_probe.py` (REGISTER+rport) — baseline real ~65-155ms/200.
Muestreador cada 2s → `results/v2_<modo>_<TS>.csv` (`ts,rtt_ms,status`,
cubre flood + 32s de recuperación/MTTR). Todo con hash (pcap + csv).

| Modo | Comando | Resultado 2026-10-02 |
|---|---|---|
| invite 3000 / 10000 | `inviteflood` (~540 pps) | Absorbido: avg ~100-118ms, max 251ms, 0 timeouts (el S-CSCF finaliza 478 rápido) |
| register 3000 | SIPp + `register_flood.xml` (3017 REGISTER en pcap) o `reg_flood.py` (~165/s) | **Degradado real**: avg 757-902ms (6-9×), max ~6s, 1 timeout; recupera a ~65ms. Camino caro Diameter SAR |
| txn dominio 3000/10000 | `txn_exhaust.py` (91-341/s) | Absorbido: avg 61-90ms (todo finaliza 478: 3000 INVITE→3000×100+3000×478) |
| txn blackhole 3000 | `TXN_RURI_HOST=172.20.0.99` | Primitiva OK: 1500 INVITE → solo `100 Trying`, **0 finales** (transacción colgada hasta fr_timer); a esta escala sin impacto (avg 133ms) |

Evidencia: `results/v2_{invite,register,txn}_*` (6 pcaps + 6 csv + 12 hashes).
Incidente: un register-3000 saturó el peer Diameter Cx (SAR sin SAA,
`peer ... Closing` en icscf) — se recupera con `docker restart
pyhss_diameter` + relanzar los 3 CSCF (hay script de recuperación en notas).
Pendiente fase 4: `pike` (`pike.so` SÍ está en la imagen, falta cargarlo:
`sampling_time_unit 2` + `reqs_density_per_unit 30` + `pike_check_req()`)
→ re-ejecutar → se espera bloqueo del atacante y RTT normal.

Hallazgos previos 2026-10-01 (referencia, S-CSCF 6060):
- Flood a IMPU registrado: 3000 INVITE → 964x478 + 241x100 (~40%).
- Evidencia legacy: `results/v2_flood2.pcapng`, `v2_victim_3000invite.pcapng`.

## V3 — Suplantación (CVSS 7.4, T1534) — VULNERABLE CONFIRMADO 2026-10-01

Script: `attacks/v3_identity_spoof/v3_spoof.py` (socket UDP dir. a P-CSCF 4060,
parametrizado por entorno: `VICTIM/TARGET/PCSCF/PORT/DOMAIN/SRC_IP`).
Resultado: INVITE `From: 1001 / To: 1002` enrutado P→I→S-CSCF y **contestado
por 1002** (`answering call ... from sip:1001@... with 200`, auto-answer).
Sin 403 en ningún punto: no hay verificación P-Asserted-Identity.
Evidencia: `results/v3_spoof_1001-to-1002.pcapng` (+ hash). Nota: directo al
S-CSCF (6060) falla con 478/DNS (requiere el path vía P-CSCF).
Pendiente fase 4: habilitar PAI check -> re-ejecutar -> 403 esperado.

## V4 — Cifrado radio (CVSS 7.5, T1040) — BLOQUEADO (track GTP, causa raíz ↓)

`vectores/v4_cipher.sh` modos `check/capture/compare` listos, pero sin
tráfico de usuario por GTP no hay qué capturar en `ogstun`.
Ver causa raíz en "Plano GTP" abajo.

## V5 — Rogue eNodeB — EJECUTADO 2026-10-02 (2 corridas, veredicto: NO ATRAIDO en ventana)

`vectores/v5_rogue.sh` (defaults `yes/7/0x09`) + reintento mejorado
(`.lab-tmp/run-v5retry.sh`: restart por contenedor, 2 intentos UE, ventana 90s c/u).
Rogue levanta (RF `ZMQ tx *:2000/rx .5:2001`, `PCI 7/cell 0x09`) pero el MME
no registra ningun `S1AP/Attach` de `001010123456789` en la ventana y el UE
no completa `attach` al rogue (verificado en `docker logs open5gs` + `/tmp/ue.log`).
Al restaurar el legitimo, el MME vuelve a ver `CellID[0x19b01]` + `Attach complete`.
Veredicto honesto: **NO ATRAIDO en ventana de observacion** (no confundir con
mitigado: falta probar reselection forzada / SIB prioritaria). UE1 quedo con
attach RAN intermitente tras el experimento (sync RF ZMQ flaky ~50%); UE2,
EPC, IMS y SIP por bridge siguen OK.
Evidencia: `results/v5_rogue_20261002T133213Z.log` +
`results/v5_rogue_reintento_20261002T134747Z.log` (+ 2 hashes `V5`).
Leccion: para RAN usar siempre `docker restart` por contenedor, no `pkill`
(lo documentado en `lab-up.sh`: sockets ZMQ se cuelgan con solo-proceso).
Pendiente fase 4: lista de celdas autorizadas / deteccion de PCI inesperado.

## V6 — GTP-U Injection — BLOQUEADO (track GTP, causa raíz ↓)

`vectores/v6_gtp.sh` con auto-descubrimiento de TEID; sin plano GTP no hay
TEID válido (sale código 2 = bloqueado explícito).

## V7 — SIP BYE forjado — VULNERABLE CONFIRMADO 2026-10-02

`vectores/v7_bye.sh` modo `auto` NO sirve tal cual: kamailio no trae `tshark`
(solo `tcpdump`) y la auto-extraccion sale vacia. Procedimiento que funciona:
colgar restos, capturar 30-60s en kamailio (`tcpdump -i any udp port
4060/6060/5060/5061`), discar `1001->1000` dentro de la ventana, extraer el
dialogo en kali (`tshark`: `Call-ID`, `From-tag` del INVITE, `To-tag` del
`200 OK`, `CSeq+1`), enviar BYE por UDP a `P-CSCF .6:4060`.
Hallazgo clave: el RURI del BYE debe ser el contacto remoto
(`sip:172.20.0.7:5061`) con `Route: <sip:172.20.0.6:4060;lr>`; con
`BYE sip:1000@<dominio>` el P-CSCF no lo enruta (canales `1->1`).
Resultado final: BYE `CSeq 50151` -> `200 OK` al BYE en pcap, canales PJSIP
en Asterisk `1->0` (`core show channels`: `0 active calls`).
Veredicto: **VULNERABLE** (BYE sin auth de dialogo termina la llamada).
Evidencia: `results/v7_bye_1001-to-1000_20261002T134234Z.pcapng` (intento 1,
dialogo `e8d5516a4492fc10`, BYE con RURI incorrecto, `1->1`) +
`results/v7_bye_1001-to-1000_20261002T134517Z.pcapng` (final, dialogo
`21a038c99068157d`, `BYE 50151` + `200 OK`, `1->0`, 522885 bytes) (+ hashes `V7`).
Pendiente fase 4: verificar tags From/To del dialogo + auth -> 403/481 esperado.

## Plano GTP — causa raíz del bloqueo V4/V6 (diagnóstico 2026-10-02)

El túnel UE↔UPF **nunca transportó datos** en este lab: con tráfico en IDLE
el MME rechaza el Service Request y el UE entra en espiral
detach→re-attach con **IP nueva cada ~60-90s** (visto .2→.4→.6→.8);
barespip queda bindeado a la IP vieja → `Network is unreachable` permanente.
En quietud total (sin baresip/pings) la sesión es estable >180s.
Evidencia: `Removed Session` + `Attach complete` cíclicos en `docker logs
open5gs`, `Attach Reject Cause=6F` y `Service Request mo-Data → RRC Release`
en `/tmp/ue.log` de srsue. El registro SIP vía túnel (paso 13 de lab-up.sh)
falla sistemáticamente; el registro vía bridge (paso 12) funciona siempre.
V1/V2/V3/V7 no necesitan el túnel. Desbloquear V4/V6 requiere fijar el
Service Request (interlab srsUE↔MME) o aceptar ventana CONNECTED post-attach.

## Fase 4 — Contramedidas aplicadas y validadas (2026-10-23)

Ciclo completo (ataque -> evidencia -> parche -> re-prueba) ejecutado sobre
el lab UP. Parches reproducibles en `parches/aplicar.sh` (y `revertir.sh` para
volver al estado vulnerable). Detalle de archivos modificados en `parches/`.

| Vector | Veredicto vulnerable (baseline) | Contramedida | Veredicto mitigado | Evidencia (results/) |
|---|---|---|---|---|
| V1 | VULNERABLE: 2 INVITE + 4 SDP en claro, 9980 RTP g711U, audio 99.8s reconstruido | TLS en Gm (P-CSCF:5061, `tls.cfg`) + SRTP/SDES en media | MITIGADO: 0 INVITE/SDP en claro, media SRTP no reconstruible (`v1_mitm_sip_*T014104Z.pcapng`) | `v1_audio_*T011807Z.wav` + 2 pcap |
| V2 | DEGRADADO: REGISTER flood avg 702ms max 6007ms 1 timeout (sonda en kali) | `pike` en S-CSCF (`reqs_density_per_unit 30/2s`) | MITIGADO: atacante .99 -> 2963x403; sonda neutral pyhss_hss avg 99ms max 202ms 0 timeout | `v2_register_3000_*T014252Z.{pcapng,csv}` |
| V3 | VULNERABLE: INVITE forjado 1001->1002 contestado, 0x403 | binding IMPU<->IP origen en P-CSCF (htable, solo 2xx REGISTER) | MITIGADO: 3 INVITE -> 3x403 "Identity Origin Mismatch", 1002 no contesta | `v3_spoof_1001-to-1002_*T015102Z.pcapng` |
| V7 | VULNERABLE: BYE forjado -> llamada 1->0 | mismo binding + TLS (tags no observables) | MITIGADO: BYE rechazado 403, llamada sigue 1->1 | `v7_bye_1001-to-1000_*T014557Z.pcapng` |

Notas de implementación (Fase 4):
- Kamailio 5.8+ exige `enable_tls=1` y `tls.cfg` (`[server:default] method=TLSv1.2+`);
  el `modparam("tls","method",...)` fue removido (parse error) — ver `parches/tls.cfg`.
- baresip UE: `;transport=tls` + `outbound=...:5061;transport=tls` + `;mediaenc=srtp-mand`
  + `sip_cafile=/root/.baresip/tls.crt` + `module srtp.so`. Cert autofirmado con
  SAN `IP:172.20.0.6` y `basicConstraints=CA:TRUE`.
- Asterisk: `ue-endpoint` y `scscf` con `media_encryption=sdes`.
- V2: la sonda legítima debe originarse desde un host distinto del atacante
  (`PROBE_CONT=pyhss_hss`) o pike la bloquea también (mismo origen).
- `lab-up.sh`/`docker-compose.yml` ya montan `kamailio/tls/` y `parches/tls.cfg`;
  `lab-up.sh` genera el cert si falta.
