# 🗺️ Arquitectura del Laboratorio

## 1. Visión General

El laboratorio virtualiza una red 4G LTE completa con soporte VoLTE usando exclusivamente software de código abierto sobre Docker. Ningún componente emite señal de radio real — la interfaz de radio entre srsUE y srsENB se simula mediante **ZeroMQ** (mensajes sobre TCP).

---

## 2. Diagrama de Topología

```
╔══════════════════════════════════════════════════════════════════════╗
║                     HOST (Linux / Docker Engine)                     ║
║                                                                      ║
║  ┌─────────────────────────────────────────────────────────────┐    ║
║  │              RED LTE-CORE  (172.20.0.0/24)                  │    ║
║  │                                                             │    ║
║  │   ┌──────────────┐    S1-MME/S1-U    ┌──────────────────┐  │    ║
║  │   │   srsENB     │ ────────────────> │    Open5GS EPC   │  │    ║
║  │   │ 172.20.0.2   │                   │    172.20.0.10   │  │    ║
║  │   │  (eNodeB)    │                   │  MME/SGW/PGW/HSS │  │    ║
║  │   └──────┬───────┘                   └────────┬─────────┘  │    ║
║  │          │ ZeroMQ (TCP)                       │ SGi/Gi     │    ║
║  │          │                                    │            │    ║
║  │   ┌──────┴───────┐                   ┌────────┴─────────┐  │    ║
║  │   │   srsUE      │                   │   Red IMS        │  │    ║
║  │   │ 172.20.0.3   │                   │  (172.21.0.0/24) │  │    ║
║  │   │  (UE / SIM)  │                   └──────────────────┘  │    ║
║  │   └──────────────┘                                         │    ║
║  └─────────────────────────────────────────────────────────────┘    ║
║                                                                      ║
║  ┌─────────────────────────────────────────────────────────────┐    ║
║  │              RED IMS  (172.21.0.0/24)                       │    ║
║  │                                                             │    ║
║  │   ┌──────────────┐   SIP    ┌──────────────┐               │    ║
║  │   │   Kamailio   │ ──────── │   Asterisk   │               │    ║
║  │   │ 172.21.0.10  │          │ 172.21.0.20  │               │    ║
║  │   │ (P/S-CSCF)  │          │  (AS + RTP)  │               │    ║
║  │   └──────────────┘          └──────┬───────┘               │    ║
║  │                                    │ RTP (sin cifrar)       │    ║
║  │   ┌──────────────┐                 │                        │    ║
║  │   │  Kali Linux  │ ════════════════╝  (captura RTP)        │    ║
║  │   │ 172.21.0.99  │                                          │    ║
║  │   │  (ATACANTE)  │                                          │    ║
║  │   └──────────────┘                                          │    ║
║  └─────────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 3. Segmentación de Redes Docker

El laboratorio usa **dos redes virtuales separadas** para reflejar la arquitectura real de un operador:

| Red | Subred | Propósito |
|---|---|---|
| `lte-core` | `172.20.0.0/24` | Comunicación entre eNB, EPC (plano de control y usuario LTE) |
| `ims-net` | `172.21.0.0/24` | Comunicación entre EPC, IMS (SIP/RTP), y atacante |

---

## 4. Tabla de Contenedores y Direcciones IP

| Contenedor | Imagen | Red(s) | IP(s) | Puerto(s) |
|---|---|---|---|---|
| `srsenb` | srsran/srsenb | lte-core | 172.20.0.2 | — |
| `srsue` | srsran/srsue | lte-core | 172.20.0.3 | — |
| `open5gs` | gradiant/open5gs | lte-core, ims-net | 172.20.0.10 / 172.21.0.5 | 36412/sctp (S1-MME) |
| `kamailio` | kamailio/kamailio | ims-net | 172.21.0.10 | 5060/udp, 5060/tcp |
| `asterisk` | andrius/asterisk | ims-net | 172.21.0.20 | 5060/udp, 10000-20000/udp |
| `kali` | kalilinux/kali-rolling | ims-net | 172.21.0.99 | — |

---

## 5. Interfaces Simuladas

### ZeroMQ — Canal de Radio Virtual

En lugar de usar hardware SDR (USRP, bladeRF, etc.), srsRAN usa ZeroMQ para simular la interfaz de radio:

```
srsUE                          srsENB
  |                               |
  | tx_port=tcp://*:2001 ─────>  rx_port=tcp://srsenb:2001
  | rx_port=tcp://srsenb:2000 <─ tx_port=tcp://*:2000
```

### Interfaz TUN — Plano de Usuario

Cuando el UE completa el Attach, Open5GS crea una interfaz TUN en el contenedor PGW/UPF para el plano de usuario:

```bash
# Dentro del contenedor Open5GS
ip addr show ogstun
# 10.45.0.1/16 — gateway del UE
```

El srsUE también crea una interfaz TUN en su contenedor:
```bash
# Dentro del contenedor srsUE
ip addr show tun_srsue
# 10.45.0.X/16 — IP asignada al "teléfono"
```

---

## 6. Flujo de Datos por Capa

```
CAPA DE APLICACIÓN (Voz)
  └─ codec AMR-WB / G.711

CAPA DE TRANSPORTE (IMS)
  └─ RTP/UDP ──── encapsulado en ────> GTP-U/UDP

CAPA DE RED (LTE Plano Usuario)
  └─ GTP-U: tun_srsue <──> eNB <──> SGW <──> PGW <──> IMS

CAPA DE CONTROL (LTE Señalización)
  └─ NAS: UE ──> MME (sobre S1AP)
  └─ S1AP: eNB ──> MME (sobre SCTP)
  └─ GTPv2-C: MME ──> SGW ──> PGW

CAPA DE SEÑALIZACIÓN IMS
  └─ SIP: UE ──> Kamailio ──> Asterisk
```

---

## 7. Requisitos del Sistema Host

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU | 4 núcleos | 8 núcleos |
| RAM | 8 GB | 16 GB |
| Disco | 20 GB | 40 GB |
| SO | Linux (kernel 5.x+) | Ubuntu 22.04 LTS |
| Docker | 24.x | 25.x |
| Docker Compose | v2.x | v2.x |

### Módulos de kernel necesarios

```bash
# SCTP (para S1AP entre eNB y MME)
modprobe sctp

# TUN (para interfaces virtuales del UE y PGW)
modprobe tun

# Verificar
lsmod | grep -E "sctp|tun"
```

---

## 8. Recursos

- srsRAN con ZeroMQ: https://docs.srsran.com/projects/4g/en/latest/app_notes/source/zeromq/source/index.html
- Open5GS Docker: https://github.com/gradiant/open5gs-docker
- Diagrama de referencia 3GPP TS 23.002
