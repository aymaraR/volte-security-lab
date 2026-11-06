# D1 — Autenticación LTE (EPS-AKA) demostrada

**Fecha:** 2026-11-04  
**Captura:** `s1ap_attach.pcap` (S1AP/NAS en eNB1, UE1 IMSI `001010123456789`).  
**Resultado:** attach LTE autenticado correctamente; sin `Authentication Failure`, sin `Attach Reject`, sin `No Bearer`.

## Secuencia observada

| # | Frame | Mensaje NAS | Origen → Destino | Δ tiempo |
|---|---|---|---|---|
| 1 | 49 | Attach Request | eNB → MME | — |
| 2 | 50 | Authentication Request | MME → eNB | +16.702 ms |
| 3 | 51 | Authentication Response | eNB → MME | +33.550 ms |
| 4 | 52 | Security Mode Command | MME → eNB | +0.515 ms |
| 5 | 53 | Security Mode Complete | eNB → MME | +26.189 ms |
| 6 | 56 | Attach Accept (EBI 5) | MME → eNB | +75.299 ms |
| 7 | 59 | Attach Complete (EBI 5) | eNB → MME | +261.002 ms |

**Attach total:** 413.257 ms (frame 49 → 59).  
**Reto AKA completo:** 60.254 ms (Authentication Request → Security Mode Complete).

## Parámetros AKA

- `RAND`: `db6295324a002b9738cca27b64840af1`
- `AUTN`: `df6795cf3809800003d19974213b256c`
- `RES`: `da418b3e8def09d4`
- `SQN xor AK`: `df6795cf3809`
- `AMF`: `8000`
- `MAC`: `03d19974213b256c`

## Algoritmos negociados

- Cifrado: **EEA0** (null ciphering)
- Integridad: **EIA2** (128-EIA2)

> EEA0 es el cifrado nulo que el vector V4 buscaba demostrar. En este cierre V4 está sustituido por V7; el dato se conserva como referencia de configuración.

## Coherencia de credenciales

`mongo_subscriber.txt` y `ue_usim.txt` muestran el mismo material:

- IMSI: `001010123456789`
- K: `00112233445566778899aabbccddeeff`
- OPc: `63bfa50ee6523365ff14c1f45f88737d`
- AMF: `8000`
- Algoritmo USIM: `milenage`

## Checks

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

## Evidencia

| Archivo | Contenido |
|---|---|
| `s1ap_attach.pcap` | Captura S1AP/NAS completa del attach |
| `lte_auth_sequence.txt` | Secuencia NAS con timestamps |
| `lte_auth_detail.txt` | Decodificación `tshark -V` de RAND/AUTN/RES/algoritmos |
| `lte_auth_metrics.csv` | Métricas de attach y autenticación |
| `lte_auth_checks.txt` | Conteos de mensajes y negativos |
| `ue_attach.log` | Log de srsUE |
| `mme_attach.log` | Log del MME |
| `mongo_subscriber.txt` | Suscriptor LTE en MongoDB |
| `ue_usim.txt` | Configuración USIM del UE |

## Reproducir

```bash
# capturar S1AP en el netns de open5gs (sobrevive reinicios de eNB/UE)
docker run -d --name s1authcap --net=container:open5gs \
  --cap-add NET_RAW --cap-add NET_ADMIN \
  -v "$PWD/.lab-tmp:/cap" kali-lab:latest \
  sh -c "timeout 200 tcpdump -i eth0 -s0 -w /cap/s1ap_auth.pcap 'sctp port 36412'"

# recrear par eNB1+UE1 para forzar attach (ver .lab-tmp/d1_recreate_attach.sh)
sh .lab-tmp/d1_recreate_attach.sh
```

## Nota

La captura se tomó en una re-attach de UE1; el `Attach Complete` sale con **EBI 5** gracias al workaround de `srsran/patches/fix_ebi.py`, coherente con el `Attach Accept` de Open5GS.
