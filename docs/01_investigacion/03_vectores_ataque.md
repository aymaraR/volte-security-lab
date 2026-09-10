# ⚔️ Vulnerabilidades: Vectores de Ataque en Redes 4G LTE / VoLTE

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

## 2. Plano de Radio / Acceso (RAN — eNodeB/UE)

| Vulnerabilidad | Descripción | Referencia |
|---|---|---|
| Rogue eNodeB / Fake Base Station | Un eNodeB falso con mayor prioridad de celda o mejor señal atrae UEs, permitiendo intercepción, downgrade o DoS selectivo. | MITRE ATT&CK Mobile T1417; 3GPP TS 33.401 |
| IMSI Catching | Explota que el mensaje Identity Request en NAS puede solicitar el IMSI en texto claro antes de establecer seguridad, permitiendo identificar/rastrear un UE. | 3GPP TS 24.301; investigación académica (ej. "Practical Attacks Against Privacy and Availability in 4G/LTE") |
| Downgrade a 2G/3G | Forzar al UE a reconectarse a una red 2G (GSM) donde el cifrado A5/1 o A5/0 es más débil o inexistente. | 3GPP TS 33.401 Anexo sobre interworking |
| Cifrado nulo (EEA0) | El operador o configuración permite EEA0 (sin cifrado) en la capa PDCP, exponiendo todo el tráfico de usuario en claro. | 3GPP TS 33.401 §5.1.3 |
| Ataques de re-lectura/replay en RRC | Mensajes RRC sin protección de integridad antes del Security Mode Command pueden ser inyectados o repetidos (ej. ataques "aLTEr", "Torpedo", "Piercer"). | Rupprecht et al., "Breaking LTE on Layer Two" (2019) |
| Paging channel attacks | Explotan el canal de paging (no cifrado) para desanonimizar usuarios o provocar DoS de localización (ej. "Torpedo attack"). | Hussain et al., "Insecure Connection Bootstrapping in Cellular Networks" |
| Jamming / DoS de RF | Interferencia deliberada de la señal de radio para degradar o bloquear el servicio. | Genérico — no aplica en emulación ZMQ (no hay RF real) |

## 3. Plano NAS / Autenticación (EPS-AKA, MME, HSS)

| Vulnerabilidad | Descripción | Referencia |
|---|---|---|
| Ataques de desincronización AKA | Explotan fallos en el manejo de SQN (sequence number) del protocolo AKA para desincronizar al HSS y al UE. | 3GPP TS 33.102 / TS 33.401 |
| Fingerprinting de dispositivo/operador | Diferencias en los códigos de error NAS (ej. "EMM cause codes") permiten inferir el modelo de UE o la configuración del operador. | Shaik et al., "LTEInspector" (2019) |
| Bidding-down de algoritmos de seguridad | Forzar la negociación hacia el algoritmo de cifrado/integridad más débil soportado por ambas partes. | 3GPP TS 33.401 §5.4.1 |
| Ataques de denegación de servicio NAS | Envío de mensajes NAS malformados o repetidos que agotan recursos del MME o dejan al UE en estado inconsistente. | MITRE ATT&CK Mobile T1498 |
| Suplantación de HSS/MME (rogue core) | En entornos sin autenticación mutua fuerte entre nodos del core, un nodo falso puede insertarse en la señalización S6a (Diameter). | 3GPP TS 29.272 |

## 4. Plano IMS / SIP (VoLTE específico)

| Vulnerabilidad | Descripción | Referencia |
|---|---|---|
| Intercepción de señalización SIP/SDP | Ausencia de TLS/IPSec en la interfaz Gm permite capturar INVITE/SDP con direcciones IP de media y códecs. | RFC 3261; RFC 5630 |
| REGISTER / INVITE Flood (DoS) | Ráfagas de mensajes SIP agotan la memoria de diálogos o transacciones del S-CSCF. | MITRE ATT&CK T1498 |
| Transaction exhaustion | INVITEs sin completar el handshake (sin ACK/BYE) mantienen transacciones abiertas hasta expirar el timer B. | RFC 3261 §17.1.1 |
| Suplantación de identidad (P-Asserted-Identity spoofing) | Falta de validación del header P-Asserted-Identity contra el IMSI autenticado permite forjar el remitente de una llamada. | RFC 3325; 3GPP TS 24.229 |
| SIP BYE / CANCEL forjado | Terminación forzada de sesiones activas explotando ausencia de verificación de tags From/To/Call-ID. | Investigación VoIP/SIP security (ej. SIPVicious toolkit docs) |
| Toll fraud / bypass de tarificación | Explota fallas de enrutamiento o autorización del S-CSCF para originar llamadas no autorizadas o hacia destinos de alto costo. | Reportado en literatura de fraude VoIP/VoLTE |
| Ataques sobre RTP (inyección, secuestro de media) | Sin SRTP, el flujo de voz puede ser inyectado, escuchado o secuestrado tras conocer IP/puerto negociado en el SDP. | RFC 3711 (SRTP) como contramedida |
| Enumeración de usuarios IMS | Diferencias en respuestas SIP (403 vs 404) a REGISTER permiten enumerar identidades válidas registradas. | Práctica común en pentesting SIP (ej. SIPVicious "svmap/svwar") |

## 5. Plano de Datos / Core de Paquetes (EPC — SGW/PGW, GTP-U)

| Vulnerabilidad | Descripción | Referencia |
|---|---|---|
| GTP-U Injection | Inyección de paquetes en el túnel GTP-U conociendo o adivinando el TEID (Tunnel Endpoint Identifier), permitiendo alterar o inyectar tráfico de datos. | GSMA FS.20 "GTP Security"; MITRE ATT&CK Mobile |
| GTP-C spoofing / roaming abuse | En interconexión entre operadores (interfaz S8/Gp), la falta de autenticación en GTP-C permite ataques de suplantación entre redes. | GSMA FS.11 "SS7 and Diameter Interconnect Security" |
| Fuga de TEID | Los TEID predecibles o filtrados en capturas facilitan ataques GTP-U dirigidos. | Investigación académica sobre seguridad GTP |
| Diameter/S6a abuse | Ataques de actualización de ubicación o cancelación de suscripción falsos entre MME y HSS. | GSMA FS.19 "Diameter Interconnect Security" |
| Ataques de doble IP-CAN / bypass de PCRF | Manipulación de las reglas de política y tarificación (PCRF) para obtener QoS o acceso no autorizado. | 3GPP TS 29.212 |

## 6. Vulnerabilidades transversales / de gestión

| Vulnerabilidad | Descripción |
|---|---|
| Configuraciones por defecto inseguras | Credenciales o parámetros de fábrica sin cambiar en HSS, MongoDB, paneles de administración. |
| Falta de segmentación de red | Planos de control, usuario y gestión en la misma VLAN/subred, facilitando movimiento lateral tras un compromiso inicial. |
| Ausencia de logging/monitoreo centralizado | Dificulta la detección temprana de ataques de señalización o DoS distribuido. |
| Falta de rate limiting / anti-flood | Ya cubierto en plano IMS, pero también aplica a nivel de MME/HSS ante ráfagas de Attach Request. |

## 7. Herramientas de Ataque a Investigar

| Herramienta | Uso en el laboratorio |
|---|---|
| **Wireshark** | Captura de tráfico SIP y RTP |
| **tshark** | Captura en línea de comandos |
| **rtpdump / rtpbreak** | Extracción de flujos RTP |
| **sipgrep** | Filtrado de mensajes SIP en tiempo real |
| **SIPp** | Generación de tráfico SIP para pruebas |

---

## 8. Referencias Académicas

- 3GPP TS 33.401 — SAE Security Architecture.
- 3GPP TS 33.203 — Access security for IP-based services (IMS).
- 3GPP TS 23.228 — IP Multimedia Subsystem (IMS), Stage 2.
- GSMA FS.11, FS.19, FS.20 — Interconnect and GTP Security guidelines.
- MITRE ATT&CK for Mobile — https://attack.mitre.org/matrices/mobile/
- Rupprecht, D. et al. "Breaking LTE on Layer Two" (IEEE S&P 2019).
- Shaik, A. et al. "LTEInspector: A Systematic Approach for Adversarial Testing of 4G LTE" (NDSS 2018).
- Hussain, S. et al. "Insecure Connection Bootstrapping in Cellular Networks: the Root Cause for Faked Base Stations" (WiSec 2019).
- MITRE ATT&CK for Mobile — https://attack.mitre.org/matrices/mobile/
- RFC 3261, RFC 3325, RFC 5630.

---

**Siguiente sección:** [`../02_herramientas/`](../02_herramientas/) — Documentación de las herramientas empleadas en el laboratorio.
