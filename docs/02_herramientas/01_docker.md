# 🐳 Herramienta: Docker

## 1. ¿Qué es Docker?

**Docker** es una plataforma de contenedores que permite empaquetar aplicaciones junto con todas sus dependencias en unidades aisladas llamadas **contenedores**. A diferencia de las máquinas virtuales, los contenedores comparten el kernel del sistema operativo host, siendo mucho más ligeros.

---

## 2. Conceptos Clave

| Concepto | Descripción |
|---|---|
| **Imagen** | Plantilla inmutable (snapshot) de un sistema de archivos. Base para crear contenedores. |
| **Contenedor** | Instancia en ejecución de una imagen. Proceso aislado con su propio filesystem, red y PID. |
| **Dockerfile** | Script de instrucciones para construir una imagen paso a paso. |
| **Docker Compose** | Herramienta para definir y orquestar múltiples contenedores con un único archivo YAML. |
| **Red Docker** | Red virtual privada donde los contenedores se comunican entre sí por nombre. |
| **Volumen** | Almacenamiento persistente que sobrevive al ciclo de vida del contenedor. |

---

## 3. Relevancia para el Laboratorio

En este proyecto, Docker permite:

1. **Aislamiento total:** cada componente (Open5GS, Kamailio, Asterisk, Kali) corre en su propio contenedor sin interferir con el sistema host.
2. **Reproducibilidad:** cualquier persona puede levantar el entorno completo con un solo comando.
3. **Redes virtuales:** se puede simular la topología de red LTE (diferentes segmentos para EPC, IMS, atacante) sin hardware adicional.
4. **Fácil teardown:** `docker compose down` elimina todo sin dejar residuos en el sistema.

---

## 4. Docker Compose — Estructura Básica

```yaml
# docker-compose.yml
version: '3.8'

services:
  open5gs-mme:
    image: gradiant/open5gs
    container_name: mme
    networks:
      lte-core:
        ipv4_address: 172.20.0.10

  kamailio:
    image: kamailio/kamailio
    container_name: ims-proxy
    depends_on:
      - open5gs-mme
    networks:
      lte-core:
        ipv4_address: 172.20.0.20
      ims-net:
        ipv4_address: 172.21.0.10

  kali:
    image: kalilinux/kali-rolling
    container_name: attacker
    cap_add:
      - NET_ADMIN        # necesario para herramientas de red
    networks:
      ims-net:
        ipv4_address: 172.21.0.99

networks:
  lte-core:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
  ims-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/24
```

---

## 5. Comandos Esenciales

```bash
# Construir imágenes definidas en el Compose
docker compose build

# Levantar todo el entorno en segundo plano
docker compose up -d

# Ver logs de un servicio específico
docker compose logs -f kamailio

# Entrar a un contenedor (shell interactivo)
docker exec -it attacker bash

# Ver contenedores en ejecución
docker compose ps

# Detener y eliminar contenedores (mantiene imágenes y volúmenes)
docker compose down

# Detener y eliminar TODO (incluyendo volúmenes y redes)
docker compose down -v --remove-orphans
```

---

## 6. Consideraciones de Red para LTE

Para emular correctamente la red LTE dentro de Docker es necesario configurar:

- **TUN/TAP interfaces:** srsRAN necesita crear interfaces de red virtuales (`tun_srsue`). El contenedor requiere `--cap-add NET_ADMIN` y `--device /dev/net/tun`.
- **IP forwarding:** habilitado en el host para rutear tráfico entre contenedores.
- **SCTP:** el protocolo S1AP usa SCTP. Verificar que el kernel del host tenga el módulo `sctp` cargado (`modprobe sctp`).

```bash
# Verificar SCTP en el host
modprobe sctp
lsmod | grep sctp

# Habilitar IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
```

---

## 7. Recursos

- Documentación oficial: https://docs.docker.com
- Docker Compose reference: https://docs.docker.com/compose/compose-file/
- Docker Hub: https://hub.docker.com
