# 👁️ Herramienta: Wireshark

## 1. ¿Qué es Wireshark?

**Wireshark** es el analizador de protocolos de red más utilizado en el mundo. Permite capturar y examinar en tiempo real el contenido de los paquetes que circulan por una red, con soporte para cientos de protocolos incluidos SIP, RTP, GTP, Diameter y todos los relevantes para LTE/VoLTE.

- **Licencia:** GPLv2
- **Sitio oficial:** https://www.wireshark.org
- **CLI:** `tshark` (mismas capacidades sin interfaz gráfica)
- **Lenguaje:** C

---

## 2. Rol en el Laboratorio

Wireshark es el **"ojo visor"** del laboratorio. Permite:

1. **Ver en tiempo real** los mensajes SIP de señalización (REGISTER, INVITE, BYE).
2. **Reconstruir el flujo completo** de una llamada VoLTE (diagrama de secuencia SIP).
3. **Reproducir el audio** capturado de los flujos RTP si no hay cifrado SRTP.
4. **Analizar encabezados GTP** para ver el tráfico tunnelado entre eNB y SGW.

---

## 3. Filtros Esenciales para VoLTE

### 3.1 Filtros de Captura (BPF — Berkeley Packet Filter)
Se aplican antes de capturar, en la interfaz. Reducen el volumen de datos.

```bash
# Solo SIP (señalización)
udp port 5060 or tcp port 5060

# Solo RTP (audio) — rango de puertos de Asterisk
udp portrange 10000-20000

# SIP + RTP combinado
udp port 5060 or udp portrange 10000-20000

# Todo el tráfico de un host específico
host 172.21.0.20
```

### 3.2 Filtros de Visualización (Display Filters)
Se aplican después de capturar, para filtrar lo que se muestra.

```wireshark
# Solo paquetes SIP
sip

# Solo paquetes RTP
rtp

# INVITE de VoLTE
sip.Method == "INVITE"

# Respuestas de error SIP (4xx, 5xx)
sip.Status-Code >= 400

# RTP de un SSRC específico
rtp.ssrc == 0x12345678

# Tráfico GTP (túneles LTE)
gtp

# Diameter (autenticación HSS/MME)
diameter

# S1AP (señalización eNB ↔ MME)
s1ap

# Combinar SIP y RTP
sip or rtp

# Tráfico entre dos IPs específicas
ip.addr == 172.21.0.10 and ip.addr == 172.21.0.20
```

---

## 4. Análisis de Llamadas VoLTE — Paso a Paso

### 4.1 Capturar en la interfaz correcta

Desde el contenedor Kali, capturar en la interfaz de red de la red IMS:

```bash
# Identificar interfaz
ip addr show

# Capturar con tshark en segundo plano
tshark -i eth0 -w /captures/llamada.pcap &

# ... realizar la llamada VoLTE ...

# Detener captura
kill %1
```

### 4.2 Abrir en Wireshark y reconstruir la llamada

1. Abrir `llamada.pcap` en Wireshark.
2. Ir a **Telephony → SIP Flows** (o **VoIP Calls**).
3. Wireshark muestra el diagrama de secuencia completo de la llamada.
4. Seleccionar la llamada → **Flow Sequence** para ver todos los mensajes.

### 4.3 Reproducir el audio RTP

1. **Telephony → RTP → RTP Streams**
2. Seleccionar los flujos de audio (habrá dos: A→B y B→A).
3. Click en **Analyze** → **Play Streams**.
4. Wireshark decodifica el codec (PCMU, PCMA, AMR) y reproduce el audio.

> ⚠️ Esto solo funciona si el RTP **no está cifrado con SRTP**. En el laboratorio, la configuración de Asterisk deliberadamente deja SRTP deshabilitado para demostrar la vulnerabilidad.

---

## 5. Exportar Audio desde tshark (CLI)

```bash
# Ver todos los flujos RTP en la captura
tshark -r llamada.pcap -Y "rtp" -T fields \
  -e frame.number -e ip.src -e udp.srcport \
  -e ip.dst -e udp.dstport -e rtp.ssrc \
  -e rtp.payload_type | sort -u

# Extraer payload de un flujo RTP específico (SSRC conocido)
tshark -r llamada.pcap \
  -Y "rtp and rtp.ssrc==0xABCD1234" \
  -T fields -e rtp.payload | \
  tr -d '\n' | xxd -r -p > audio_raw.bin

# Convertir a WAV con sox (codec G.711 µ-law = PCMU)
sox -t raw -r 8000 -e mu-law -c 1 audio_raw.bin audio_output.wav

# Reproducir
aplay audio_output.wav
```

---

## 6. Análisis de GTP (Túneles LTE)

Para ver el tráfico que viaja dentro del túnel GTP entre eNB y SGW:

```wireshark
# Ver tráfico GTP
gtp

# Ver el contenido del túnel (decapsulado)
gtp and ip
```

Wireshark decapsula automáticamente el GTP y muestra el tráfico IP del UE que va dentro del túnel.

---

## 7. Coloreado de Protocolos Útil

Wireshark usa colores para identificar protocolos. Para VoLTE conviene crear reglas de color personalizadas en **View → Coloring Rules**:

| Color | Filtro | Protocolo |
|---|---|---|
| Verde claro | `sip` | Señalización SIP |
| Azul | `rtp` | Audio RTP |
| Amarillo | `gtp` | Túneles GTP-U |
| Naranja | `diameter` | Autenticación |
| Rojo | `s1ap` | Señalización S1 |

---

## 8. Uso desde Docker (modo headless)

En el laboratorio, se usa `tshark` (CLI) para capturar dentro del contenedor Kali. La GUI de Wireshark se ejecuta en el **host** abriendo el archivo `.pcap` generado:

```bash
# En el contenedor Kali: capturar
tshark -i eth0 -w /captures/llamada.pcap

# En el host: abrir la captura con GUI
wireshark /ruta/local/captures/llamada.pcap
```

Alternativamente, usar **X11 forwarding** o **Wireshark remoto** si el host tiene entorno gráfico.

---

## 9. Recursos

- Documentación oficial: https://www.wireshark.org/docs/
- Wiki de filtros: https://wiki.wireshark.org/DisplayFilters
- Guía VoIP/VoLTE en Wireshark: https://wiki.wireshark.org/VoIP_calls
- tshark man page: https://www.wireshark.org/docs/man-pages/tshark.html
