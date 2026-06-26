# Kamailio

Kamailio es un servidor SIP open source de alto rendimiento. En este laboratorio actúa como el núcleo IMS (IP Multimedia Subsystem), que es la capa encargada de gestionar las llamadas de voz sobre LTE. Se compila con los módulos específicos para IMS: P-CSCF, I-CSCF y S-CSCF.

- [Ver contenido del Dockerfile](#contenido-del-dockerfile)

## Rol en el laboratorio

| Componente IMS | Funcion |
|---|---|
| P-CSCF (Proxy-CSCF) | Primer punto de contacto del UE con el IMS |
| I-CSCF (Interrogating-CSCF) | Enruta las solicitudes al S-CSCF correcto |
| S-CSCF (Serving-CSCF) | Gestiona el registro y las sesiones SIP |

## Contenido

```
3-kamailio/
├── Dockerfile
└── README.md
```

## Modulos IMS compilados

El Dockerfile compila Kamailio incluyendo los siguientes modulos necesarios para VoLTE:

- `ims_registrar_pcscf` / `ims_usrloc_pcscf` / `ims_ipsec_pcscf` — funciones P-CSCF
- `ims_registrar_scscf` / `ims_usrloc_scscf` / `ims_dialog` — funciones S-CSCF
- `cdp` / `cdp_avp` — interfaz Diameter (Cx/Rx) con el HSS y PCRF
- `ims_charging` — control de carga
- `tls` / `websocket` / `presence` — soporte TLS, WebSocket y presencia

## Construccion de la imagen

Desde la terminal de Ubuntu, dentro de la carpeta `3-kamailio`:

```bash
docker build -t kamailio-ims:latest .
```

La compilacion tarda aproximadamente 10-15 minutos.

## Verificacion

```bash
docker run --rm kamailio-ims:latest kamailio -V
```

Deberias ver algo como:

```
version: kamailio 5.8.8 (x86_64/linux)
flags: USE_TCP, USE_TLS, USE_SCTP, TLS_HOOKS...
```

## Siguiente paso

Una vez verificada la imagen continua con [`4-asterisk`](../4-asterisk/README.md).

---

## Contenido del Dockerfile

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake build-essential git curl \
    bison flex python3 \
    libmysqlclient-dev libssl-dev libcurl4-openssl-dev \
    libxml2-dev libpcre3-dev libunistring-dev \
    libsctp-dev libmnl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 5.8 https://github.com/kamailio/kamailio.git /kamailio && \
    cd /kamailio && \
    make cfg && \
    make include_modules="db_mysql tls websocket presence ims_registrar_pcscf \
        ims_usrloc_pcscf ims_ipsec_pcscf cdp cdp_avp \
        ims_registrar_scscf ims_usrloc_scscf ims_dialog \
        ims_charging" cfg && \
    make -j$(nproc) && \
    make install

WORKDIR /kamailio

CMD ["/bin/bash"]
```
