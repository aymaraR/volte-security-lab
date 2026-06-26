# Open5GS

Open5GS es una implementación open source del núcleo de red 4G/5G. En este laboratorio actúa como el EPC (Evolved Packet Core), que es el cerebro de la red LTE. Incluye los componentes MME, HSS, SGW, PGW y PCRF.

- [Ver contenido del Dockerfile](#contenido-del-dockerfile)

## Componentes que se levantan

| Binario | Componente | Funcion |
|---|---|---|
| open5gs-mmed | MME | Gestiona la movilidad y autenticacion de los UEs |
| open5gs-hssd | HSS | Base de datos de suscriptores |
| open5gs-sgwcd | SGW-C | Control del gateway de servicio |
| open5gs-sgwud | SGW-U | Plano de usuario del gateway de servicio |
| open5gs-pcrfd | PCRF | Control de politicas y carga |
| open5gs-upfd | UPF | Plano de usuario |

## Contenido

```
2-open5gs/
├── Dockerfile
└── README.md
```

## Prerequisito importante

Este Dockerfile usa `COPY . /open5gs`, lo que significa que necesitas el codigo fuente de Open5GS en la misma carpeta antes de construir la imagen. Clonalo asi:

```bash
cd 2-open5gs
git clone https://github.com/open5gs/open5gs.git .
```

El punto al final es importante — indica que clone dentro de la carpeta actual.

## Construccion de la imagen

```bash
docker build -t open5gs-local:latest .
```

La compilacion tarda aproximadamente 10-15 minutos.

## Verificacion

```bash
docker run --rm open5gs-local:latest open5gs-mmed --version
```

Deberias ver algo como:

```
Open5GS daemon v2.8.0
[app] INFO: Configuration: '/etc/open5gs/mme.yaml'
[mme] INFO: s1ap_server() [127.0.0.2]:36412
[sctp] INFO: MME initialize...done
```

El proceso queda corriendo — eso es normal. Presiona Ctrl+C para detenerlo.

## Binarios instalados

Todos los binarios quedan en `/usr/bin/open5gs-*`. Puedes listarlos con:

```bash
docker run --rm open5gs-local:latest ls /usr/bin/open5gs-*
```

## Siguiente paso

Una vez verificada la imagen continua con [`3-kamailio`](../3-kamailio/README.md).

---

## Contenido del Dockerfile

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3-pip python3-setuptools python3-wheel \
    ninja-build build-essential flex bison git \
    cmake libsctp-dev libgnutls28-dev libgcrypt-dev \
    libssl-dev libidn11-dev libmongoc-dev libbson-dev \
    libyaml-dev libnghttp2-dev libmicrohttpd-dev \
    libcurl4-gnutls-dev libtins-dev libtalloc-dev \
    meson iproute2 iputils-ping net-tools \
    && rm -rf /var/lib/apt/lists/*

COPY . /open5gs

RUN cd /open5gs && \
    meson build --prefix=/usr && \
    ninja -C build && \
    ninja -C build install

EXPOSE 3000

WORKDIR /open5gs

CMD ["/bin/bash"]
```
