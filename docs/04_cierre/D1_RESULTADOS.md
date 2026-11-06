# D1 — Resultados de autenticación LTE (2026-11-04)

**Objetivo D1:** demostrar la autenticación LTE (EPS-AKA) y dejar evidencia en S1AP/NAS.  
**Resultado:** **D1 LTE completado**. El UE1 ejecutó `Attach Request → Authentication Request/Response → Security Mode Command/Complete → Attach Accept/Complete` sin fallos.

---

## 1. Secuencia capturada

Captura: `voLTE-lab/results/d1_lte_auth/s1ap_attach.pcap`  
Punto: `open5gs:eth0`, filtro `sctp port 36412`.

| Frame | Mensaje | Dirección | Tiempo relativo |
|---|---|---|---|
| 49 | Attach Request | eNB → MME | t0 |
| 50 | Authentication Request | MME → eNB | +16.702 ms |
| 51 | Authentication Response | eNB → MME | +33.550 ms |
| 52 | Security Mode Command | MME → eNB | +0.515 ms |
| 53 | Security Mode Complete | eNB → MME | +26.189 ms |
| 56 | Attach Accept | MME → eNB | +75.299 ms |
| 59 | Attach Complete | eNB → MME | +261.002 ms |

- **Attach total:** 413.257 ms.
- **Reto AKA (Authentication Request → Security Mode Complete):** 60.254 ms.

## 2. Parámetros AKA

| Parámetro | Valor |
|---|---|
| RAND | `db6295324a002b9738cca27b64840af1` |
| AUTN | `df6795cf3809800003d19974213b256c` |
| RES | `da418b3e8def09d4` |
| SQN xor AK | `df6795cf3809` |
| AMF | `8000` |
| MAC | `03d19974213b256c` |

## 3. Algoritmos

- Cifrado: **EEA0** (null ciphering).
- Integridad: **EIA2** (128-EIA2).

> EEA0 es el escenario de cifrado nulo asociado a V4. En el alcance de cierre V4 está sustituido por V7; se conserva este dato como referencia.

## 4. Coherencia de credenciales

`mongo_subscriber.txt` y `ue_usim.txt` muestran el mismo material:

- IMSI `001010123456789`
- K `00112233445566778899aabbccddeeff`
- OPc `63bfa50ee6523365ff14c1f45f88737d`
- AMF `8000`
- USIM `milenage`

## 5. Checks negativos

```text
authentication_request=1
authentication_response=1
security_mode_command=1
security_mode_complete=1
authentication_failure=0
attach_reject=0
attach_complete=1
no_bearer_in_mme_log=0
attach_accept_ebi5=1
attach_complete_ebi5=1
```

## 6. Evidencia

Directorio: `voLTE-lab/results/d1_lte_auth/`

- `s1ap_attach.pcap`
- `lte_auth_sequence.txt`
- `lte_auth_detail.txt`
- `lte_auth_metrics.csv`
- `lte_auth_checks.txt`
- `ue_attach.log`
- `mme_attach.log`
- `mongo_subscriber.txt`
- `ue_usim.txt`
- `SHA256SUMS.txt` (verificado)

## 7. Reproducción

Ver `results/d1_lte_auth/README.md`. La captura se tomó en el netns de `open5gs` para sobrevivir al reinicio del par eNB/UE; el attach se forzó recreando `srsenb`/`srsue` con `.lab-tmp/d1_recreate_attach.sh`.

## 8. Estado del laboratorio al cierre de D1

- UE1 con `tun_srsue` y ruta a `172.20.0.6` por el túnel.
- baresip 1001 registrado por TLS: `200 OK` (3 bindings).
- UE2 sigue levantado con su túnel.
- Plano GTP-U validado en D0 (600/600 pings, 0 % pérdida) y llamada 1001→1000 por GTP.

## 9. Siguiente bloque: D2

1. Compilar/activar `ims_auth` en el S-CSCF.
2. Provisionar AuC/Subscriber en PyHSS para 1001/1002.
3. Capturar `REGISTER → 401 → REGISTER autenticado → 200`.
4. Prueba negativa con credencial incorrecta.
5. Recién después, V7 con BYE en el pcap.
