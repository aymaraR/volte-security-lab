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

Dejandolo correr por unos segundo deberia salir algo como: 

```
Active RF plugins: libsrsran_rf_zmq.so
Inactive RF plugins:
---  Software Radio Systems LTE eNodeB  ---

Reading configuration file enb.conf...

Built in Release mode using commit 6bcbd9e5b on branch master.

Opening 1 channels in RF device=zmq with args=fail_on_disconnect=true,tx_port0=tcp://*:2000,rx_port0=tcp://172.20.0.5:2001,id=enb,base_srate=23.04e6
Supported RF device list: zmq file
CHx base_srate=23.04e6
CHx id=enb
Current sample rate is 1.92 MHz with a base rate of 23.04 MHz (x12 decimation)
CH0 rx_port=tcp://172.20.0.5:2001
CH0 tx_port=tcp://*:2000
CH0 fail_on_disconnect=true

==== eNodeB started ===
Type <t> to view trace
Current sample rate is 11.52 MHz with a base rate of 23.04 MHz (x2 decimation)
Current sample rate is 11.52 MHz with a base rate of 23.04 MHz (x2 decimation)
Setting frequency: DL=2680.0 Mhz, UL=2560.0 MHz for cc_idx=0 nof_prb=50
```

## Siguiente paso

Levantar srsue.
