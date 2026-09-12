# Laboratorio VoLTE con Docker

Laboratorio de tecnología **VoLTE (Voice over LTE)** completamente simulado, sin necesidad de hardware SDR. Todo corre en contenedores Docker sobre Windows con WSL2.

## Arquitectura

```
172.20.0.0/24
├── 172.20.0.2  →  MongoDB        (base de datos de suscriptores)
├── 172.20.0.3  →  Open5GS        (EPC: MME, HSS, SGW, PGW, PCRF)
├── 172.20.0.4  →  srsRAN eNB     (radio simulada con ZMQ)
├── 172.20.0.5  →  srsRAN UE      (dispositivo simulado)
├── 172.20.0.6  →  Kamailio       (IMS: P-CSCF, I-CSCF, S-CSCF)
└── 172.20.0.7  →  Asterisk       (media server / TAS)
```

## Stack tecnológico

| Componente | Tecnología | Versión |
|---|---|---|
| Radio simulada | srsRAN 4G + ZMQ | 25.10.0 |
| EPC (núcleo 4G) | Open5GS | 2.8.0 |
| IMS Core | Kamailio | 5.8.8 |
| Media Server | Asterisk | 21.12.2 |
| Base de datos | MongoDB | 4.4 |
| Infraestructura | Docker + WSL2 | — |

## Requisitos mínimos

- Windows 10/11 de 64 bits
- 16 GB de RAM
- 50 GB de espacio libre en disco
- Conexión a internet (para descargar imágenes y compilar)

## Estructura del repositorio

```
laboratorio-volte/
├── README.md                  ← estás aquí
├── 0-prerequisitos/
│   └── README.md              ← instalar Docker + WSL2
├── 1-srsran/
│   ├── Dockerfile
│   └── README.md
├── 2-open5gs/
│   ├── Dockerfile
│   └── README.md
├── 3-kamailio/
│   ├── Dockerfile
│   └── README.md
├── 4-asterisk/
│   ├── Dockerfile
│   └── README.md
└── 5-integracion/
    ├── docker-compose.yml
    └── README.md
```

## ¿Por dónde empezar?

Sigue las carpetas en orden numérico:

1. [`0-prerequisitos`](./0-prerequisitos/README.md) — Instala Docker y WSL2
2. [`1-srsran`](./1-srsran/README.md) — Compila srsRAN con ZMQ
3. [`2-open5gs`](./2-open5gs/README.md) — Compila Open5GS
4. [`3-kamailio`](./3-kamailio/README.md) — Compila Kamailio con módulos IMS
5. [`4-asterisk`](./4-asterisk/README.md) — Compila Asterisk
6. [`5-integracion`](./5-integracion/README.md) — Levanta todo junto con docker-compose

## ⏱️ Tiempo estimado

La compilación completa desde cero toma aproximadamente **60-90 minutos** dependiendo del hardware, ya que srsRAN, Open5GS, Kamailio y Asterisk se compilan desde el código fuente.
