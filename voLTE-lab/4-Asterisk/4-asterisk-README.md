# Asterisk

Asterisk es una plataforma de comunicaciones open source. En este laboratorio actúa como el servidor de medios y TAS (Telephony Application Server) del IMS, encargado de procesar el audio de las llamadas VoLTE.

- [Ver contenido del Dockerfile](#contenido-del-dockerfile)

## Rol en el laboratorio

| Funcion | Descripcion |
|---|---|
| TAS | Telephony Application Server, gestiona la logica de llamadas |
| Media Server | Procesa el audio RTP entre los extremos de la llamada |
| PJSIP | Interfaz SIP con Kamailio (S-CSCF) |

## Contenido

```
4-asterisk/
├── Dockerfile
└── README.md
```

## Nota sobre el Dockerfile

El script `install_prereq` que incluye Asterisk por defecto requiere `aptitude`, que no esta disponible en Ubuntu 22.04. Por eso en este Dockerfile se instalan todas las dependencias manualmente con `apt-get` y se omite ese script.

## Construccion de la imagen

Desde la terminal de Ubuntu, dentro de la carpeta `4-asterisk`:

```bash
docker build -t asterisk-ims:latest .
```

La compilacion tarda aproximadamente 15-20 minutos porque descarga y compila Asterisk desde el codigo fuente.

## Verificacion

```bash
docker run --rm asterisk-ims:latest asterisk -V
```

Deberias ver:

```
Asterisk 21.12.2
```

## Siguiente paso

Una vez verificada la imagen continua con [`5-integracion`](../5-integracion/README.md).

---

## Contenido del Dockerfile

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential git curl wget \
    libssl-dev libncurses5-dev libnewt-dev \
    libxml2-dev libsqlite3-dev uuid-dev \
    libjansson-dev libedit-dev \
    libsrtp2-dev libopus-dev \
    python3 python3-pip \
    iproute2 iputils-ping net-tools \
    libasound2-dev libcurl4-openssl-dev \
    libvorbis-dev libogg-dev \
    libspandsp-dev libgsm1-dev \
    libbluetooth-dev libradcli-dev \
    libcorosync-common-dev libcpg-dev \
    libiksemel-dev libneon27-dev \
    libgmime-3.0-dev liblua5.2-dev \
    libpopt-dev libresample1-dev \
    libc-client2007e-dev binutils-dev \
    libsybdb5 freetds-dev \
    libpq-dev unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cd /usr/src && \
    wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-21-current.tar.gz && \
    tar xzf asterisk-21-current.tar.gz && \
    cd asterisk-21*/ && \
    ./configure --with-jansson-bundled && \
    make -j$(nproc) && \
    make install && \
    make samples

WORKDIR /etc/asterisk

CMD ["/bin/bash"]
```
