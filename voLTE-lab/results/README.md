# Evidencia del laboratorio — set de cierre (2026-11-04)

Este directorio contiene la evidencia final de los vectores V1–V3, V5, V6, V7,
IMS-AKA y de las fases D0–D5 del cierre. El registro histórico completo está en
`hashes_historico.txt`; la fuente de verdad actual es `MANIFEST.csv` +
`hashes.txt` + `verificar.py`.

## Set final

| Bloque | Escenario | Evidencia | Qué prueba |
|---|---|---|---|
| D0 | GTP-U estable | `d0_gtp/gtp_ping_1001-1002.pcap`, `ping_stability_ue1.log` | 600/600 pings, 0 % pérdida; TEIDs UL/DL |
| D0 | Llamada por GTP | `d0_gtp/gtp_dial_1001-1000.pcap`, `baresip_dial_1001-1000.log` | Llamada 15 s, SRTP, Echo, 254 181 bytes GTP |
| D1 | Auth LTE | `d1_lte_auth/s1ap_attach.pcap`, `lte_auth_metrics.csv` | Attach 413 ms; RAND/AUTN/RES; EEA0/EIA2 |
| D2 | Auth IMS | `d2_ims_auth/ims_auth_clean.pcap`, `ims_auth_negative.pcap` | 401→200 en 126.6 ms; password mala → 401 |
| D3 | V7 vulnerable | `v7_d3/v7_vuln_{dialog,attack}_*.pcap` | 4 BYE + 4×200; llamada 1→0 |
| D3 | V7 mitigado | `v7_d3/v7_mit_{dialog,attack}_*.pcap` | 3 BYE + 3×403; llamada 1→1 |
| D5 | V7 vulnerable limpio | `v7_d3/v7_vuln_*T135125Z.pcap` | Re-ejecución limpia: 4 BYE + 4×200; 1→0 |
| D5 | V7 mitigado limpio | `v7_d3/v7_mit_*T134934Z.pcap` | Re-ejecución limpia: 3 BYE + 3×403; 1→1 |
| V1 | vulnerable | `v1_mitm_sip_20261023T011807Z.pcapng` + `v1_audio_20261023T011807Z.wav` | 2 INVITE, 4 SDP en claro, 9 980 RTP, audio 99,8 s |
| V1 | mitigado | `v1_mitm_sip_20261023T014104Z.pcapng` | 0 INVITE/SDP en claro; media SRTP |
| V2 | vulnerable | `v2_register_3000_20261023T012139Z.{pcapng,csv}` | avg 702 ms, max 6 007 ms, 1 timeout |
| V2 | mitigado | `v2_register_3000_20261023T014252Z.{pcapng,csv}` | pike: 403 al atacante; sonda neutral estable |
| V3 | vulnerable | `v3_spoof_1001-to-1002_20261023T011943Z.pcapng` | INVITE forjado contestado, sin 403 |
| V3 | mitigado | `v3_spoof_1001-to-1002_20261023T015138Z.pcapng` | 3×403 `Identity Origin Mismatch` |
| V5 | vulnerable condicionado | `v5_d3/v5_success_*.log` | PCI 7 + attach OK; 3 corridas previas sin sync |
| V6 | vulnerable | `v6_d3/v6_vuln_*.pcap` | TEID 0x2; 5 inyecciones, 5 respuestas ICMP de la UE |
| V6 | mitigado | `v6_d3/v6_mit_*.pcap` | Filtro `tc` en eNB: 0 respuestas |
| AKA | autenticado | `aka_d3/aka_*.pcap` | 401 AKAv1-MD5 -> 200 con RES real (1003) |
| baseline | referencia | `baseline_rtp_1001-1000.pcapng` | G.711, 897 paquetes/flujo, 0 % loss |

## Alcance V4/V6

- **V4 (cifrado EEA0): sustituido por V7** a solicitud de la empresa. No es
  criterio de cierre; `vectores/v4_cipher.sh` queda como anexo opcional.
- **V6 (GTP-U injection): ejecutado en alcance extendido**; vulnerable y mitigado en `v6_d3/`.

## Integridad

- `MANIFEST.csv`: archivo, vector, escenario, timestamp, tamaño, SHA-256.
- `hashes.txt`: formato histórico `<sha256>  <archivo>  <vector>  <timestamp>  <descripción>`.
- `verificar.py` / `verificar.sh`: recalculan y comparan; fallan si algo no coincide.
- `hashes_historico.txt`: registro previo completo, incluidas corridas archivadas.
- Nota: el hash antiguo de V5 no coincidía con el archivo presente; el manifiesto
  actual registra el hash real. El anterior se conserva en el histórico.

## Reproducir

```bash
cd voLTE-lab
./lab-up.sh
docker compose up -d kali
python3 results/verificar.py
```

Para V7:

```bash
sh parches/revertir.sh
sh vectores/v7_cierre.sh vuln
sh scripts/restaurar_mitigado.sh
sh vectores/v7_cierre.sh mit
```
