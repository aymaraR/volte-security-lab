# ⚔️ Vectores de Ataque - Implementar y ejecutar

> ⚠️ **Propósito estrictamente académico.** Esta documentación analiza vulnerabilidades conocidas y publicadas en la literatura de seguridad. No se provee código malicioso ni instrucciones de ataque sobre redes reales.

---

## 1. Introducción

Una red VoLTE combina varias capas heredadas de dominios de seguridad distintos —radio LTE, core EPC, señalización SIP/IMS y transporte de voz RTP—, cada una con su propio historial de vulnerabilidades documentadas en literatura académica y en boletines de la GSMA. Este documento consolida el modelo de amenazas del proyecto: qué capa se ataca, con qué técnica, y qué contramedida existe, sirviendo de mapa conceptual antes de ejecutar cada prueba en el laboratorio.

Los procedimientos técnicos detallados (comandos, scripts, métricas de éxito) de cada vector se documentan íntegramente en la propuesta de tesis y se replican en el pipeline de automatización del repositorio (`attacks/`). Este documento se enfoca en el **por qué** de cada vulnerabilidad y su **clasificación de riesgo**, mientras que la ejecución práctica se referencia desde aquí.

---

## 2. Modelo de Amenazas por Capa

| Capa | Elemento | Amenazas principales |
|---|---|---|
| Radio (Uu) | eNodeB / UE | Cifrado nulo o débil (EEA0), rogue eNodeB, jamming (fuera de alcance del laboratorio) |
| Core (EPC) | MME/SGW/PGW | Manipulación de bearers, exhaustion de recursos, ataques a interfaces Diameter |
| Señalización (IMS/SIP) | P/I/S-CSCF | Interceptación (MITM), DoS por inundación, suplantación de identidad |
| Transporte de voz (RTP) | Media plane | Interceptación de audio, inyección de paquetes RTP, secuestro de sesión |

---

## Criterio de selección

Los 7 vectores se seleccionaron porque:
1. Son reproducibles sin hardware SDR ni terminales físicos (compatibles con el modo ZMQ).
2. Cubren los tres planos principales del sistema: señalización IMS/SIP, cifrado de radio y plano de datos GTP-U.
3. Están priorizados por severidad CVSS 3.1 y mapeados a MITRE ATT&CK for Mobile.
4. Los 4 primeros (V1–V4) son obligatorios para la tesis; V5–V7 son contribución extendida (opcional según tiempo disponible, ver cronograma).

---

## Vectores obligatorios

### V1 — Intercepción de Señalización SIP/SDP
- **Criticidad:** CRÍTICA (CVSS 9.1) — MITRE ATT&CK T1557 (Adversary-in-the-Middle)
- **Objetivo:** Capturar el SDP en claro (IP de media, puerto RTP, códec) cuando el P-CSCF no fuerza TLS.
- **Herramientas:** ARP spoofing (arpspoof) desde el contenedor Kali, Wireshark (filtro `sip || rtp`), rtpbreak para reconstruir el audio.
- **Contramedida a validar:** `tls_required=yes` en Kamailio; se espera tráfico TLSv1.3 ilegible tras aplicarla.

### V2 — Denegación de Servicio sobre el IMS
- **Criticidad:** CRÍTICA (CVSS 8.6) — MITRE ATT&CK T1498 (Network DoS)
- **Sub-escenario 2a (REGISTER Flood):** ráfagas de REGISTER con credenciales distintas (inviteflood, SIPp) agotan la tabla de diálogos del S-CSCF.
- **Sub-escenario 2b (Transaction Exhaustion):** INVITEs sin ACK/BYE mantienen transacciones en TRYING hasta expirar el timer B (32 s).
- **Métrica de éxito:** un REGISTER legítimo recibe 503 o no responde en 5 s.
- **Contramedida a validar:** rate limiting con el módulo `pike` de Kamailio.

### V3 — Suplantación de Identidad (User Impersonation)
- **Criticidad:** ALTA (CVSS 7.4) — MITRE ATT&CK T1534 (Internal Spearphishing)
- **Objetivo:** Iniciar una llamada apareciendo como otro usuario registrado, forjando el header `From` con Scapy.
- **Contramedida a validar:** verificación de P-Asserted-Identity contra el registro autenticado; se espera un 403 Forbidden si no coincide.

### V4 — Análisis de Robustez del Cifrado Radio
- **Criticidad:** ALTA (CVSS 7.5) — MITRE ATT&CK T1040 (Network Sniffing)
- **Objetivo:** Demostrar que EEA0 (sin cifrado) expone el tráfico RTP en claro, en contraste con EEA2 (AES-CTR 128 bits).
- **Procedimiento:** captura con tcpdump en la interfaz `ogstun`, análisis en Wireshark con filtro `rtp`.
- **Comparación:** payload legible/reconstruible (EEA0) vs. payload cifrado ininteligible (EEA2).

---

## Vectores extendidos (contribución adicional, si el tiempo lo permite)

### V5 — Rogue eNodeB
- Segundo srsENB con mayor prioridad de celda (`dl_earfcn`) atrae al srsUE, demostrando ataque de celda falsa sin necesidad de SDR físico.

### V6 — GTP-U Injection
- Inyección de paquetes en el túnel GTP-U del S/PGW usando Scapy con un TEID conocido, alterando el tráfico de datos del usuario.

### V7 — SIP BYE Forjado
- Terminación forzada de una llamada activa mediante un BYE sin autenticación de diálogo, explotando la ausencia de verificación de tags From/To.

---

## Ciclo metodológico aplicado a cada vector (4 fases)

| Fase | Actividad | Duración estimada |
|---|---|---|
| 1. Reconocimiento pasivo | Captura baseline del tráfico normal; identificación de puertos, protocolos y patrones. | 30 min |
| 2. Análisis de configuración | Revisión de archivos de configuración del EPC e IMS en busca de parámetros inseguros. | 45 min |
| 3. Explotación activa | Ejecución del ataque con las herramientas definidas; captura de evidencia y logs. | 60–90 min |
| 4. Validación de contramedida | Aplicación de la mitigación; re-ejecución del ataque para verificar efectividad. | 45 min |

---

## Referencias

- MITRE ATT&CK for Mobile — https://attack.mitre.org/matrices/mobile/
- 3GPP TS 33.203 / TS 33.401 — Seguridad de acceso IMS y arquitectura de seguridad SAE.
- RFC 3261, RFC 3325, RFC 5630.
- Propuesta de tesis del proyecto (documento fuente de los procedimientos de ataque y contramedidas).

---

**Siguiente sección:** [`../02_herramientas/`](../02_herramientas/) — Documentación de las herramientas empleadas en el laboratorio.
