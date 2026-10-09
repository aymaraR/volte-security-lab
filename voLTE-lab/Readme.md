# Laboratorio VoLTE con Docker

Laboratorio de tecnologia VoLTE (Voice over LTE) completamente simulado, sin necesidad de hardware SDR. Todo corre en contenedores Docker sobre Windows con WSL2. El levantado y apagado estan automatizados con `lab-up.sh` / `lab-down.sh`.

## Arquitectura real (red `volte-net` 172.20.0.0/24)

```text
172.20.0.0/24 (bridge volte-net)
├── 172.20.0.2  →  MongoDB        (suscriptores LTE)
├── 172.20.0.3  →  Open5GS        (EPC: MME, SGW, PGW, HSS, PCRF, UPF)
├── 172.20.0.4  →  srsRAN eNB1    (celda legitima PCI 1)
├── 172.20.0.5  →  srsRAN UE1     (IMSI ...789, linea 1001)
├── 172.20.0.14 →  srsRAN eNB2    (celda legitima PCI 2, configs en .lab-tmp/)
├── 172.20.0.8  →  srsRAN UE2     (IMSI ...790, linea 1002)
├── 172.20.0.6  →  Kamailio       (IMS: P-CSCF 4060 / I-CSCF 5060 / S-CSCF 6060)
├── 172.20.0.7  →  Asterisk       (TAS + echo 1000, PJSIP contra S-CSCF)
├── 172.20.0.9  →  Redis          (colas PyHSS)
├── 172.20.0.10/.11/.12 → PyHSS   (HSS IMS Diameter Cx 3868 + API 8080)
├── 172.20.0.13 →  WebUI          (gestion de suscriptores Open5GS, puerto 3000)
└── 172.20.0.99 →  Kali           (atacante, se levanta aparte)
```

Usuarios IMS: `1000` (echo Asterisk), `1001` (UE1), `1002` (UE2, auto-answer).

## Stack tecnologico

| Componente | Tecnologia | Version |
|---|---|---|
| Radio simulada | srsRAN 4G + ZMQ | 25.10.0 |
| EPC (nucleo 4G) | Open5GS | 2.8.0 |
| HSS IMS | PyHSS | development |
| IMS Core | Kamailio | 5.8.8 |
| Media Server | Asterisk | 21.12.2 |
| Base de datos LTE | MongoDB | 4.4 |
| Colas HSS | Redis | 7.0-alpine |
| Infraestructura | Docker + Compose v2 + WSL2 | - |

## Requisitos minimos

- Windows 10/11 de 64 bits, 16 GB de RAM, 50 GB libres.
- Docker Desktop con backend WSL2 y Compose v2.
- Terminal Ubuntu 22.04 en WSL2 (o Git Bash), parado en `voLTE-lab/`.
- `python3` en el host (genera configs de la celda 2 en `.lab-tmp/`).

## Montaje paso a paso

### 1. Construir imagenes (solo primera vez, 60-90 min)

```bash
docker build -t srsran-zmq:latest ./srsran
docker build -t open5gs-local:latest ./open5gs
docker build -t kamailio-ims:latest ./kamailio
docker build -t asterisk-ims:latest ./asterisk
docker build -t pyhss-local:latest -f ./pyhss/docker/Dockerfile ./pyhss
docker tag pyhss-local:latest ghcr.io/nickvsnetworking/pyhss/pyhss:development
docker pull mongo:4.4
docker pull redis:7.0-alpine
```

Verificacion: `srsenb --version` (ZMQ activo), `open5gs-mmed --version` (v2.8.0),
`kamailio -V` (5.8.8), `asterisk -V`. Detalle por componente en su `README.md`.

### 2. Levantar todo

```bash
./lab-up.sh
```

13 pasos idempotentes: base mongo+redis, suscriptores LTE, EPC, PyHSS,
provision IMS 1000/1001/1002, Kamailio 3 CSCF, Asterisk (espera `Registered`),
eNB1, eNB2, attach UE1/UE2 (hasta 3 intentos), registro SIP 1001+1002 por
bridge y conmutacion al tunel GTP. Verificacion:

```bash
docker exec srsue grep -a -c 200 /tmp/baresip.log
docker exec asterisk asterisk -rx "pjsip show registrations"
```

Llamada de prueba: `docker exec -d srsue sh -c "export HOME=/root; baresip -f /root/.baresip -e '/dial 1000@ims.mnc070.mcc999.3gppnetwork.org'"`.

### 3. Contenedor atacante

`lab-up.sh` no levanta Kali a proposito:

```bash
docker compose up -d kali
docker exec -it kali bash
```

Runbook completo en `kali.md`. Vectores interactivos en `vectores/v1_mitm.sh`
a `v7_bye.sh`. Evidencia en `results/` con SHA-256 en `results/hashes.txt`.

### 4. Apagar

```bash
./lab-down.sh
```

Apagado ordenado sin borrar volumenes. Limpieza total opcional:
`docker compose down -v` (borra DBs).

## Estado de vectores (2026-10-02)

| Vector | Estado | Evidencia |
|---|---|---|
| V1 MITM SIP/RTP | Vulnerable confirmado | `results/v1_mitm_sip_*.pcapng`, `v1_audio_*.wav` |
| V2 DoS IMS | Degradacion real en REGISTER flood | `results/v2_*` (6 pcap + 6 csv) |
| V3 suplantacion | Vulnerable confirmado | `results/v3_spoof_1001-to-1002.pcapng` |
| V4 cifrado radio | Bloqueado (sin plano GTP) | ver `kali.md` causa raiz |
| V5 rogue eNodeB | Ejecutado, no atraido en ventana | `results/v5_rogue_*.log` |
| V6 GTP-U injection | Bloqueado (sin plano GTP) | ver `kali.md` causa raiz |
| V7 BYE forjado | Vulnerable confirmado | `results/v7_bye_1001-to-1000_*.pcapng` |

Detalle, metricas y contramedidas pendientes en `kali.md`.

## Estructura

```text
voLTE-lab/
├── docker-compose.yml          Red volte-net + servicios
├── lab-up.sh / lab-down.sh     Orquestacion 13 pasos / apagado
├── kali.md                     Runbook atacante + estado V1-V7
├── srsran/                     Dockerfile + enb-config/ + ue-config/ + baresip-config/
├── open5gs/ + open5gs-config/   Dockerfile + mme.yaml/mme.conf/nrf.yaml
├── open5gs-webui/               WebUI suscriptores
├── kamailio/                    Dockerfile + pcscf/icscf/scscf
├── asterisk/                    Dockerfile + pjsip.conf + extensions.conf
├── pyhss/                       HSS IMS + docker/.env
├── attacks/                     Scripts v1-v7
├── vectores/                    Wrappers v1_mitm.sh ... v7_bye.sh
├── captures/                    Capturas manuales
├── results/                     Evidencia + hashes.txt
└── reports/                     (reservado para informes)
```

Guia completa de replica en el `README.md` de la raiz del repositorio.
