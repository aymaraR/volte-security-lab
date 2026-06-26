# Integracion — Levantar el laboratorio completo

Esta sección contiene el `docker-compose.yml` que levanta todos los componentes del laboratorio en una red interna compartida con IPs fijas.

- [Ver contenido del docker-compose.yml](#contenido-del-docker-composeyml)

## Prerequisito

Antes de continuar asegurate de haber construido todas las imagenes Docker en las secciones anteriores. Puedes verificar que estan disponibles con:

```bash
docker images
```

Deberias ver las siguientes imagenes listadas:

```
srsran-zmq        latest
open5gs-local     latest
kamailio-ims      latest
asterisk-ims      latest
```

## Arquitectura de red

```
172.20.0.0/24
├── 172.20.0.2  →  MongoDB        (base de datos de suscriptores)
├── 172.20.0.3  →  Open5GS        (EPC: MME, HSS, SGW, PGW, PCRF)
├── 172.20.0.4  →  srsRAN eNB     (radio simulada con ZMQ)
├── 172.20.0.5  →  srsRAN UE      (dispositivo simulado)
├── 172.20.0.6  →  Kamailio       (IMS: P-CSCF, I-CSCF, S-CSCF)
└── 172.20.0.7  →  Asterisk       (media server / TAS)
```

## Contenido

```
5-integracion/
├── docker-compose.yml
└── README.md
```

## Levantar el laboratorio

Desde la terminal de Ubuntu, dentro de la carpeta `5-integracion`:

```bash
docker compose up -d
```

Verifica que todos los contenedores estan corriendo:

```bash
docker ps
```

Deberias ver 6 contenedores con estado `Up`:

```
mongodb
open5gs
kamailio
asterisk
srsenb
srsue
```

## Detener el laboratorio

```bash
docker compose down
```

Si ademas quieres eliminar los datos de MongoDB:

```bash
docker compose down -v
```

## Notas sobre el estado inicial

Los contenedores de Kamailio, Asterisk, srsenb y srsue arrancan con `sleep infinity` porque aun no tienen archivos de configuracion. El siguiente paso del laboratorio es configurar cada componente para que se comuniquen entre si.

Open5gs arranca sus servicios automaticamente pero tambien requiere configuracion adicional para apuntar al IMS.

---

## Contenido del docker-compose.yml

```yaml
networks:
  volte-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24

services:

  mongodb:
    image: mongo:4.4
    container_name: mongodb
    networks:
      volte-net:
        ipv4_address: 172.20.0.2
    volumes:
      - mongodb_data:/data/db

  open5gs:
    image: open5gs-local:latest
    container_name: open5gs
    privileged: true
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.ip_forward=1
    networks:
      volte-net:
        ipv4_address: 172.20.0.3
    environment:
      - DB_URI=mongodb://172.20.0.2/open5gs
    depends_on:
      - mongodb
    ports:
      - "3000:3000"
    command: >
      bash -c "
        open5gs-nrfd &
        sleep 2 &&
        open5gs-mmed &
        open5gs-sgwcd &
        open5gs-sgwud &
        open5gs-smfd &
        open5gs-amfd &
        open5gs-hssd &
        open5gs-pcrfd &
        open5gs-upfd &
        wait
      "

  kamailio:
    image: kamailio-ims:latest
    container_name: kamailio
    privileged: true
    cap_add:
      - NET_ADMIN
    networks:
      volte-net:
        ipv4_address: 172.20.0.6
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp"
    command: bash -c "sleep infinity"

  asterisk:
    image: asterisk-ims:latest
    container_name: asterisk
    privileged: true
    networks:
      volte-net:
        ipv4_address: 172.20.0.7
    ports:
      - "5061:5061/udp"
      - "10000-10100:10000-10100/udp"
    command: bash -c "sleep infinity"

  enb:
    image: srsran-zmq:latest
    container_name: srsenb
    privileged: true
    cap_add:
      - NET_ADMIN
    networks:
      volte-net:
        ipv4_address: 172.20.0.4
    depends_on:
      - open5gs
    command: bash -c "sleep infinity"

  ue:
    image: srsran-zmq:latest
    container_name: srsue
    privileged: true
    cap_add:
      - NET_ADMIN
    networks:
      volte-net:
        ipv4_address: 172.20.0.5
    depends_on:
      - enb
    command: bash -c "sleep infinity"

volumes:
  mongodb_data:
```
