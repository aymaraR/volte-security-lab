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

## 3. Subir ue.conf al contenedor

```bash
docker exec srsue mkdir -p /root/ue-config
docker cp ~/voLTE-lab/srsran/ue-config/ue.conf srsue:/root/ue-config/ue.conf
docker exec srsue ls -la /root/ue-config
```

Deberíamos tener algo como:

```
total 28
drwxr-xr-x 2 root root  4096 Jun 25 03:29 .
drwx------ 1 root root  4096 Jun 25 03:29 ..
-rw-r--r-- 1 1000 1000 19440 Jun 25 03:19 ue.conf
```

## 4. Arrancar el UE

En la misma terminal del UE, con el eNB todavía corriendo en la primera terminal:

```bash
docker exec -it srsue bash -c "cd /root/ue-config && srsue ue.conf"
```
## 5. Alta del suscriptor en MongoDB

```bash
docker cp ~/voLTE-lab/subscriber.js mongodb:/subscriber.js
docker exec mongodb mongo /subscriber.js
```

Verificamos que el documento se insertó correctamente:

```bash
docker exec mongodb mongo open5gs --eval "db.subscribers.find().pretty()"
```

**Pendiente:** pegar el output de los tres comandos (especialmente el último), para confirmar que el documento quedó bien formado antes de seguir con la configuración del eNB.

## 6. Corregir tipos de campos del suscriptor (fix_subscriber.js)

```bash
docker cp ~/voLTE-lab/fix_subscriber.js mongodb:/fix_subscriber.js
docker exec mongodb mongo open5gs /fix_subscriber.js
```

El script imprime el documento actualizado al final de la ejecución.

Verificamos que los tipos quedaron corregidos:

```bash
docker exec mongodb mongo open5gs --eval 'db.subscribers.find().forEach(function(doc){ print("typeof sst: " + typeof doc.slice[0].sst); print("typeof qos.index: " + typeof doc.slice[0].session[0].qos.index); })'
```

**Resultado esperado:** tanto `sst` como `qos.index` deberían reportar `number` en lugar de `string`.

## 7. Verificación correcta de tipos (con $unwind)

Para evitar ambigüedad al usar `$type` sobre campos dentro de arrays, primero se "desarman" los arrays con `$unwind`:

```bash
docker exec mongodb mongo open5gs --eval '
db.subscribers.aggregate([
  { $unwind: "$slice" },
  { $unwind: "$slice.session" },
  { $project: {
      imsi: 1,
      sst_type: { $type: "$slice.sst" },
      qos_index_type: { $type: "$slice.session.qos.index" }
  }}
]).forEach(printjson)
'
```

**Resultado obtenido:**

```
{
        "_id" : ObjectId("6a3c77eb55b2d099243fb924"),
        "imsi" : "001010123456789",
        "sst_type" : "int",
        "qos_index_type" : "int"
}
```

Ambos campos quedaron como `int`, confirmando que la corrección de `fix_subscriber.js` se aplicó correctamente.

## 8. Reintentar el attach (eNB + UE)

Con el dato ya corregido en MongoDB, se repite la prueba de attach con las dos terminales.

**Terminal 1 (eNB):**

```bash
docker exec -it srsenb bash -c "cd /root/enb-config && srsenb enb.conf"
```

Esperar a ver `==== eNodeB started ===` y dejarla corriendo.

**Terminal 2 (UE), una vez que el eNB esté arriba:**

```bash
docker exec -it srsue bash -c "cd /root/ue-config && srsue ue.conf"
```

Dejarlo correr 20-30 segundos para darle margen al ciclo completo de attach con autenticación.

**Resultado esperado** (en lugar de `Attach failed`):

```
Network attach successful. IP: 10.45.0.2
```

Si en cambio se sigue viendo `Attach failed`, revisar en paralelo el log fresco del MME:

```bash
docker logs --tail 50 open5gs
```
