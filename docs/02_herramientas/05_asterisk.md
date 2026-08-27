# 🔊 Herramienta: Asterisk

## 1. ¿Qué es Asterisk?

**Asterisk** es un framework de código abierto para construir aplicaciones de comunicaciones. En el contexto de este laboratorio, actúa como el **Application Server (AS)** y **Media Gateway** del IMS, siendo responsable de gestionar el audio (RTP) de las llamadas VoLTE.

- **Licencia:** GPLv2
- **Repositorio:** https://github.com/asterisk/asterisk
- **Lenguaje:** C
- **Desarrollador:** Sangoma Technologies (anteriormente Digium)

---

## 2. Rol en el Laboratorio

```
[ Kamailio (señalización SIP) ]
            |
     SIP INVITE / BYE
            |
     [ Asterisk (B2BUA) ]
            |
     RTP (audio en claro)
            |
  [ flujo interceptable por Wireshark ]
```

Asterisk actúa como **B2BUA (Back-to-Back User Agent):** termina la sesión SIP de un lado y crea una nueva sesión hacia el otro extremo. Esto centraliza todo el tráfico RTP a través de Asterisk, facilitando la captura.

---

## 3. Componentes Clave de Configuración

| Archivo | Función |
|---|---|
| `sip.conf` / `pjsip.conf` | Configuración de usuarios y trunks SIP |
| `extensions.conf` | Dialplan — lógica de enrutamiento de llamadas |
| `rtp.conf` | Configuración de puertos RTP |
| `modules.conf` | Módulos a cargar al iniciar |
| `logger.conf` | Configuración de logs |

---

## 4. Configuración — pjsip.conf (stack SIP moderno)

```ini
; pjsip.conf — configuración para laboratorio VoLTE

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

; ---- Definición de usuarios (UE virtuales) ----

[1001]
type=endpoint
context=llamadas
disallow=all
allow=ulaw
allow=alaw
allow=amr                   ; AMR-NB para VoLTE
allow=amrwb                 ; AMR-WB (HD Voice)
aors=1001
auth=auth1001
rtp_symmetric=yes
force_rport=yes
direct_media=no             ; Forzar que el RTP pase por Asterisk (clave para captura)

[auth1001]
type=auth
auth_type=userpass
username=1001
password=test1001

[aors1001]
type=aor
max_contacts=1
remove_existing=yes

; Segundo usuario
[1002]
type=endpoint
context=llamadas
disallow=all
allow=ulaw
allow=amrwb
aors=aors1002
auth=auth1002
direct_media=no

[auth1002]
type=auth
auth_type=userpass
username=1002
password=test1002

[aors1002]
type=aor
max_contacts=1
```

---

## 5. Configuración — extensions.conf (Dialplan)

```ini
; extensions.conf — enrutamiento de llamadas

[general]
static=yes
writeprotect=no

[llamadas]
; Llamada de 1001 a 1002
exten => 1002,1,NoOp(Llamada entrante de ${CALLERID(num)} hacia ${EXTEN})
exten => 1002,n,Dial(PJSIP/1002,30)
exten => 1002,n,Hangup()

; Llamada de 1002 a 1001
exten => 1001,1,NoOp(Llamada entrante de ${CALLERID(num)} hacia ${EXTEN})
exten => 1001,n,Dial(PJSIP/1001,30)
exten => 1001,n,Hangup()

; Extensión de prueba — reproduce audio de bienvenida
exten => 9999,1,Answer()
exten => 9999,n,Playback(demo-congrats)
exten => 9999,n,Hangup()
```

---

## 6. Configuración — rtp.conf

```ini
; rtp.conf — rango de puertos RTP
[general]
rtpstart=10000
rtpend=20000
icesupport=no       ; Deshabilitar ICE (simplifica captura en laboratorio)
strictrtp=no
```

---

## 7. Instalación con Docker

```yaml
services:
  asterisk:
    image: andrius/asterisk:latest
    container_name: asterisk
    volumes:
      - ./config/asterisk:/etc/asterisk
    ports:
      - "5060:5060/udp"   # SIP (si no usa Kamailio como proxy)
      - "10000-10100:10000-10100/udp"  # RTP
    cap_add:
      - NET_ADMIN
    networks:
      ims-net:
        ipv4_address: 172.21.0.20
```

---

## 8. Comandos de Diagnóstico (CLI de Asterisk)

```bash
# Entrar a la consola de Asterisk
asterisk -rvvv

# Ver endpoints SIP registrados
pjsip show endpoints

# Ver canales activos (llamadas en curso)
core show channels

# Ver canales con detalle RTP
core show channel <channel-id>

# Activar verbose máximo para debug SIP
pjsip set logger on

# Ver llamadas activas con info RTP
rtp show channels
```

---

## 9. RTP y la Captura

El parámetro crítico para el laboratorio es `direct_media=no` en pjsip.conf. Esto **fuerza que todo el audio RTP pase a través de Asterisk**, en lugar de ir directamente entre los UEs. Sin esto, Asterisk instruye a los UEs a intercambiar RTP directamente (media bypass) y Wireshark no vería el audio desde el segmento del atacante.

```
Con direct_media=yes (bypass):
  UE-A ══════(RTP directo)══════> UE-B   ← Asterisk no ve el audio

Con direct_media=no (forzado):
  UE-A ──RTP──> Asterisk ──RTP──> UE-B   ← Todo el audio pasa por Asterisk ✓
```

---

## 10. Recursos

- Documentación oficial: https://docs.asterisk.org
- Wiki PJSIP: https://wiki.asterisk.org/wiki/display/AST/PJSIP
- GitHub: https://github.com/asterisk/asterisk
