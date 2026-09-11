# Vectores de Ataque — Superficie de Seguridad VoLTE

> Documento de investigación teórica — Fase 1 del proyecto de tesis
> Laboratorio de seguridad VoLTE sobre redes 4G/LTE

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

## 3. Resumen de los Siete Vectores de Ataque

| # | Vector | Capa | Criticidad (CVSS 3.1) | MITRE ATT&CK |
|---|---|---|---|---|
| V1 | Interceptación de señalización SIP/SDP | Señalización | 9.1 (Crítica) | T1557 — AiTM |
| V2 | Denegación de servicio sobre el IMS | Señalización | 8.6 (Crítica) | T1498 — Network DoS |
| V3 | Suplantación de identidad (User Impersonation) | Señalización | 7.4 (Alta) | T1534 — Internal Spearphishing |
| V4 | Robustez del cifrado radio (EEA0 vs EEA2) | Radio | 7.5 (Alta) | T1040 — Network Sniffing |
| V5 | Rogue eNodeB | Radio | Extendido | — |
| V6 | Inyección en el túnel GTP-U | Core | Extendido | — |
| V7 | SIP BYE forjado (terminación forzada) | Señalización | Extendido | — |

Los cuatro primeros (V1-V4) son obligatorios para la tesis; V5-V7 se documentan como contribución extendida.

---

## 4. V1 — Interceptación de Señalización SIP/SDP

**Causa raíz:** el Gm (interfaz UE↔P-CSCF) puede operar sin TLS obligatorio ni IPSec-IKEv2 correctamente forzado, permitiendo que el tráfico SIP viaje en texto claro dentro de la red de acceso.

**Impacto:** un atacante posicionado en la misma red (ARP spoofing) puede leer el `INVITE`/SDP completo, obteniendo IP y puerto de media y el codec negociado — información suficiente para localizar y potencialmente reconstruir el flujo RTP de la llamada (con herramientas como `rtpbreak`).

**Contramedida:** forzar TLS en el P-CSCF (`tls_required=yes` en Kamailio). Referencia normativa: RFC 5630.

**Procedimiento detallado:** ver propuesta de tesis, sección 3.1, y script `attacks/v1_mitm_sip.py`.

---

## 5. V2 — Denegación de Servicio sobre el IMS

**Causa raíz:** el S-CSCF procesa cada transacción SIP manteniendo estado en memoria (tabla de diálogos, máquina de estados de transacción). Sin límites de tasa, este estado es agotable.

**Sub-escenarios:**
- **2a — REGISTER Flood:** ráfagas de `REGISTER` con credenciales distintas agotan la tabla de diálogos y la capacidad de autenticación AKA.
- **2b — Transaction Exhaustion:** `INVITE` sin `ACK`/`BYE` mantiene transacciones en estado `TRYING` hasta que expira el Timer B (32 s de la máquina de estados SIP, RFC 3261), agotando memoria con transacciones colgadas.

**Métrica de éxito:** un `REGISTER` legítimo recibe `503 Service Unavailable` o no obtiene respuesta en 5 segundos.

**Contramedida:** rate limiting con el módulo `pike` de Kamailio, limitando la tasa de solicitudes por origen.

**Procedimiento detallado:** ver propuesta de tesis, sección 3.2.

---

## 6. V3 — Suplantación de Identidad (User Impersonation)

**Causa raíz:** si el S-CSCF no valida el header `P-Asserted-Identity` (RFC 3325) contra la identidad autenticada en el registro (IMPI/IMPU verificado en el HSS), el campo `From` de un `INVITE` puede forjarse libremente.

**Impacto:** un atacante puede iniciar una llamada haciéndose pasar por otro usuario legítimo del IMS, habilitando escenarios de fraude, ingeniería social o suplantación en investigaciones internas.

**Contramedida:** habilitar en Kamailio la verificación de `P-Asserted-Identity` contra el registro autenticado, rechazando con `403 Forbidden` cualquier discrepancia.

**Procedimiento detallado:** ver propuesta de tesis, sección 3.3, y script `attacks/v3_identity_spoof.py` (Scapy).

---

## 7. V4 — Robustez del Cifrado Radio

**Causa raíz:** el algoritmo de cifrado de la capa PDCP (`EEA0`, sin cifrado) puede quedar configurado por error o debilidad administrativa en el eNodeB, dejando expuesto todo el tráfico de la interfaz radio, incluido el RTP de una llamada VoLTE.

**Impacto:** cualquier interceptor con acceso a la interfaz radio (o, en el laboratorio, al log/captura del `ogstun`) puede reconstruir el audio de la llamada sin necesidad de comprometer la señalización SIP.

**Contramedida:** forzar `EEA2` (AES-CTR de 128 bits) en la configuración de seguridad del eNodeB.

**Procedimiento detallado:** ver propuesta de tesis, sección 3.4.

---

## 8. Vectores Extendidos (V5–V7)

| Vector | Descripción conceptual | Capa |
|---|---|---|
| **V5 — Rogue eNodeB** | Un segundo eNodeB con mayor prioridad de celda (parámetro de reselección) atrae al UE, ilustrando el principio de un ataque de celda falsa sin necesidad de hardware SDR | Radio |
| **V6 — GTP-U Injection** | Inyección de paquetes en el túnel GTP-U del S/PGW conociendo el TEID de la sesión, alterando el tráfico de datos del usuario | Core |
| **V7 — SIP BYE Forjado** | Terminación forzada de una llamada activa mediante un `BYE` sin verificación de los tags `From`/`To` del diálogo, explotando la ausencia de autenticación de diálogo | Señalización |

---

## 9. Metodología de Evaluación (resumen)

Cada vector se ejecuta siguiendo el mismo ciclo de cuatro fases, detallado con tiempos estimados en la propuesta de tesis:

1. **Reconocimiento pasivo** — captura de tráfico baseline.
2. **Análisis de configuración** — revisión de archivos de configuración del EPC/IMS en busca de parámetros inseguros.
3. **Explotación activa** — ejecución del ataque, captura de evidencia (`.pcapng`, logs).
4. **Validación de contramedida** — aplicación de la mitigación y reejecución del ataque para confirmar su efectividad.

---

## 10. Referencias

- MITRE ATT&CK for Mobile — https://attack.mitre.org/matrices/mobile/
- 3GPP TS 33.203 / TS 33.401 — Seguridad de acceso IMS y arquitectura de seguridad SAE.
- RFC 3261, RFC 3325, RFC 5630.
- Propuesta de tesis del proyecto (documento fuente de los procedimientos de ataque y contramedidas).

---

**Siguiente sección:** [`../02_herramientas/`](../02_herramientas/) — Documentación de las herramientas empleadas en el laboratorio.
