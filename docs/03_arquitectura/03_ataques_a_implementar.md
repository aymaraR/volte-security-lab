# Vectores de Ataque - Implementar y ejecutar

> **Propósito estrictamente académico.** Esta documentación analiza vulnerabilidades conocidas y publicadas en la literatura de seguridad. No se provee código malicioso ni instrucciones de ataque sobre redes reales.

---

## Estado de ejecución en el laboratorio (actualizado 2026-10-02)

| Vector | Veredicto | Evidencia en `voLTE-lab/results/` |
|---|---|---|
| V1 Intercepción SIP/SDP | VULNERABLE (baseline) / MITIGADO con TLS+SRTP (0 INVITE/SDP en claro, media cifrada) | `v1_mitm_sip_*.pcapng`, `v1_audio_*.wav` |
| V2 DoS IMS | DEGRADACIÓN real en REGISTER flood (avg 6-9x, 1 timeout) / MITIGADO con pike (atacante 403, sonda neutral normal) | `v2_register_3000_*.{pcapng,csv}` |
| V3 Suplantación | VULNERABLE (baseline) / MITIGADO con binding identidad<->origen (3x403, 1002 no contesta) | `v3_spoof_1001-to-1002_*.pcapng` |
| V4 Cifrado radio | Sustituido por V7 (solicitud de la empresa) | `voLTE-lab/results/v7_d3/` |
| V5 Rogue eNodeB | VULNERABLE condicionado (PCI 7, attach OK en corrida 154002Z) | `v5_d3/` |
| V6 GTP-U Injection | VULNERABLE (5 inyecciones, 5 respuestas) / MITIGADO (0 respuestas) | `v6_d3/` |
| V7 BYE forjado | VULNERABLE (1->0, 4 BYE + 4x200) / MITIGADO (1->1, 3 BYE + 3x403) | `v7_d3/v7_*_{dialog,attack}_*.pcap` |

Contramedidas aplicadas y validadas (fase 4, 2026-10-23): TLS obligatorio en P-CSCF + SRTP/SDES (V1), `pike` en Kamailio (V2), binding IMPU<->IP de origen en P-CSCF (V3/V7). Implementación reproducible en `voLTE-lab/parches/aplicar.sh` (revertir con `revertir.sh`). Detalle operativo por vector en `voLTE-lab/kali.md`.

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
4. Los vectores (V1, V2, V3 y V7) son obligatorios para la tesis; V5/V6 son contribución extendida (opcional según tiempo disponible, ver cronograma).

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

### V5 - Rogue eNodeB (vulnerable condicionado 2026-11-04)

- Segundo srsENB con takeover ZMQ (misma IP/puertos del eNB1 legítimo, PCI 7 / cell 0x09) para atraer al srsUE, sin SDR físico.
- Resultado: en 3 corridas con reinicio de contenedor el UE no completó attach; en la corrida 154002Z, con eNB2 apagado y reinicio de proceso, el UE reportó `Found Cell PCI=7`, obtuvo IP 10.45.0.8 y el MME registró `Attach complete`. Veredicto: vulnerable condicionado (sensible a ZMQ).
- Evidencia: `voLTE-lab/results/v5_d3/v5_success_20261104T154002Z.log` + hashes. Nota: la celda 2 (`.14`, PCI 2) es legítima, no es el ataque.

### V6 - GTP-U Injection (cierre 2026-11-04)
- Inyección de 5 T-PDU GTP-U desde Kali `.99` al eNB `.4:2152` con el TEID downlink real; la UE responde 5/5 ICMP. Mitigado con filtro `tc` en el eNB (solo SGW-U `.3`): 0 respuestas.
- Evidencia: `voLTE-lab/results/v6_d3/` + hashes; script `vectores/v6_gtp_cierre.sh`.

### V7 — SIP BYE Forjado (cierre D3 2026-11-04)

- Terminación forzada de llamada activa (`1001->1000`) con BYE sin autenticación de diálogo. Requiere extraer `Call-ID`, tags `From/To` y `CSeq` del diálogo (captura en kamailio con `tcpdump`, extracción con `tshark` en kali: kamailio no trae `tshark`).
- Detalle crítico: el RURI debe ser el contacto remoto (`sip:172.20.0.7:5061`) con `Route: <sip:172.20.0.6:4060;lr>`; con RURI `sip:1000@<dominio>` el P-CSCF no lo enruta.
- Éxito medido: `BYE CSeq 50151` → `200 OK`, canales PJSIP `1->0` en Asterisk.
- Evidencia: `voLTE-lab/results/v7_d3/v7_{vuln,mit}_{dialog,attack}_*.pcap` + hashes.

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
