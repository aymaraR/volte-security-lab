# srsRAN 4G con ZMQ

srsRAN es un stack de radio LTE open source. En este laboratorio se usa la versión 4G con el backend ZMQ, que reemplaza el hardware SDR por una radio virtual sobre sockets. Esto permite simular tanto el eNodeB (antena) como el UE (dispositivo) sin ningún equipo físico.

- [Ver contenido del Dockerfile](#contenido-del-dockerfile)

## Por que srsRAN 4G y no 5G

Como muchas de las vunerabilidades de 4G migran a 5G se opta por centrarse en 4G

## Contenido

```
1-srsran/
├── Dockerfile
└── README.md
```

## Construccion de la imagen

Desde la terminal de Ubuntu, dentro de la carpeta `1-srsran`:

```bash
docker build -t srsran-zmq:latest .
```

La compilacion tarda aproximadamente 15-20 minutos porque descarga y compila srsRAN desde el codigo fuente.

## Verificacion

```bash
docker run --rm srsran-zmq:latest srsenb --version
```

Deberias ver:

```
Active RF plugins: libsrsran_rf_zmq.so
Inactive RF plugins:
---  Software Radio Systems LTE eNodeB  ---

Version 25.10.0
```

La linea `libsrsran_rf_zmq.so` confirma que el backend de radio virtual esta activo.

## Que instala este Dockerfile

- Dependencias de compilacion (cmake, gcc, boost, fftw3)
- libzmq3 — backend de radio virtual
- srsRAN_4G compilado con ZMQ habilitado (`-DENABLE_ZMQ=ON`)

## Siguiente paso

Una vez verificada la imagen continua con [`2-open5gs`](../2-open5gs/README.md).

---

## Contenido del Dockerfile

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake build-essential git \
    libfftw3-dev libmbedtls-dev libboost-all-dev \
    libconfig++-dev libsctp-dev \
    libzmq3-dev \
    python3 python3-pip \
    iproute2 iputils-ping net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/srsran/srsRAN_4G.git /srsran && \
    cd /srsran && \
    mkdir build && cd build && \
    cmake .. -DENABLE_ZMQ=ON && \
    make -j$(nproc) && \
    make install && \
    ldconfig

WORKDIR /srsran/build

CMD ["/bin/bash"]
```
