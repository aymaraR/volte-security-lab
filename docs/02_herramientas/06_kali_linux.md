# 🐉 Herramienta: Kali Linux

## 1. ¿Qué es Kali Linux?

**Kali Linux** es una distribución GNU/Linux basada en Debian, mantenida por **Offensive Security**, diseñada específicamente para pruebas de penetración, auditorías de seguridad e investigación forense. Viene preinstalada con más de 600 herramientas de seguridad organizadas por categorías.

- **Licencia:** Distribución libre (herramientas con licencias individuales)
- **Sitio oficial:** https://www.kali.org
- **Base:** Debian Testing
- **Imagen Docker:** `kalilinux/kali-rolling`

---

## 2. Rol en el Laboratorio

El contenedor de Kali representa la **máquina atacante** dentro de la red IMS. Desde aquí se ejecutan las herramientas de captura, análisis e interceptación de tráfico SIP/RTP.

```
Red IMS (172.21.0.0/24)
┌─────────────────────────────────────────┐
│  Kamailio (172.21.0.10)                 │
│  Asterisk  (172.21.0.20)                │
│  Kali      (172.21.0.99) ← ATACANTE    │
└─────────────────────────────────────────┘
```

---

## 3. Herramientas Relevantes para VoLTE

### 3.1 Captura y Análisis de Red

| Herramienta | Uso en el laboratorio |
|---|---|
| **Wireshark** | Captura y análisis visual de SIP/RTP (ver doc 07) |
| **tshark** | Versión CLI de Wireshark para captura automatizada |
| **tcpdump** | Captura raw de paquetes |
| **ngrep** | Búsqueda de patrones en tráfico de red |

### 3.2 Herramientas SIP

| Herramienta | Descripción |
|---|---|
| **sipgrep** | Captura y filtra mensajes SIP en tiempo real |
| **sipsak** | Herramienta de diagnóstico SIP (OPTIONS, REGISTER) |
| **SIPp** | Generador de tráfico SIP para pruebas de carga |
| **sngrep** | Visualizador interactivo de diálogos SIP en terminal |

### 3.3 Análisis de RTP / Audio

| Herramienta | Descripción |
|---|---|
| **rtpdump** | Captura y reproduce flujos RTP |
| **rtpbreak** | Detecta y extrae flujos RTP de una captura |
| **sox** | Procesamiento y conversión de archivos de audio |
| **ffmpeg** | Conversión de audio/video (de .pcap a .wav) |

---

## 4. Instalación de Herramientas en el Contenedor

El contenedor de Kali rolling no incluye todas las herramientas por defecto. Instalarlas al iniciar:

```bash
# Actualizar repositorios
apt update

# Herramientas de red y SIP
apt install -y wireshark tshark tcpdump ngrep sipgrep sipsak sngrep

# Herramientas de audio/RTP
apt install -y rtpdump sox ffmpeg

# Herramientas generales útiles
apt install -y net-tools iputils-ping curl wget python3 python3-pip vim
```

O bien, construir una imagen personalizada con un `Dockerfile`:

```dockerfile
FROM kalilinux/kali-rolling

RUN apt update && apt install -y \
    wireshark tshark tcpdump \
    sipgrep sipsak sngrep \
    sox ffmpeg rtpdump \
    net-tools iputils-ping curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /captures
CMD ["/bin/bash"]
```

---

## 5. Configuración en Docker Compose

```yaml
services:
  kali:
    build:
      context: ./docker/kali
      dockerfile: Dockerfile
    container_name: kali-attacker
    hostname: attacker
    cap_add:
      - NET_ADMIN          # Para manipular interfaces de red
      - NET_RAW            # Para captura raw (tcpdump, wireshark)
    volumes:
      - ./captures:/captures   # Carpeta para guardar .pcap
    stdin_open: true
    tty: true
    networks:
      ims-net:
        ipv4_address: 172.21.0.99
```

---

## 6. Flujo de Ataque en el Laboratorio

### Paso 1 — Verificar conectividad desde Kali

```bash
# Verificar que Kali ve a Kamailio y Asterisk
ping 172.21.0.10   # Kamailio
ping 172.21.0.20   # Asterisk
```

### Paso 2 — Capturar tráfico SIP con sngrep

```bash
# Visualizador interactivo de diálogos SIP
sngrep -I eth0 port 5060
```

### Paso 3 — Capturar tráfico completo con tshark

```bash
# Capturar todo el tráfico de la red IMS
tshark -i eth0 -w /captures/volte_capture.pcap

# Solo SIP y RTP
tshark -i eth0 -f "udp port 5060 or (udp portrange 10000-20000)" \
       -w /captures/sip_rtp.pcap
```

### Paso 4 — Extraer audio RTP con tshark

```bash
# Listar flujos RTP en la captura
tshark -r /captures/volte_capture.pcap \
       -Y "rtp" -T fields \
       -e rtp.ssrc -e ip.src -e ip.dst -e udp.srcport

# Exportar audio directamente (Wireshark GUI → Telephony → RTP Streams)
```

### Paso 5 — Convertir RTP a WAV

```bash
# Extraer payload RTP y convertir con sox
# (requiere conocer el codec: PCMU=0, PCMA=8, AMR, etc.)
rtpdump -F payload -t 0 /captures/volte_capture.pcap \
        172.21.0.20/10000 > audio.raw

sox -t raw -r 8000 -e a-law -c 1 audio.raw audio.wav
```

---

## 7. sngrep — Vista de Diálogos SIP

`sngrep` es especialmente útil para ver el flujo completo de una llamada en la terminal:

```
 ┌──────────────────────────────────────────────────────────────┐
 │  172.21.0.50        172.21.0.10        172.21.0.20           │
 │  (srsUE)            (Kamailio)         (Asterisk)            │
 │      │                   │                   │               │
 │      │──── REGISTER ────>│                   │               │
 │      │<─── 200 OK ───────│                   │               │
 │      │──── INVITE ──────>│──── INVITE ──────>│               │
 │      │<─── 180 Ringing ──│<─── 180 Ringing ──│               │
 │      │<─── 200 OK ───────│<─── 200 OK ────── │               │
 │      │──── ACK ─────────>│──── ACK ─────────>│               │
 │      │═══════════════ RTP (voz) ═════════════│               │
 └──────────────────────────────────────────────────────────────┘
```

---

## 8. Recursos

- Kali Linux Tools: https://www.kali.org/tools/
- sngrep GitHub: https://github.com/irontec/sngrep
- SIPp: https://sipp.sourceforge.net/
- rtpdump: http://www.cs.columbia.edu/irt/software/rtptools/
