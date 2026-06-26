# Configuraciones extra: enb-config

## 1. Subir los archivos de la carpeta enb-config

```bash
docker exec srsenb mkdir -p /root/enb-config

docker cp ~/voLTE-lab/srsran/enb-config/enb.conf srsenb:/root/enb-config/enb.conf
docker cp ~/voLTE-lab/srsran/enb-config/rr.conf  srsenb:/root/enb-config/rr.conf
docker cp ~/voLTE-lab/srsran/enb-config/sib.conf srsenb:/root/enb-config/sib.conf
docker cp ~/voLTE-lab/srsran/enb-config/rb.conf  srsenb:/root/enb-config/rb.conf
```

Verificamos con:

```bash
docker exec srsenb ls -la /root/enb-config
```

Deberíamos tener algo como:

```
total 48
drwxr-xr-x 2 root root  4096 Jun 25 03:24 .
drwx------ 1 root root  4096 Jun 25 03:23 ..
-rw-r--r-- 1 1000 1000 20029 Jun 25 01:00 enb.conf
-rw-r--r-- 1 1000 1000  3386 Jun 24 21:28 rb.conf
-rw-r--r-- 1 1000 1000  3038 Jun 25 01:10 rr.conf
-rw-r--r-- 1 1000 1000 10583 Jun 24 21:28 sib.conf
```

## 2. Primer arranque de srsenb

```bash
docker exec -it srsenb bash -c "cd /root/enb-config && srsenb enb.conf"
```

**Observación:** existe la posibilidad de que aparezca un error de conexión ZMQ, ya que el UE todavía no está levantado.

## Siguiente paso

Levantar srsue.
