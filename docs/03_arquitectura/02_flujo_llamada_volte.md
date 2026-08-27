# 📞 Flujo Completo de una Llamada VoLTE en el Laboratorio

## 1. Visión General

Una llamada VoLTE involucra **tres fases principales** y cruza múltiples capas de la red:

```
Fase 1: REGISTRO IMS    → El UE se registra en el servidor SIP (Kamailio)
Fase 2: ESTABLECIMIENTO → Negociación SIP (INVITE / 200 OK / ACK)
Fase 3: CONVERSACIÓN    → Flujo de audio RTP entre UE y Asterisk
Fase 4: TERMINACIÓN     → BYE / 200 OK
```

---

## 2. Prerrequisito: Attach LTE (antes de la llamada)

Antes de cualquier llamada VoLTE, el UE debe haberse **adjuntado a la red LTE** y tener asignada una IP.

```
srsUE          srsENB         Open5GS MME       Open5GS HSS
  │                │                │                 │
  │──Attach Req───>│                │                 │
  │                │──S1AP: InitUE──>│                 │
  │                │                │──Diameter Auth──>│
  │                │                │<─Auth Vectors────│
  │                │<──Auth Req─────│                 │
  │<──Auth Req─────│                │                 │
  │──Auth Resp────>│                │                 │
  │                │──Auth Resp────>│                 │
  │<──Security─────│<───SecMode Cmd─│                 │
  │──SecMode Cmp──>│───SecMode Cmp──>│                 │
  │                │                │──Create Session──> SGW/PGW
  │                │                │<──Session Created─┘
  │<──Attach Accept (IP: 10.45.0.X)─────────────────────
  │──Attach Complete────────────────────────────────────>
  │                                                     │
  ▼  UE conectado, interfaz tun_srsue activa            │
```

---

## 3. Fase 1 — Registro IMS (SIP REGISTER)

Una vez con IP LTE asignada, el UE registra su identidad en el servidor IMS.

```
srsUE (10.45.0.X)          Kamailio (172.21.0.10)      Asterisk (172.21.0.20)
        │                          │                           │
        │──── REGISTER ──────────>│                           │
        │     From: sip:1001@ims  │                           │
        │     Contact: 10.45.0.X  │                           │
        │     Expires: 3600       │                           │
        │                         │                           │
        │<─── 401 Unauthorized ───│  (Digest challenge)       │
        │     WWW-Authenticate:   │                           │
        │     realm, nonce        │                           │
        │                         │                           │
        │──── REGISTER ──────────>│  (con credenciales)       │
        │     Authorization:      │                           │
        │     Digest response     │                           │
        │                         │──── Notifica registro ───>│
        │<─── 200 OK ─────────────│                           │
        │     Contact registrado  │                           │
        ▼                         │                           │
   UE registrado en IMS           │                           │
```

---

## 4. Fase 2 — Establecimiento de la Llamada (SIP INVITE)

```
srsUE-A (llamante)    Kamailio            Asterisk         srsUE-B (llamado)
        │                 │                   │                   │
        │── INVITE ──────>│                   │                   │
        │  To: sip:1002   │                   │                   │
        │  SDP offer:     │                   │                   │
        │   m=audio 5004  │                   │                   │
        │   a=rtpmap AMR  │                   │                   │
        │                 │── INVITE ────────>│                   │
        │                 │                   │── INVITE ────────>│
        │                 │                   │<── 180 Ringing ───│
        │                 │<── 180 Ringing ───│                   │
        │<── 180 Ringing ─│                   │                   │
        │                 │                   │<── 200 OK ────────│
        │                 │                   │   SDP answer:     │
        │                 │                   │   m=audio 5006    │
        │                 │<── 200 OK ────────│                   │
        │<── 200 OK ──────│                   │                   │
        │   SDP answer:   │                   │                   │
        │   m=audio 10500 │ ← IP de Asterisk  │                   │
        │   (Asterisk IP) │                   │                   │
        │                 │                   │                   │
        │── ACK ─────────>│── ACK ───────────>│── ACK ───────────>│
        │                 │                   │                   │
```

### Detalle del SDP Offer/Answer

**SDP Offer (del UE llamante, en el INVITE):**
```
v=0
o=- 123456 654321 IN IP4 10.45.0.2
s=VoLTE Call
c=IN IP4 10.45.0.2
t=0 0
m=audio 5004 RTP/AVP 0 8 96
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:96 AMR-WB/16000
a=ptime:20
```

**SDP Answer (de Asterisk, en el 200 OK):**
```
v=0
o=- 789012 210987 IN IP4 172.21.0.20
s=Asterisk
c=IN IP4 172.21.0.20
t=0 0
m=audio 10500 RTP/AVP 0
a=rtpmap:0 PCMU/8000
a=ptime:20
```

---

## 5. Fase 3 — Conversación (Flujo RTP)

Una vez establecida la sesión con el ACK, comienza el flujo de audio:

```
srsUE-A                   Asterisk (172.21.0.20)              srsUE-B
  │                              │                               │
  │═══ RTP (SSRC=0xAAA) ════════>│  puerto 10500 ← UE-A         │
  │   payload: PCMU/AMR          │                               │
  │   seq: 1,2,3,4...            │                               │
  │                              │══ RTP (SSRC=0xBBB) ══════════>│
  │                              │  puerto 5006 ← Asterisk       │
  │<══ RTP (SSRC=0xCCC) ═════════│  puerto 10502 ← UE-B          │
  │   (audio de UE-B             │                               │
  │    procesado por Asterisk)   │<══ RTP (SSRC=0xDDD) ══════════│
  │                              │                               │
```

### Kali captura el RTP en este punto

```
Kali (172.21.0.99) escucha en la red ims-net
  │
  │ tshark -i eth0 -Y "rtp" -w /captures/llamada.pcap
  │
  └─ Captura los flujos RTP de/hacia Asterisk
     SSRC 0xAAA: audio del UE-A
     SSRC 0xCCC: audio del UE-B (mezclado por Asterisk)
```

---

## 6. Fase 4 — Terminación de la Llamada (BYE)

```
srsUE-A               Kamailio             Asterisk           srsUE-B
   │                      │                    │                  │
   │ (cuelga el teléfono) │                    │                  │
   │── BYE ──────────────>│── BYE ────────────>│                  │
   │                      │                    │── BYE ──────────>│
   │                      │                    │<── 200 OK ───────│
   │                      │<── 200 OK ─────────│                  │
   │<── 200 OK ───────────│                    │                  │
   │                      │                    │                  │
   ▼  Canal RTP cerrado   │                    │                  │
```

---

## 7. Resumen de Puertos en el Laboratorio

| Protocolo | Origen | Destino | Puerto | Descripción |
|---|---|---|---|---|
| SIP | srsUE | Kamailio | 5060/UDP | REGISTER, INVITE |
| SIP | Kamailio | Asterisk | 5060/UDP | INVITE enrutado |
| RTP | srsUE-A | Asterisk | 10500/UDP | Audio UE-A → Asterisk |
| RTP | Asterisk | srsUE-A | 5004/UDP | Audio UE-B → UE-A |
| RTP | srsUE-B | Asterisk | 10502/UDP | Audio UE-B → Asterisk |
| RTP | Asterisk | srsUE-B | 5006/UDP | Audio UE-A → UE-B |
| S1AP | srsENB | MME | 36412/SCTP | Señalización LTE |
| GTP-U | srsENB | SGW | 2152/UDP | Plano usuario LTE |

---

## 8. Punto Crítico: ¿Por Qué es Posible la Interceptación?

```
┌─────────────────────────────────────────────────────┐
│  CAUSA RAÍZ: RTP no cifrado (sin SRTP)              │
│                                                     │
│  El audio viaja como RTP plano (G.711/AMR en claro) │
│  entre el UE y Asterisk sobre la red IMS Docker.    │
│                                                     │
│  Kali, al estar en la misma red (ims-net), puede    │
│  capturar estos paquetes y reconstruir el audio.    │
│                                                     │
│  En una red real con SRTP + TLS, el atacante vería  │
│  solo ruido cifrado, sin posibilidad de escuchar.   │
└─────────────────────────────────────────────────────┘
```

---

## 9. Herramienta de Verificación del Flujo

Para visualizar el flujo completo de la llamada en tiempo real desde Kali:

```bash
# sngrep — visualizador interactivo de diálogos SIP
sngrep -I eth0 -f "port 5060"

# Al presionar Enter sobre una llamada, muestra:
# - Todos los mensajes SIP con timestamps
# - El contenido SDP con IPs y puertos RTP
# - Estadísticas de la sesión
```
