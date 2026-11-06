# IMS-AKA real (AKAv1-MD5)

**Fecha:** 2026-11-04  
**Identidad:** IMPU `sip:1003@ims.mnc070.mcc999.3gppnetwork.org`  
**IMPI:** `001010123456791@ims.mnc070.mcc999.3gppnetwork.org`  
**Cliente:** `scripts/ims_aka_client.py` (SIP/TLS + MILENAGE, ejecutado en `pyhss_hss`).

## Resultado

| Paso | Resultado |
|---|---|
| REGISTER inicial | `401 Unauthorized` |
| Algoritmo ofrecido | `AKAv1-MD5` |
| Nonce | `base64(RAND || AUTN)` |
| RES calculado con K/OPc | 8 bytes |
| Segundo REGISTER | `200 OK` |
| Veredicto | **PASS** |

## Evidencia

- `aka_client_20261104T143936Z.log`: 401, RAND/AUTN, RES y 200.
- `aka_sip_20261104T143936Z.pcap`: REGISTER inicial, 401, REGISTER con `Authorization`, 200.
- `aka_cx_20261104T143936Z.pcap`: MAR/MAA en Cx.
- `aka_cx_values_20261104T143936Z.txt`: `SIP-Authenticate` (RAND+AUTN) y
  `SIP-Authorization` (XRES) del HSS.
- `aka_metrics_20261104T143936Z.txt`: resumen y 1001/D2 intacto.

## Nota técnica

Kamailio `ims_auth` usa el **RES binario de 8 bytes** como password en
`H(A1)=MD5(IMPI:realm:RES)`. Por eso un cliente que use `RES` en hexadecimal
falla aunque el vector sea correcto.

1003 es una identidad exclusiva de esta prueba; 1001/1002 siguen usando
Digest-MD5 con baresip. No se implementó IPsec/Gm; el alcance es la
autenticación AKA, no el establecimiento de SA de seguridad.

## Reproducción

```sh
sh vectores/aka_cierre.sh
```
