# V6 — Inyección GTP-U en S1-U

**Fecha:** 2026-11-04  
**Escenario:** UE 1001 (`10.45.0.5`), S1-U entre eNB `172.20.0.4` y SGW-U `172.20.0.3`.  
**Script:** `vectores/v6_gtp_cierre.sh`

## 1. Descubrimiento

Se capturó S1-U en `open5gs` (`eth0:2152`) mientras la UE hacía ping al gateway:

- TEID downlink real: `0x00000002`
- IP interna de la UE: `10.45.0.5`
- Evidencia: `v6_discovery_20261104T142318Z.pcap`

## 2. V6 vulnerable

Kali `172.20.0.99` inyectó 5 GTP-U T-PDU hacia el eNB (`172.20.0.4:2152`) con
el TEID downlink y un ICMP echo request interno `10.45.0.1 -> 10.45.0.5`,
payload `V6-INJECT`.

| Métrica | Valor |
|---|---|
| Intentos | 5 |
| Vistos en eNB | 5 |
| Respuestas ICMP de la UE en eNB | 5 |
| Respuestas ICMP en S1-U/UPF | 5 |
| Veredicto | **VULNERABLE** |

Evidencia:
- `v6_vuln_enb_20261104T142318Z.pcap`
- `v6_vuln_upf_20261104T142318Z.pcap`
- `v6_vuln_metrics_20261104T142318Z.txt`

## 3. Contramedida y re-prueba

Se aplicó un filtro `tc flower` en el eNB: solo se permite GTP-U desde el
SGW-U `172.20.0.3`; el resto se descarta.

| Métrica | Valor |
|---|---|
| Intentos | 5 |
| Vistos en ingress del eNB (captura previa al filtro) | 5 |
| Respuestas de la UE | 0 |
| Respuestas en S1-U/UPF | 0 |
| Veredicto | **MITIGADO** |

Evidencia:
- `v6_mit_enb_20261104T142318Z.pcap`
- `v6_mit_upf_20261104T142318Z.pcap`
- `v6_mit_metrics_20261104T142318Z.txt`

> `injected_seen_enb=5` en la fase mitigada es esperado: el punto de captura
> `tcpdump` ve el paquete antes de la clasificación `tc`. El impacto real es
> cero porque no hay respuesta de la UE ni tráfico en S1-U.

## 4. Reproducción

```sh
sh vectores/v6_gtp_cierre.sh
```

Requiere laboratorio UP con 1001 attachado. No altera D2.
