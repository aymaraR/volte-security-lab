# Laboratorio de seguridad VoLTE sobre redes 4G/LTE

> Proposito academico: este repositorio documenta la investigacion, herramientas y configuracion de un laboratorio virtualizado para el estudio de vulnerabilidades en redes 4G LTE / VoLTE. Todo el trabajo se realiza en un entorno completamente aislado y controlado, sin afectar redes reales.

---

## Pregunta a resolver

De que manera un entorno de experimentacion por software permite identificar y mitigar vulnerabilidades en la senalizacion (SIP/IMS) y el transporte (RTP) de una red VoLTE, sin comprometer infraestructuras reales de un operador?

---

## Problema

Las redes VoLTE combinan varias capas criticas (radio LTE, core de red EPC, senalizacion SIP/IMS y transporte de voz RTP) y cada una tiene superficies de ataque conocidas (interceptacion, denegacion de servicio, suplantacion de identidad, cifrado debil) que son dificiles y riesgosas de validar directamente sobre una red comercial en produccion.

---

## Propuesta de solucion

Un laboratorio 100% software, sin costo de hardware, que emula la cadena VoLTE completa mediante componentes de codigo abierto (srsRAN en modo ZeroMQ, Open5GS, Kamailio, Asterisk, PyHSS) desplegados en contenedores Docker sobre una red aislada. Sobre ese entorno se ejecutan siete vectores de ataque documentados, cada uno con su procedimiento, metricas de exito y contramedida validada, siguiendo una metodologia reproducible de cuatro fases (reconocimiento, analisis de configuracion, explotacion, validacion de contramedida).

---

## Valor para la empresa

- Validacion previa a produccion: permite probar configuraciones y parches de seguridad antes de desplegarlos en la red comercial, reduciendo el riesgo de interrupciones.
- Evidencia reproducible y verificable: capturas con hash SHA-256, metricas cuantitativas y logs, utiles para auditorias internas o cumplimiento normativo (GSMA, proteccion de datos).
- Entrenamiento del equipo de ciberseguridad: cada vector de ataque viene con su contramedida exacta, sirviendo como runbook operativo.
- Reduccion de perdidas economicas: identificacion temprana de vulnerabilidades que podrian derivar en fraude tarifario, robo de identidad o sanciones regulatorias.
- Costo de infraestructura casi nulo: al no requerir SDR ni terminales fisicos, es replicable y escalable como practica recurrente del equipo, no solo como ejercicio puntual.

---

## Diferencias entre el laboratorio y una red real

| Aspecto | Laboratorio | Red real |
|---|---|---|
| Canal de radio | Loopback ZMQ, sin efectos de propagacion | RF fisica con fading, interferencia y movilidad |
| Escala | 1-2 UE emulados | Miles/millones de suscriptores concurrentes |
| Software | Open-source de referencia (srsRAN, Open5GS, Kamailio) | Core comercial certificado con hardening propietario |
| Interconexion | Red bridge aislada, sin exposicion externa | Roaming, senalizacion SS7/Diameter externa, integracion OSS/BSS |
| Terminales | UE emulado con credenciales en MongoDB | Smartphones comerciales con USIM certificada |
| Generacion | Solo 4G/LTE | Coexistencia con 5G y otras generaciones |

Estas diferencias son la razon por la que el desafio original propone, como evolucion, una arquitectura hibrida: sumar un nodo de acceso inalambrico real y terminales fisicos como paso intermedio entre el laboratorio y la red de produccion.

---

## Estructura del repositorio

```text
volte-security-lab/
├── README.md                       Estás aquí
├── Laboratorio_VoLTE_Tesis.docx    Propuesta de tesis (procedimientos detallados)
├── Imagenes/
├── docs/
│   ├── 01_investigacion/
│   │   ├── 01_redes_4G_LTE.md
│   │   ├── 02_VoLTE.md
│   │   └── 03_vectores_ataque.md
│   ├── 02_herramientas/
│   │   ├── 01_docker.md
│   │   ├── 02_srsRAN_4G.md
│   │   ├── 03_open5gs.md
│   │   ├── 04_kamailio.md
│   │   ├── 05_asterisk.md
│   │   ├── 06_kali_linux.md
│   │   └── 07_wireshark.md
│   └── 03_arquitectura/
│       ├── 01_diagrama_laboratorio.md
│       ├── 02_flujo_llamada_volte.md
│       └── 03_ataques_a_implementar.md
└── voLTE-lab/                      Implementación del laboratorio
    ├── docker-compose.yml          Red 172.20.0.0/24 y todos los servicios
    ├── lab-up.sh                   Levantado ordenado en 13 pasos (idempotente)
    ├── lab-down.sh                 Apagado ordenado (conserva volúmenes)
    ├── kali.md                     Runbook del contenedor atacante + estado V1-V7
    ├── srsran/                     Dockerfile + enb-config/ + ue-config/ + baresip-config/
    ├── open5gs/                    Dockerfile Open5GS v2.8.0
    ├── open5gs-config/             mme.yaml, mme.conf, nrf.yaml
    ├── open5gs-webui/              WebUI de suscriptores
    ├── kamailio/                   Dockerfile + pcscf/icscf/scscf (.cfg + diameter.xml)
    ├── asterisk/                   Dockerfile + pjsip.conf + extensions.conf
    ├── pyhss/                      HSS IMS (Diameter Cx) + docker/.env
    ├── attacks/                    Scripts de ataque v1-v7 (scapy, SIPp, tshark)
    ├── vectores/                   Wrappers interactivos v1_mitm.sh ... v7_bye.sh
    ├── captures/                   Capturas manuales (tshark/tcpdump)
    ├── results/                    Evidencia final (.pcapng/.csv/.wav + hashes.txt)
    └── reports/
```

---

## Objetivo del proyecto

Construir y operar un laboratorio de seguridad VoLTE 100% software, aislado y sin costo de hardware, como base para validar los siete vectores de ataque documentados en `docs/01_investigacion/03_vectores_ataque.md` y `docs/03_arquitectura/03_ataques_a_implementar.md`.

---

## Componentes del laboratorio

| Capa | Software | Version | Funcion | IP en volte-net |
|---|---|---|---|---|
| Base de suscriptores LTE | MongoDB | 4.4 | Credenciales SIM emuladas (IMSI/K/OPc) | 172.20.0.2 |
| Core EPC | Open5GS | 2.8.0 | MME, SGW-C/U, SMF, AMF, HSS, PCRF, UPF | 172.20.0.3 |
| Radio RAN celda 1 | srsRAN 4G ZMQ | 25.10.0 | eNB1 (PCI 1) + UE1 | .4 / .5 |
| Radio RAN celda 2 | srsRAN 4G ZMQ | 25.10.0 | eNB2 (PCI 2) + UE2 (configs en .lab-tmp/) | .14 / .8 |
| IMS CSCF | Kamailio | 5.8.8 | P-CSCF 4060 / I-CSCF 5060 / S-CSCF 6060 | 172.20.0.6 |
| HSS IMS | PyHSS | development | Diameter Cx 3868 + API 8080, Redis 7.0 | .10 / .11 / .12 / .9 |
| TAS / Media server | Asterisk | 21.12.2 | Echo 1000 + PJSIP contra S-CSCF | 172.20.0.7 |
| Atacante | Kali | kali-lab:latest | arpspoof, inviteflood, sipp, scapy, tshark | 172.20.0.99 |
| Analisis | Wireshark / tshark / tcpdump | - | Captura y decodificacion SIP/RTP | - |
| Orquestacion | Docker + Compose v2 | - | Red bridge aislada 172.20.0.0/24 | - |

Usuarios IMS de prueba: `1000` (echo Asterisk), `1001` (UE1, IMSI ...789), `1002` (UE2, IMSI ...790).

---

## Requisitos previos

1. Windows 10/11 de 64 bits, 16 GB de RAM, 50 GB libres, conexion a internet.
2. Docker Desktop con WSL2 (backend WSL2 activado) y Docker Compose v2:
   `docker info` y `docker compose version` deben responder sin error.
3. Terminal: Ubuntu 22.04 en WSL2, o Git Bash. Pararse siempre en `voLTE-lab/`.
4. `python3` disponible en el host (solo se usa para generar las configs de la celda 2 en `.lab-tmp/`).
5. Puertos libres en el host: `3000` (WebUI), `5060`, `5061`, `8080`, `10000-10100/udp`.

---

## Paso a paso para replicar el montaje

### Paso 0. Clonar y ubicarse

```bash
git clone https://github.com/aymaraR/volte-security-lab.git
cd volte-security-lab/voLTE-lab
```

Todos los comandos siguientes se ejecutan desde `voLTE-lab/`.

### Paso 1. Construir las imagenes (solo primera vez, 60-90 min)

Cada Dockerfile ya clona y compila su fuente, no hay que clonar nada a mano.
Construir en este orden:

```bash
docker build -t srsran-zmq:latest ./srsran
docker build -t open5gs-local:latest ./open5gs
docker build -t kamailio-ims:latest ./kamailio
docker build -t asterisk-ims:latest ./asterisk
docker build -t pyhss-local:latest -f ./pyhss/docker/Dockerfile ./pyhss
docker tag pyhss-local:latest ghcr.io/nickvsnetworking/pyhss/pyhss:development
```

Imagenes externas (se descargan solas, pero conviene pre-traerlas):

```bash
docker pull mongo:4.4
docker pull redis:7.0-alpine
docker pull nicolaka/netshoot
```

Verificacion rapida por imagen:

```bash
docker run --rm srsran-zmq:latest srsenb --version
# Debe mostrar Version 25.10.0 y libsrsran_rf_zmq.so

docker run --rm open5gs-local:latest open5gs-mmed --version
# Debe mostrar Open5GS daemon v2.8.0

docker run --rm kamailio-ims:latest kamailio -V
# Debe mostrar kamailio 5.8.8

docker run --rm asterisk-ims:latest asterisk -V
# Debe mostrar Asterisk 21.12.2
```

Nota: la WebUI (`open5gs-webui/`) no se construye a mano, la construye Compose al levantar.

### Paso 2. Levantar el laboratorio completo

```bash
./lab-up.sh
```

El script es idempotente y no modifica el repo (la celda 2 se genera en `.lab-tmp/`).
Hace, en orden, 13 pasos con espera por logs frescos (`docker logs --since`):

1. Chequea imagenes y etiqueta `pyhss-local` como upstream.
2. Levanta `mongodb + redis` y espera `PONG` / `ping ok`.
3. Inserta 2 suscriptores LTE en Mongo (`001010123456789`, `001010123456790`).
4. Levanta `open5gs`, reinicia el contenedor y espera `MME initialize...done`.
5. Levanta `pyhss_hss/api/diameter` (.10/.11/.12) y espera `Serving on` en 3868.
6. Provisiona IMS en PyHSS: `1000/1001/1002` con `default_ifc.xml`.
7. Arranca Kamailio: valida sintaxis `scscf/icscf/pcscf.cfg`, lanza los 3 CSCF, instala `iproute2+tcpdump`.
8. Arranca Asterisk y espera `pjsip show registrations: Registered` en S-CSCF.
9. Levanta eNB1 y espera `Number of eNBs is now 1` en Open5GS.
10. Genera configs de celda 2 con python3, levanta eNB2 y espera `Number of eNBs is now 2`.
11. Attach UE1 (hasta 3 intentos eNB+UE frescos) hasta `Attach complete` del IMSI ...789.
12. Attach UE2 igual para IMSI ...790.
13. Registra `baresip 1001+1002` por bridge (paso 12), luego levanta `ogstun`, suma rutas `10.45.0.0/24` en Kamailio/Asterisk, fija `sip_listen` a la IP real del `tun_srsue` y re-registra por el tunel GTP.

Duracion tipica: 10-20 min segun maquina. Si un paso falla, el mensaje indica el log a revisar
(`docker logs open5gs`, `/tmp/enb.log`, `/tmp/ue.log`, `/tmp/baresip.log`).

### Paso 3. Verificar que quedo operativo

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
docker logs open5gs --since 5m 2>&1 | grep -E "Attach complete|Number of eNBs"
docker exec asterisk asterisk -rx "pjsip show registrations" | grep -i registered
docker exec srsue sh -c "grep -a -q '200 OK' /tmp/baresip.log && echo 1001-OK"
docker exec srsue2 sh -c "grep -a -q '200 OK' /tmp/baresip2.log && echo 1002-OK"
docker exec srsue sh -c "ip -o addr show tun_srsue | grep inet"
docker exec srsue2 sh -c "ip -o addr show tun_srsue | grep inet"
```

Llamada de prueba 1001 -> 1000 (echo Asterisk):

```bash
docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/dial 1000@ims.mnc070.mcc999.3gppnetwork.org'"
# Hablar unos segundos y colgar:
docker exec srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/hangup'"
```

Llamada 1001 -> 1002 con el mismo comando cambiando el destino a
`1002@ims.mnc070.mcc999.3gppnetwork.org` (1002 tiene `answermode=auto`).

### Paso 4. Levantar el contenedor atacante (cuando se necesite)

`lab-up.sh` no levanta Kali a proposito. Tras cada `down` o reset:

```bash
docker compose up -d kali
docker exec -it kali bash
```

Ver runbook completo, inventario verificado y estado por vector en `voLTE-lab/kali.md`.
Scripts por vector: `voLTE-lab/vectores/v1_mitm.sh` ... `v7_bye.sh`.
Evidencia siempre en `voLTE-lab/results/` + hash en `results/hashes.txt`:

```bash
sha256sum <archivo> >> results/hashes.txt
# Formato: <sha256>  <archivo>  <vector>  <timestamp-UTC>  <descripcion>
```

### Paso 5. Apagado ordenado

```bash
./lab-down.sh
```

Orden: cuelga llamadas y mata baresip -> para RAN (UEs antes que eNBs) ->
para Kamailio -> detiene contenedores manuales (`srsue2/srsenb2/kamailio/asterisk/pyhss_*`) ->
`compose stop open5gs/enb/ue/mongodb/redis`. No borra volumenes ni imagenes.
Limpieza total (borra DBs, solo si se quiere partir de cero):
`docker compose down -v`.

---

## Solucion de problemas frecuentes

- `docker daemon no responde`: prender Docker Desktop y reintentar.
- Git Bash mutila `-v SRC:DST` y `--add-host H:IP`: el script ya exporta
  `MSYS_NO_PATHCONV=1`, no lo quitar.
- Falsos OK por logs viejos: el script usa `docker logs --since`, no reemplazar por `grep` simple.
- Sockets ZMQ colgados: reiniciar el contenedor (`docker restart srsenb/srsue`), no solo
  `pkill srsenb/srsue` dentro. El attach ya reintenta 3 veces con par fresco eNB+UE.
- No tocar `rrc_inactivity_timer` (dejar default 30s): valores enormes rompen la RF de srsENB.
- `ogstun` nace DOWN en cada arranque: sin `ip link set ogstun up` + `10.45.0.1/16` no hay breakout UPF.
- `baresip` bindea la IP del `tun_srsue` y esta cambia en cada attach: hay que reescribir
  `sip_listen <tun-ip>:5060` (paso 13 de `lab-up.sh`) o queda `Network is unreachable`.
- Trafico en IDLE dispara `Service Request` rechazado (causa 9) y espiral detach/re-attach
  con IP nueva cada 60-90s: no hacer ping por el tun, el keepalive del lab solo repone rutas.
- Registro SIP por bridge funciona siempre (paso 12), por tunel solo en ventana CONNECTED
  post-attach (paso 13). V1/V2/V3/V7 no necesitan el tunel.
- `inviteflood` solo hace INVITE: `inviteflood eth0 USER DOMINIO IP COUNT -D PUERTO`.
- `sipp` sin TTY exige `TERM=xterm ... -bg` y sale con rc=99 aunque funcione: esperar por `-m`.
- `sipsak` contra S-CSCF sale mudo: usar `attacks/v2_dos_ims/sip_probe.py`.
- `tshark -f` es BPF: `or rtp` es invalido, usar `-f "udp"`.
- Kali no tiene `pgrep/pkill/ps` ni `audioop` (python 3.13): usar `kallikill()` y
  `attacks/v1_mitm_sip/rtp_to_wav.py` (stdlib puro).

---

## Fases del proyecto

- [x] Fase 0: Definicion del alcance y objetivos
- [x] Fase 1: Investigacion teorica (redes 4G LTE y VoLTE)
- [x] Fase 2: Documentacion de herramientas
- [x] Fase 3: Diseno de arquitectura del laboratorio
- [x] Fase 4: Implementacion y configuracion (lab levanta end-to-end con `lab-up.sh`)
- [x] Fase 5: Ejecucion de pruebas (V1 MITM y V2 DoS completados 2026-10-02, V3 suplantacion confirmada, V7 BYE forjado confirmado 2026-10-02, V5 rogue ejecutado sin exito de atraccion en ventana; V4/V6 bloqueados por plano GTP; contramedidas pendientes - ver `voLTE-lab/kali.md` y `voLTE-lab/results/`)

---

## Advertencia legal y etica

Este proyecto es exclusivamente educativo. El uso de estas tecnicas sobre redes reales sin autorizacion explicita es ilegal y puede derivar en sanciones penales. Todo el laboratorio opera en redes virtuales aisladas, sin espectro radioelectrico real ni conexion a infraestructura de operadores.

---

## Como navegar la documentacion

1. Empieza por `docs/01_investigacion/01_redes_4G_LTE.md` para la base teorica LTE.
2. Sigue con `docs/01_investigacion/02_VoLTE.md` y `docs/01_investigacion/03_vectores_ataque.md`.
3. Revisa las herramientas en `docs/02_herramientas/` (Docker, srsRAN, Open5GS, Kamailio, Asterisk, Kali, Wireshark).
4. Revisa la arquitectura en `docs/03_arquitectura/` (diagrama, flujo de llamada, ataques a implementar).
5. Monta el lab con `voLTE-lab/lab-up.sh` (esta guia) y opera los ataques desde `voLTE-lab/kali.md` + `voLTE-lab/vectores/`.
