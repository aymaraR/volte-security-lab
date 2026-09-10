# ☎️ Investigación: VoLTE — Voice over LTE

## 1. ¿Qué es VoLTE?

LTE fue diseñado desde su origen como una red exclusivamente de conmutación de paquetes, sin un dominio de circuitos para voz como el de GSM/UMTS. Esto planteó a la industria el problema de cómo ofrecer servicio de voz sobre una red LTE pura. La solución estandarizada por el 3GPP y adoptada por la GSMA es **VoLTE (Voice over LTE)**, que transporta la voz como tráfico IP (RTP) sobre un bearer dedicado de LTE, con la señalización de la llamada gestionada por el **IMS (IP Multimedia Subsystem)**.

Antes de VoLTE, los operadores usaban **CSFB (Circuit-Switched Fallback):** cuando entraba una llamada, el dispositivo "caía" a 2G/3G para manejarla. VoLTE elimina eso completamente.

Este documento describe la arquitectura del IMS, el protocolo SIP como base de su señalización, y el ciclo de vida completo de una llamada VoLTE, estableciendo la base conceptual para el análisis de vulnerabilidades.

---

## 2. IMS — IP Multimedia Subsystem

El IMS es un subsistema definido por 3GPP (TS 23.228) para ofrecer servicios multimedia sobre IP, independiente del acceso radio subyacente. Sus elementos centrales son los **CSCF (Call Session Control Function)**:

![Arquitectura VoLTE](../../Imagenes/arquitectura-IMS.png)

### Componentes del IMS

| Nodo | Nombre | Función |
|---|---|---|
| **P-CSCF** | Proxy-CSCF | Primer punto de contacto del UE con el IMS. Recibe toda la señalización SIP del terminal, aplica políticas de seguridad (IPSec/TLS) y reenvía al S-CSCF. |
| **I-CSCF** | Interrogating-CSCF | Consulta al HSS para determinar qué S-CSCF debe atender a un usuario. |
| **S-CSCF** | Serving-CSCF | Núcleo de control de sesión. Autentica al usuario, mantiene el estado del registro, aplica lógica de servicio (routing de llamadas, filtros) y es el elemento más crítico de todo el IMS. |
| **AS** | Application Server | Lógica de servicios: buzón de voz, conferencia, etc. |
| **HSS** | Home Subscriber Server | Base de datos de suscriptores (compartida con EPC). |
| **MGCF** | Media Gateway Control Function | Interconecta el plano de medios IMS con otras redes (PSTN, otros operadores) y gestiona el establecimiento del flujo RTP. |

---

## 3. Protocolos de VoLTE

VoLTE combina tres protocolos clave:

### 3.1 SIP — Session Initiation Protocol
- RFC 3261
- Protocolo de señalización para establecer, modificar y terminar sesiones multimedia.
- Maneja: REGISTER, INVITE, ACK, BYE, CANCEL, etc.
- Funciona sobre UDP o TCP (en IMS generalmente TCP o TLS).

### 3.2 SDP — Session Description Protocol
- RFC 4566
- Describe los parámetros de la sesión multimedia (codec, IP, puerto RTP, etc.).
- Se transporta dentro del cuerpo de los mensajes SIP (INVITE).

### 3.3 RTP / RTCP — Real-time Transport Protocol
- RFC 3550
- Transporta los datos de voz en tiempo real (paquetes de audio codificado).
- RTCP: control y estadísticas de la sesión.
- Codecs comunes en VoLTE: **AMR-WB** (HD Voice), **AMR-NB**, **EVS**.

---

## 4. Flujo de una Llamada VoLTE

```
Llamante (UE-A)                IMS (Kamailio)         Llamado (UE-B)
     |                               |                       |
     |── REGISTER ──────────────────>|                       |
     |<─ 200 OK ─────────────────────|                       |
     |                               |                       |
     |── INVITE (SDP offer) ────────>|                       |
     |                               |── INVITE ────────────>|
     |                               |<─ 180 Ringing ────────|
     |<─ 180 Ringing ────────────────|                       |
     |                               |<─ 200 OK (SDP ans.) ──|
     |<─ 200 OK ─────────────────────|                       |
     |── ACK ─────────────────────── |──────────────────────>|
     |                               |                       |
     |══════════ RTP (voz) ══════════════════════════════════|
     |                               |                       |
     |── BYE ─────────────────────── |──────────────────────>|
     |<─ 200 OK ─────────────────────|───────────────────────|
```

---

## 5. QoS en VoLTE — Bearers y QCI

LTE usa el concepto de **bearers** (portadoras) para garantizar calidad de servicio. VoLTE requiere bearers dedicados:

| Bearer | QCI | Uso | Características |
|---|---|---|---|
| Default bearer | 9 | Datos generales | Best effort |
| Dedicated bearer | 1 | RTP (voz VoLTE) | GBR, baja latencia, alta prioridad |
| Dedicated bearer | 5 | SIP (señalización IMS) | Non-GBR, alta prioridad |

- **QCI 1:** Garantiza latencia < 100 ms y pérdida de paquetes < 0.01% para voz.
- **GBR (Guaranteed Bit Rate):** La red reserva ancho de banda para el bearer de voz.

---

## 6. Seguridad en VoLTE

### 6.1 Señalización SIP
- **IPSec ESP:** entre UE y P-CSCF (obligatorio en IMS). Protege la señalización SIP en la capa de transporte.
- **TLS:** alternativa para señalización SIP.

### 6.2 Medios RTP
- **SRTP (Secure RTP):** RFC 3711. Cifra el flujo de audio.
- **SDES (SDP Security Descriptions):** intercambio de claves SRTP mediante SDP. Vulnerable a ataques MITM si no hay TLS/IPSec en la señalización.
- **DTLS-SRTP:** alternativa más robusta (usado en WebRTC).

### 6.3 Vulnerabilidades documentadas

| Vulnerabilidad | Descripción |
|---|---|
| **SRTP con SDES sin TLS** | Las claves de cifrado RTP viajan en SDP en texto claro si no hay TLS/IPSec. |
| **Falta de SRTP** | Algunas implementaciones IMS no habilitan SRTP, dejando el audio en texto claro (RTP plano). |
| **SIP INVITE sin autenticación** | En entornos mal configurados, se puede generar sesiones sin autenticarse. |
| **RTP injection** | Sin SRTP/SRTCP, un atacante en la red puede inyectar paquetes de audio. |
| **RTCP hijacking** | RTCP no cifrado puede revelar metadatos y estadísticas de la llamada. |

---

## 7. Diferencias entre VoLTE y VoIP convencional

| Aspecto | VoIP (ej. SIP genérico) | VoLTE (IMS) |
|---|---|---|
| Red de transporte | Internet pública | Red LTE gestionada |
| QoS | Best effort | Bearers dedicados con QCI |
| Seguridad | Opcional | IPSec/TLS obligatorio (estándar) |
| Registro | Servidor SIP libre | HSS del operador |
| Codecs | Variado | AMR-WB / EVS (estandarizados) |
| Emergencias | Variable | Soporte E911/E112 integrado |

---

## 8. Referencias

- GSMA IR.92 — IMS Profile for Voice and SMS
- 3GPP TS 23.228 — IP Multimedia Subsystem (IMS); Stage 2
- 3GPP TS 24.229 — IP multimedia call control protocol based on SIP and SDP
- 3GPP TS 33.203 — 3G Security; Access security for IP-based services.
- RFC 3261 — SIP: Session Initiation Protocol
- RFC 3550 — RTP: A Transport Protocol for Real-Time Applications
- RFC 3711 — The Secure Real-time Transport Protocol (SRTP)
- RFC 3325 — Private Extensions to SIP for Asserted Identity.
- RFC 5630 — The Use of the SDES Key Management Method with SIP.


---

**Siguiente documento:** [`03_vectores_ataque.md`](03_vectores_ataque.md) — Superficie de ataque y vulnerabilidades.
