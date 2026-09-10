# ⚔️ Investigación: Vectores de Ataque en Redes 4G LTE / VoLTE

> ⚠️ **Propósito estrictamente académico.** Esta documentación analiza vulnerabilidades conocidas y publicadas en la literatura de seguridad. No se provee código malicioso ni instrucciones de ataque sobre redes reales.

---

## 1. Superficie de Ataque en LTE/VoLTE

```
[ UE ] ──(LTE-Uu)──> [ eNB ] ──(S1)──> [ EPC ] ──(Gi/SGi)──> [ IMS ]
   ↑                    ↑                   ↑                      ↑
 IMSI              Rogue eNB            Core falso           SIP/RTP
 Catching           / MITM              (SS7-like)           intercept
```

| Capa | Elemento | Amenazas principales |
|---|---|---|
| Radio (Uu) | eNodeB / UE | Cifrado nulo o débil (EEA0), rogue eNodeB, jamming (fuera de alcance del laboratorio) |
| Core (EPC) | MME/SGW/PGW | Manipulación de bearers, exhaustion de recursos, ataques a interfaces Diameter |
| Señalización (IMS/SIP) | P/I/S-CSCF | Interceptación (MITM), DoS por inundación, suplantación de identidad |
| Transporte de voz (RTP) | Media plane | Interceptación de audio, inyección de paquetes RTP, secuestro de sesión |

---

## 2. Ataques en la Capa Radio (LTE-Uu)

### 2.1 IMSI Catching (Stingray / IMSI Catcher)
- **Descripción:** Un atacante despliega una estación base falsa (rogue eNB) que imita una red legítima. Los UEs se conectan a ella y revelan su IMSI antes del cifrado.
- **Causa:** El UE envía el IMSI en texto claro en el primer `Attach Request` cuando no tiene TMSI asignado, o cuando la red falsa lo solicita.
- **Impacto:** Identificación y seguimiento de usuarios.
- **Mitigación:** SUPI/SUCI en 5G cifra el identificador con la clave pública del operador (LTE no tiene esto).

### 2.2 Ataques de Downgrade
- **Descripción:** Forzar al UE a caer a 2G (GSM) donde el cifrado A5/1 es rompible o puede deshabilitarse.
- **Método:** La rogue eNB rechaza la conexión LTE, el UE busca red 3G/2G.
- **Impacto:** Intercepción de llamadas en redes legacy.

### 2.3 Denegación de Servicio (DoS) en Capa Radio
- **Descripción:** Jamming de la banda de frecuencias LTE, o bombardeo de mensajes de señalización.
- **Impacto:** Interrupción del servicio para usuarios en el área.

---

## 3. Ataques en el Plano de Usuario (User Plane)

### 3.1 LTE UP Sniffing (sin cifrado UP)
- **Descripción:** 3GPP no obliga el cifrado del plano de usuario entre eNB y UE. Si el operador no lo habilita (EEA0), el tráfico viaja en texto claro.
- **Impacto:** Lectura de datos HTTP, metadatos, contenido sin cifrar.

### 3.2 aLTEr Attack (2019 — Raza et al.)
- **Descripción:** Ataque de redirección DNS aprovechando la falta de protección de integridad en el plano de usuario LTE.
- **Método:** El atacante modifica paquetes IP en el túnel GTP-U (bit flipping en AES-CTR sin MAC).
- **Impacto:** Redirige tráfico HTTP a servidores maliciosos.
- **Referencia:** *"Breaking LTE on Layer Two"*, S&P 2019.

---

## 4. Ataques sobre VoLTE / IMS

### 4.1 Interceptación de RTP (sin SRTP)
- **Descripción:** Si el servidor IMS no negocia SRTP y los paquetes RTP circulan en claro dentro de la red del operador, un atacante con acceso al segmento de red puede capturarlos.
- **Herramienta típica:** Wireshark → "Telephony → RTP Streams → Play".
- **Condición:** El atacante debe estar en el path de red (MITM, acceso al core, eNB comprometido).

### 4.2 SIP INVITE Spoofing
- **Descripción:** Enviar mensajes SIP INVITE con identidad falsa en entornos IMS mal configurados.
- **Impacto:** Llamadas falsas, consumo de recursos, evasión de billing.

### 4.3 SRTP Key Exposure (SDES sin TLS)
- **Descripción:** El método SDES intercambia las claves SRTP dentro del SDP, que a su vez viaja en el SIP INVITE. Si la señalización SIP no está protegida por TLS/IPSec, las claves viajan en texto claro.
- **Impacto:** Con las claves capturadas, el atacante puede descifrar el audio SRTP.

### 4.4 RTP Injection / RTCP Hijacking
- **Descripción:** Sin SRTP, el atacante puede inyectar paquetes RTP o manipular RTCP.
- **Impacto:** Corrupción del audio, revelación de estadísticas de la sesión.

---

## 5. Modelo de Amenaza del Laboratorio

En este laboratorio **simulamos el escenario de atacante en el mismo segmento de red del core IMS**, que representa:

- Un insider malicioso en la red del operador.
- Un atacante que ha comprometido un nodo de la red (eNB, SGW).
- Un entorno IMS mal configurado sin SRTP.

```
[ UE-A (srsRAN) ] ──> [ IMS: Kamailio + Asterisk ]
                                    ↑
                        [ Kali (MITM / sniffer) ]
                                    ↓
                       [ Wireshark captura RTP ]
                       [ RTP decode → audio .wav ]
```

---

## 6. Herramientas de Ataque a Investigar

| Herramienta | Uso en el laboratorio |
|---|---|
| **Wireshark** | Captura de tráfico SIP y RTP |
| **tshark** | Captura en línea de comandos |
| **rtpdump / rtpbreak** | Extracción de flujos RTP |
| **sipgrep** | Filtrado de mensajes SIP en tiempo real |
| **SIPp** | Generación de tráfico SIP para pruebas |

---

## 7. Referencias Académicas

- Raza, D. et al. (2019). *Breaking LTE on Layer Two*. IEEE S&P 2019.
- Hussain, S. et al. (2019). *Insecure Connection Bootstrapping in Cellular Networks*. WiSec 2019.
- 3GPP TR 33.926 — Security assurance specification for 5G
- 3GPP TS 33.203 / TS 33.401 — Seguridad de acceso IMS y arquitectura de seguridad SAE.
- Kim, H. et al. (2020). *LTEInspector: A Systematic Approach for Adversarial Testing of 4G LTE*. NDSS 2018.
- MITRE ATT&CK for Mobile — https://attack.mitre.org/matrices/mobile/
- RFC 3261, RFC 3325, RFC 5630.

---

**Siguiente sección:** [`../02_herramientas/`](../02_herramientas/) — Documentación de las herramientas empleadas en el laboratorio.
