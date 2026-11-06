# Alcance extendido: V6, IMS-AKA y V5

**Fecha:** 2026-11-04  
**Estado:** V6 cerrado, IMS-AKA cerrado, V5 vulnerable (reproducibilidad sensible a ZMQ).

Este anexo no modifica el cierre D0–D5; agrega evidencia de los vectores que la
empresa pidió considerar dentro del scope.

---

## 1. V6 — Inyección GTP-U: CERRADO

| Fase | Resultado |
|---|---|
| Descubrimiento | TEID downlink `0x00000002`, UE `10.45.0.5` |
| V6 vulnerable | 5 inyecciones, 5 respuestas ICMP de la UE |
| V6 mitigado | 5 intentos, 0 respuestas |
| Contramedida | `tc flower` en eNB: solo GTP-U desde SGW-U `172.20.0.3` |

Evidencia: `voLTE-lab/results/v6_d3/`.  
Script: `voLTE-lab/vectores/v6_gtp_cierre.sh`.

La captura de descubrimiento se hizo en `open5gs:eth0` puerto 2152. El script
antiguo capturaba en `ogstun`, que no es el punto S1-U y por eso no encontraba
el TEID.

---

## 2. IMS-AKA real: CERRADO

| Paso | Resultado |
|---|---|
| REGISTER inicial | `401` con `algorithm=AKAv1-MD5` |
| Nonce | `base64(RAND||AUTN)` |
| RES | calculado con MILENAGE y K/OPc del AuC |
| Segundo REGISTER | `200 OK` |
| Identidad | IMPU 1003 / IMPI 001010123456791 |

Evidencia: `voLTE-lab/results/aka_d3/`.  
Script: `voLTE-lab/vectores/aka_cierre.sh` y `scripts/ims_aka_client.py`.

Hallazgo técnico: Kamailio `ims_auth` usa el **RES binario de 8 bytes** como
password para `H(A1)=MD5(IMPI:realm:RES)`. Usar el RES en hexadecimal produce
un 401 aunque el vector AKA sea correcto.

Alcance: autenticación AKA; no se implementó IPsec/Gm. baresip/1001/1002 siguen
en Digest-MD5 para no romper D2.

---

## 3. V5 — Rogue eNodeB: VULNERABLE (condicionado)

Tras tres intentos con `docker restart` del UE que no sincronizaron, se repitió
con **eNB2 apagado** y **reinicio del proceso UE** (sin recrear el contenedor):
el eNB falso con PCI 7 tomó los puertos ZMQ del eNB1, el UE reportó
`Found Cell PCI=7`, obtuvo IP `10.45.0.8` y el MME registró
`[001010123456789] Attach complete`.

Evidencia:
- `results/v5_d3/v5_success_20261104T154002Z.log`
- `results/v5_rogue_20261104T144013Z.log` … `...152449Z.log` (fallos previos)

**Veredicto:** VULNERABLE, con reproducibilidad sensible a ZMQ/PHY. No se
presenta como ataque estable al 100 %. La contramedida (allowlist de eNB/PCI)
queda como diseño, no validada.

---

## 4. Impacto en la entrega

- El cierre principal sigue siendo D0–D5.
- V6 e IMS-AKA son anexos verificables con hash.
- V5 se entrega como vulnerable condicionado, con la limitación explícita.
- No se alteró la ruta estable de 1001/1002 ni la evidencia D2.
