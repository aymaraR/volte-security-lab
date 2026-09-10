# 🗺️ Arquitectura del Laboratorio

## 1. Vista general

Nuestra solución se encuentra en un laboratorio que virtualiza una red 4G LTE completa con soporte VoLTE usando exclusivamente software de código abierto sobre Docker. Ningún componente emite señal de radio real — la interfaz de radio entre srsUE y srsENB se simula mediante **ZeroMQ** (mensajes sobre TCP).

En este documento se encuentra la topología completa del laboratorio: qué contenedores existen, cómo se interconectan, qué direccionamiento IP usan y qué interfaz de red real (loopback, ZMQ, bridge Docker) transporta cada tramo de la cadena VoLTE. 

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

## 3. Requisitos del Sistema Host

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU | 4 núcleos | 8 núcleos |
| RAM | 8 GB | 16 GB |
| Disco | 20 GB | 40 GB |
| SO | Linux (kernel 5.x+) | Ubuntu 22.04 LTS |
| Docker | 24.x | 25.x |
| Docker Compose | v2.x | v2.x |

---

## 4. Segmentos de Red

| Segmento | Rango / dirección | Tecnología | Tráfico que transporta |
|---|---|---|---|
| Interfaz radio emulada | `127.0.0.1:2000` / `127.0.0.1:2001` | Sockets TCP (ZeroMQ) | Muestras I/Q entre srsUE y srsENB (equivalente lógico de la interfaz LTE-Uu) |
| Túnel de datos del UE | `10.45.0.0/16` | Interfaz virtual `tun_srsue` | Tráfico IP de usuario una vez asignada la IP por el PGW |
| Red bridge del laboratorio | `172.16.0.0/24` | Docker bridge | S1-MME, S1-U, S6a, Gx, SIP (Gm), Diameter Cx, RTP |
| Túnel GTP-U | Interfaz virtual `ogstun` en el host | GTP-U | Plano de usuario encapsulado entre eNodeB y PGW (incluye el RTP de la llamada) |

---

## 5. Direccionamiento Fijo de Contenedores

Reiterando el detalle ya introducido en `../02_herramientas/01_docker.md`, para facilitar la reproducibilidad de capturas y scripts de ataque, cada contenedor recibe una IP estática dentro de `172.16.0.0/24`:

| Contenedor | IP | Capa | Herramienta |
|---|---|---|---|
| open5gs-mme | 172.16.0.10 | EPC | Open5GS |
| open5gs-sgw | 172.16.0.11 | EPC | Open5GS |
| open5gs-pgw | 172.16.0.12 | EPC | Open5GS |
| open5gs-hss | 172.16.0.13 | EPC | Open5GS |
| open5gs-pcrf | 172.16.0.14 | EPC | Open5GS |
| kamailio-pcscf | 172.16.0.20 | IMS | Kamailio (P-CSCF) |
| kamailio-scscf | 172.16.0.21 | IMS | Kamailio (S-CSCF) |
| kamailio-icscf | 172.16.0.22 | IMS | Kamailio (I-CSCF) |
| asterisk-mgcf | 172.16.0.23 | IMS / Media | Asterisk |
| kali-attacker | 172.16.0.99 | Atacante | Kali Linux |

Los procesos `srsenb`/`srsue` corren directamente sobre el host (no dentro de contenedores), comunicándose con el MME de Open5GS a través de la IP `172.16.0.10` publicada en la red bridge, típicamente mediante un puente adicional (`macvlan` o publicación de puertos) que permite que el proceso del host alcance la subred `172.16.0.0/24`.

---

## 6. Puntos de Posicionamiento del Atacante

Cada vector de ataque asume una posición de red específica para el contenedor `kali-attacker`, coherente con el requisito de que el laboratorio nunca exponga tráfico fuera de la red bridge aislada:

| Vector | Posición del atacante | Técnica de posicionamiento |
|---|---|---|
| V1 — MITM SIP | Entre srsUE y P-CSCF | ARP spoofing dentro de `172.16.0.0/24` |
| V2 — DoS IMS | Cualquier punto con alcance al S-CSCF | Envío directo de tráfico (no requiere MITM) |
| V3 — Suplantación | Cualquier punto con alcance al P-CSCF | Envío de INVITE forjado (Scapy) |
| V4 — Cifrado radio | Acceso de lectura al log/captura de `srsenb` o a `ogstun` | Captura pasiva, sin necesidad de spoofing |
| V5 — Rogue eNodeB | Segundo proceso `srsenb` con mayor prioridad de celda | Competencia de reselección de celda |
| V6 — GTP-U Injection | Con visibilidad del túnel `ogstun` y el TEID de sesión | Inyección de paquetes GTP-U forjados |
| V7 — SIP BYE forjado | Cualquier punto con alcance al S-CSCF | Envío de BYE sin autenticación de diálogo |

---

## 7. Correspondencia con Docker Compose

La topología descrita se declara íntegramente en `docker-compose.yml`, que además de las IPs fijas define las dependencias de arranque (`depends_on`) para garantizar que el HSS y el MME estén operativos antes de intentar el primer Attach:

```yaml
services:
  open5gs-hss:
    networks:
      volte-lab-net:
        ipv4_address: 172.16.0.13

  open5gs-mme:
    depends_on: [open5gs-hss]
    networks:
      volte-lab-net:
        ipv4_address: 172.16.0.10

  kamailio-pcscf:
    depends_on: [open5gs-mme]
    networks:
      volte-lab-net:
        ipv4_address: 172.16.0.20

  kali-attacker:
    networks:
      volte-lab-net:
        ipv4_address: 172.16.0.99
```

---

## 8. Diferencias Explícitas con una Red Real

Esta topología reproduce fielmente el comportamiento de los planos de señalización y control, pero difiere deliberadamente de una red comercial en los siguientes puntos (ya introducidos en el README del repositorio, aquí con detalle de arquitectura):

- **Sin RF física:** el segmento "radio" es en realidad un socket TCP en loopback, sin fading, interferencia ni movilidad real.
- **Escala reducida:** 1-2 UE emulados frente a miles/millones de suscriptores concurrentes en producción.
- **Sin interconexión externa:** no existe roaming ni señalización SS7/Diameter hacia otras redes; toda la topología vive dentro de una única red bridge.
- **Terminales sin USIM certificada:** las credenciales del UE emulado se almacenan en texto plano en MongoDB, no en hardware inviolable.

---

## 9. Recursos

- srsRAN 4G Project — https://github.com/srsran/srsRAN_4G
- srsRAN con ZeroMQ: https://docs.srsran.com/projects/4g/en/latest/app_notes/source/zeromq/source/index.html
- Open5GS Docker: https://github.com/gradiant/open5gs-docker
- Diagrama de referencia 3GPP TS 23.002
- Docker Compose networking — https://docs.docker.com/compose/networking/

---

**Siguiente documento:** [`02_flujo_llamada_volte.md`](02_flujo_llamada_volte.md) — Ciclo de vida de una llamada VoLTE.





