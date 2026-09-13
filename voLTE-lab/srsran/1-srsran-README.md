# srsRAN 4G con ZMQ

srsRAN es un stack de radio LTE open source. En este laboratorio se usa la versión 4G con el backend ZMQ, que reemplaza el hardware SDR por una radio virtual sobre sockets. Esto permite simular tanto el eNodeB (antena) como el UE (dispositivo) sin ningún equipo físico.

## Por que srsRAN 4G y no 5G

El stack VoLTE con IMS corre sobre LTE/4G. srsRAN 4G tiene soporte maduro para ZMQ y es compatible con Open5GS como EPC.

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
