# 📶 Herramienta: srsRAN 4G

## 1. ¿Qué es srsRAN 4G?

**srsRAN 4G** (anteriormente srsLTE) es un conjunto de software de código abierto desarrollado por **SRS (Software Radio Systems)** que implementa una pila LTE completa en software. Permite emular tanto el lado del dispositivo (UE) como el de la antena (eNB).

- **Licencia:** AGPLv3
- **Repositorio:** https://github.com/srsran/srsRAN_4G
- **Lenguaje:** C++

---

## 2. Componentes

| Componente | Binario | Función |
|---|---|---|
| **srsUE** | `srsue` | Emula un teléfono móvil (User Equipment) |
| **srsENB** | `srsenb` | Emula una antena base LTE (eNodeB) |
| **srsEPC** | `srsepc` | EPC simplificado (solo para pruebas básicas) |

> En este proyecto usamos **srsUE + srsENB** y conectamos al EPC de **Open5GS** (más completo).

---

## 3. Arquitectura en el Laboratorio

```
[ srsUE (contenedor) ] ──(ZeroMQ RF)──> [ srsENB (contenedor) ]
                                                 |
                                           S1-MME / S1-U
                                                 |
                                         [ Open5GS EPC ]
```

**ZeroMQ RF:** srsRAN puede simular el canal de radio sobre ZeroMQ en lugar de usar hardware SDR real. Esto es clave para nuestro laboratorio virtual — no se emite señal de radio.

---

## 4. Configuración clave — srsUE

Archivo: `ue.conf`

```ini
[rf]
freq_offset = 0
tx_gain = 80
rx_gain = 40
device_name = zmq                        # Usar ZeroMQ (sin hardware)
device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6

[rat.eutra]
dl_earfcn = 2850                         # EARFCN de la banda a conectar

[usim]
mode = soft
algo = milenage
opc  = 63BFA50EE6523365FF14C1F45F88737D   # Debe coincidir con Open5GS HSS
k    = 00112233445566778899AABBCCDDEEFF
imsi = 001010123456780                    # IMSI registrado en Open5GS
imei = 353490069873319

[rrc]
release      = 15
ue_category  = 4

[nas]
apn = internet
apn_protocol = ipv4

[pcap]
enable   = false
filename = /tmp/ue.pcap
nas_enable   = false
nas_filename = /tmp/nas.pcap
```

---

## 5. Configuración clave — srsENB

Archivo: `enb.conf`

```ini
[enb]
enb_id = 0x19B
mcc = 001
mnc = 01
mme_addr = 172.20.0.10        # IP del MME de Open5GS
gtp_bind_addr = 172.20.0.2    # IP del eNB para GTP-U
s1c_bind_addr = 172.20.0.2    # IP del eNB para S1AP

[rf]
dl_earfcn = 2850
tx_gain = 80
rx_gain = 40
device_name = zmq
device_args = fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6

[scheduler]
pdsch_mcs = -1
pusch_mcs = -1
```

---

## 6. Instalación (desde fuente)

```bash
# Dependencias en Ubuntu 22.04
sudo apt install -y build-essential cmake libfftw3-dev libmbedtls-dev \
  libboost-program-options-dev libconfig++-dev libsctp-dev libzmq3-dev

# Clonar y compilar
git clone https://github.com/srsran/srsRAN_4G.git
cd srsRAN_4G
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

---

## 7. Verificación de Conectividad

Una vez levantado el laboratorio, el UE debería:
1. Completar el **Attach** con el MME.
2. Recibir una IP en la interfaz `tun_srsue`.
3. Poder hacer ping a través de la red.

```bash
# Dentro del contenedor srsUE, verificar interfaz TUN
ip addr show tun_srsue

# Verificar conectividad
ping -I tun_srsue 8.8.8.8
```

---

## 8. Recursos

- Documentación oficial: https://docs.srsran.com/projects/4g
- Guía de lab con ZeroMQ: https://docs.srsran.com/projects/4g/en/latest/app_notes/source/zeromq/source/index.html
- GitHub: https://github.com/srsran/srsRAN_4G
