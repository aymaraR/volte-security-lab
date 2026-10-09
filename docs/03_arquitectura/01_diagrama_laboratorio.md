# Arquitectura del Laboratorio

## 1. Vista general

Nuestra solución se encuentra en un laboratorio que virtualiza una red 4G LTE completa con soporte VoLTE usando exclusivamente software de código abierto sobre Docker. Ningún componente emite señal de radio real — la interfaz de radio entre srsUE y srsENB se simula mediante **ZeroMQ** (mensajes sobre TCP).

En este documento se encuentra la topología completa del laboratorio: qué contenedores existen, cómo se interconectan, qué direccionamiento IP usan y qué interfaz de red real (loopback, ZMQ, bridge Docker) transporta cada tramo de la cadena VoLTE. El levantado está automatizado en `voLTE-lab/lab-up.sh` (13 pasos idempotentes).

---

## 2. Diagrama de Topología (vigente, red única 172.20.0.0/24)

```text
HOST (Windows + Docker Desktop + WSL2 Ubuntu 22.04)
|
|  RED volte-net  172.20.0.0/24 (bridge Docker, aislada)
|
|  EPC + RAN                          IMS + Media              Soporte
|  mongodb .2  (suscriptores LTE)     kamailio .6              redis .9 (colas PyHSS)
|  open5gs .3  (MME/SGW/PGW/HSS/      (P:4060 / I:5060 /        pyhss .10/.11/.12
|   PCRF/UPF + ogstun 10.45.0.1)       S:6060)                  (HSS/API/Diameter Cx 3868)
|  srsenb .4 + srsue .5               asterisk .7              webui .13 (puerto 3000)
|   (celda 1, PCI 1, UE1/1001)        (TAS + echo 1000)
|  srsenb2 .14 + srsue2 .8            kali .99 (ATACANTE)
|   (celda 2, PCI 2, UE2/1002)        sniffer (netshoot, host)
|
|  Radio: ZMQ TCP .4:2000 <-> .5:2001 (celda 1), .14:2002 <-> .8:2003 (celda 2)
|  Datos UE: tun_srsue 10.45.0.0/16 via UPF/ogstun (ver limitaciones §8)
|  SIP: UE -> P-CSCF .6:4060 -> I:5060 -> S:6060 -> Asterisk .7:5061
```

---

## 3. Requisitos del Sistema Host

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU | 4 núcleos | 8 núcleos |
| RAM | 8 GB | 16 GB |
| Disco | 20 GB | 50 GB |
| SO | Windows 10/11 + WSL2 Ubuntu 22.04 | Ubuntu 22.04 LTS |
| Docker | Desktop con backend WSL2 | 25.x |
| Docker Compose | v2.x | v2.x |

La compilación completa desde cero toma 60-90 minutos (srsRAN, Open5GS, Kamailio y Asterisk se compilan desde fuente).

---

## 4. Segmentos de Red

| Segmento | Rango / dirección | Tecnología | Tráfico que transporta |
|---|---|---|---|
| Interfaz radio emulada celda 1 | `172.20.0.4:2000` / `172.20.0.5:2001` | Sockets TCP (ZeroMQ) | Muestras I/Q entre srsUE1 y srsENB1 (equivalente lógico de LTE-Uu) |
| Interfaz radio emulada celda 2 | `172.20.0.14:2002` / `172.20.0.8:2003` | Sockets TCP (ZeroMQ) | Muestras I/Q entre srsUE2 y srsENB2 |
| Túnel de datos del UE | `10.45.0.0/16` | Interfaz virtual `tun_srsue` | Tráfico IP de usuario asignado por el PGW/UPF |
| Red bridge del laboratorio | `172.20.0.0/24` | Docker bridge `volte-net` | S1-MME, S1-U, SIP (Gm), Diameter Cx, RTP |
| Túnel GTP-U | Interfaz `ogstun` en open5gs (`10.45.0.1/16`) | GTP-U | Plano de usuario entre eNodeB y UPF (incluye RTP) |

Limitación conocida (2026-10-02): el túnel UE-UPF no transporta datos de forma estable (el MME rechaza Service Request en IDLE y el UE re-hace attach con IP nueva). El registro SIP por bridge funciona siempre; V1/V2/V3/V7 no necesitan el túnel. Detalle en `voLTE-lab/kali.md` (Plano GTP).

---

## 5. Direccionamiento Fijo de Contenedores

Cada contenedor recibe una IP estática dentro de `172.20.0.0/24` (ver `voLTE-lab/docker-compose.yml`):

| Contenedor | IP | Capa | Software |
|---|---|---|---|
| mongodb | 172.20.0.2 | EPC / datos | MongoDB 4.4 (IMSI/K/OPc) |
| open5gs | 172.20.0.3 | EPC | Open5GS 2.8.0 (MME, SGW-C/U, SMF, AMF, HSS, PCRF, UPF) |
| srsenb (eNB1) | 172.20.0.4 | RAN celda 1 | srsRAN 4G 25.10.0, PCI 1, cell 0x01 |
| srsue (UE1) | 172.20.0.5 | RAN celda 1 | IMSI ...789, línea 1001 |
| kamailio | 172.20.0.6 | IMS | Kamailio 5.8.8 (P:4060 / I:5060 / S:6060) |
| asterisk | 172.20.0.7 | IMS / Media | Asterisk 21.12.x (echo 1000, PJSIP :5061) |
| srsue2 (UE2) | 172.20.0.8 | RAN celda 2 | IMSI ...790, línea 1002 (auto-answer) |
| redis | 172.20.0.9 | Soporte | Redis 7.0 (colas PyHSS) |
| pyhss_hss / api / diameter | 172.20.0.10 / .11 / .12 | IMS / HSS | PyHSS (Cx 3868, API 8080) |
| webui | 172.20.0.13 | Gestión | Open5GS WebUI (host :3000) |
| srsenb2 (eNB2) | 172.20.0.14 | RAN celda 2 | Celda legítima PCI 2 (configs en `.lab-tmp/`, NO es ataque) |
| kali | 172.20.0.99 | Atacante | Kali (arpspoof, inviteflood, sipp, scapy, tshark) |
| sniffer | host network | Análisis | netshoot (capturas) |

Usuarios IMS: `1000` (echo Asterisk), `1001` (UE1), `1002` (UE2).

---

## 6. Puntos de Posicionamiento del Atacante

Cada vector asume una posición de red específica para `kali` (.99), coherente con que el laboratorio nunca expone tráfico fuera de la red bridge aislada:

| Vector | Posición del atacante | Técnica de posicionamiento | Estado 2026-10-02 |
|---|---|---|---|
| V1 — MITM SIP | Entre srsUE y P-CSCF / Asterisk | ARP spoofing doble par (.5<->.6 señalización, .5<->.7 media) | Vulnerable |
| V2 — DoS IMS | Con alcance al S-CSCF .6:6060 | Envío directo (inviteflood, SIPp, scapy) | Degradación real en REGISTER |
| V3 — Suplantación | Con alcance al P-CSCF .6:4060 | INVITE forjado (scapy) | Vulnerable |
| V4 — Cifrado radio | Lectura de `ogstun` / logs srsENB | Captura pasiva | Bloqueado (sin plano GTP) |
| V5 — Rogue eNodeB | Takeover ZMQ de IP/puertos del eNB1 con PCI 7/cell 0x09 | Competencia de reselección | Ejecutado, no atraído en ventana |
| V6 — GTP-U Injection | Con visibilidad del túnel `ogstun` y TEID | Inyección GTP-U forjada | Bloqueado (sin plano GTP) |
| V7 — SIP BYE forjado | Con alcance al P-CSCF .6:4060 | BYE con RURI del contacto remoto + Route P-CSCF | Vulnerable |

Detalle de ejecución y evidencias en `voLTE-lab/kali.md` y `voLTE-lab/results/` (+ `hashes.txt`).

---

## 7. Correspondencia con Docker Compose y lab-up.sh

La topología se declara en `voLTE-lab/docker-compose.yml` (red `volte-net`, IPs fijas, volúmenes de config). El orden de arranque lo impone `voLTE-lab/lab-up.sh`: `mongo+redis -> suscriptores -> open5gs -> pyhss -> provision IMS -> kamailio -> asterisk (espera Registered) -> eNB1 -> eNB2 -> UE1/UE2 (hasta 3 intentos, par fresco eNB+UE) -> baresip 1001/1002 -> plano GTP`. Notas operativas críticas (no quitar): `docker logs --since` para healthchecks, restart por contenedor en RAN (sockets ZMQ se cuelgan con solo-proceso), `ogstun` nace DOWN, `sip_listen` debe fijarse a la IP vigente del `tun_srsue`, sin ping por el túnel en IDLE.

---

## 8. Diferencias Explícitas con una Red Real

- **Sin RF física:** la "radio" son sockets TCP ZMQ, sin fading, interferencia ni movilidad real; la sincronización RF es flaky (~50% al primer intento, `lab-up.sh` reintenta).
- **Escala reducida:** 2 UE emulados frente a miles/millones de suscriptores.
- **Sin interconexión externa:** no hay roaming ni señalización SS7/Diameter hacia otras redes.
- **Terminales sin USIM certificada:** credenciales en MongoDB/PyHSS, no en hardware inviolable.
- **Plano de usuario inestable:** ver limitación GTP en §4; el registro SIP vía túnel falla sistemáticamente y se opera por bridge.

---

## 9. Recursos

- srsRAN 4G Project — https://github.com/srsran/srsRAN_4G
- srsRAN con ZeroMQ: https://docs.srsran.com/projects/4g/en/latest/app_notes/source/zeromq/source/index.html
- Open5GS — https://github.com/open5gs/open5gs
- PyHSS — https://github.com/nickvsnetworking/pyhss
- Diagrama de referencia 3GPP TS 23.002
- Docker Compose networking — https://docs.docker.com/compose/networking/

---

**Siguiente documento:** [`02_flujo_llamada_volte.md`](02_flujo_llamada_volte.md) — Ciclo de vida de una llamada VoLTE.
