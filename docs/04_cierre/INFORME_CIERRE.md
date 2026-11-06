# Informe de cierre — Laboratorio VoLTE

**Fecha:** 2026-11-04  
**Alcance:** cierre técnico y documental del laboratorio `voLTE-lab`.  
**Resultado global:** **D0–D5 completados**; ver `D5_REPRODUCCION.md`.

---

## 1. Resumen ejecutivo

El laboratorio quedó operativo de extremo a extremo:

- LTE/GTP-U estable, con llamada real por el túnel GTP.
- Autenticación LTE (EPS-AKA) demostrada en S1AP/NAS.
- Autenticación IMS resuelta con `REGISTER → 401 → 200` y prueba negativa.
- V7 cerrado con el BYE **dentro del pcap**, en estado vulnerable y mitigado.
- V4 sustituido formalmente por V7 a solicitud de la empresa.
- Métricas, capturas e integridad centralizadas en `voLTE-lab/results/`.

La evidencia final se verifica con `results/verificar.py`: **123 archivos, 0 faltantes, 0 diferencias**.

---

## 2. Alcance y decisiones

| Tema | Decisión |
|---|---|
| V4 cifrado radio | **Sustituido por V7** (solicitud de la empresa) |
| V7 BYE forjado | Vector obligatorio de cierre; vulnerable + mitigado |
| V6 GTP-U injection | **Cerrado en alcance extendido** (vulnerable + mitigado) |
| V5 rogue eNodeB | Vulnerable condicionado: PCI 7 + attach OK; reproducibilidad sensible a ZMQ |
| Autenticación IMS | Digest-MD5 baseline + IMS-AKA real demostrado con 1003 |
| Evidencia | `results/MANIFEST.csv` + `hashes.txt` + verificador |

---

## 3. Arquitectura validada

```text
UE (srsUE) ──ZMQ/LTE── eNB (srsENB) ──S1-U GTP-U── Open5GS (MME/SGW-U/PGW-U)
    │                                                        │
    └── TLS/SIP (Gm) ── P-CSCF ── I-CSCF ── S-CSCF ── Asterisk (TAS)
                              │             │
                              └── Cx ── PyHSS (AuC/Subscriber)
```

Componentes con cambios de cierre:

- `open5gs-config/sgwu.yaml`: GTP-U de SGW-U en `172.20.0.3` (antes loopback).
- `lab-up.sh`: `ogstun` antes del attach; keepalive ICMP desde el attach.
- `srsran/Dockerfile.cierre` + `patches/fix_ebi.py`: workaround EBI 5/PTI 1 de srsUE.
- `kamailio/Dockerfile.cierre`: compila `ims_auth.so`.
- `kamailio/scscf/scscf.cfg`: challenge IMS y Cx.
- `pyhss/lib/diameter.py`: fallback IMPU→IMSI.
- `pyhss/provision_ims_auth.py`: APN/AuC/Subscriber idempotente.

---

## 4. Resultados por fase

### D0 — LTE/GTP-U

- `lab-up.sh` 13/13.
- UE1/UE2 con `tun_srsue`; ping a `10.45.0.1`: **600/600, 0 % pérdida, 600.7 s**.
- Sin `No Bearer`, sin detach, sin `Service request` en 15 min.
- Llamada 1001→1000 por GTP: **15 s**, SRTP, `Echo()`, 1 canal activo.
- TEIDs UL `0x5019`/`0x761a`; captura GTP-U de 254 181 bytes en la llamada.

Evidencia: `results/d0_gtp/`.

### D1 — Autenticación LTE

- Attach: **413.257 ms**.
- Authentication Request→Response: **33.550 ms**.
- Security Mode Command→Complete: **26.189 ms**.
- RAND/AUTN/RES capturados; EEA0 / EIA2; EBI 5.
- Sin Authentication Failure ni Attach Reject.

Evidencia: `results/d1_lte_auth/`.

### D2 — Autenticación IMS

- `REGISTER → 401 → 200`: **126.619 ms** de 401 a 200.
- IMPI: `001010123456789@ims.mnc070.mcc999.3gppnetwork.org`.
- Password incorrecta: **401**; restauración: **200**.
- 1001 y 1002 autenticados.

Evidencia: `results/d2_ims_auth/`.

### D3 — V7

| Escenario | Canales PJSIP | BYE en pcap | Respuesta | Veredicto |
|---|---|---|---|---|
| Vulnerable | 1 → 0 | 4 | 4×200 | VULNERABLE |
| Mitigado | 1 → 1 | 3 | 3×403 | MITIGADO |

Evidencia: `results/v7_d3/`.

### V1/V2/V3/V5

- V1: 2 INVITE + 4 SDP en claro y 9 980 RTP; mitigado sin SDP/RTP en claro.
- V2: REGISTER flood avg 702 ms / max 6 007 ms / 1 timeout; mitigado 99/202/0.
- V3: INVITE forjado aceptado; mitigado 3×403.
- V5: rogue eNodeB vulnerable condicionado; PCI 7 y attach OK en la corrida 154002Z.

---

## 5. Métricas consolidadas

Archivo: `results/metrics.csv` (33 filas). Incluye:

- D0: estabilidad, pérdida, detach, duración de llamada, TEIDs.
- D1: attach, auth, security mode, EEA/EIA, EBI.
- D2: 401/200, prueba negativa, restauración.
- D3: canales, BYE, 200/403.
- V1/V2/V3: métricas de referencia.

Cada fila referencia el archivo de evidencia y su SHA-256.

---

## 6. Integridad del set

- `results/MANIFEST.csv`: 123 archivos con vector, escenario, timestamp, tamaño y SHA-256.
- `results/hashes.txt`: regenerado desde el manifiesto.
- `results/verificar.py` / `verificar.sh`: **123 OK, 0 faltantes, 0 diferencias**.
- `results/hashes_historico.txt`: registro previo completo.
- Correcciones:
  - V5: hash real recalculado (el anterior no correspondía al archivo presente).
  - V3: referencia corregida a `...T015138Z`.
  - V7 histórico: se conserva, pero el set de cierre es `v7_d3/` con BYE en el pcap.

---

## 7. Limitaciones

- **D2 usa Digest-MD5** como baseline interoperable; el anexo IMS-AKA demuestra 401 `AKAv1-MD5` -> 200 con RES real para 1003. IPsec/Gm queda como evolución.
- Asterisk/TAS `1000` se considera nodo interno de confianza y no recibe challenge.
- La corrida V7 vulnerable se hizo en bridge (por diseño de `revertir.sh`); la mitigada en el path GTP/TLS. V7 es un ataque de señalización y el BYE quedó capturado en ambos casos.
- La RF ZMQ puede requerir recrear contenedores tras muchos reinicios; el procedimiento reproducible es `lab-up.sh` desde estado limpio.
- V6 se ejecutó en alcance extendido: 5 inyecciones GTP-U con 5 respuestas de la UE y mitigación con filtro `tc` (0 respuestas).

---

## 8. Conclusiones

1. Es posible reproducir una cadena VoLTE completa 100 % software y aislada.
2. La estabilización de GTP-U exigió corregir el endpoint SGW-U y el timing del `ogstun`/keepalive, además del workaround EBI de srsUE.
3. La autenticación LTE e IMS quedó demostrada con evidencia en el cable.
4. V7 se cerró con evidencia directa del BYE, no solo con el estado de canales.
5. El set de resultados es verificable e íntegro; el informe y la reproducción quedan documentados.

---

## 9. Reproducción

Ver `D5_REPRODUCCION.md` y `voLTE-lab/scripts/aceptacion.sh`.

```bash
cd voLTE-lab
docker compose down -v
./lab-up.sh
sh scripts/aceptacion.sh
python3 results/verificar.py
```


---

## 10. Anexo de alcance extendido

- **V6 — GTP-U injection:** cerrado en `results/v6_d3/`; TEID `0x2`,
  5 inyecciones, 5 respuestas ICMP, mitigado con filtro `tc` en el eNB.
- **IMS-AKA real:** cerrado en `results/aka_d3/`; IMPU 1003/IMPI
  `001010123456791`, 401 `AKAv1-MD5` -> 200 con RES binario.
- **V5 - Rogue eNodeB:** vulnerable condicionado; PCI 7 y attach OK en la corrida 154002Z; reproducibilidad sensible a ZMQ.

Detalle: `EXTENDIDO_V5_V6_AKA.md`.
