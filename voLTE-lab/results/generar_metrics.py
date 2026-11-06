#!/usr/bin/env python3
"""Consolida metrics.csv a partir de las metricas D0-D3 y evidencias."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
manifest = {}
with (ROOT / 'MANIFEST.csv').open(newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        manifest[row['path']] = row['sha256']

# (test_id, vector, scenario, timestamp, metric, value, unit, source, evidence, result)
data = [
    ('D0-GTP-01', 'D0', 'estable', '2026-11-04T05:48:12Z', 'ping_count', '600', 'paquetes', 'd0_gtp/ping_stability_ue1.log', 'd0_gtp/ping_stability_ue1.log', 'PASS'),
    ('D0-GTP-02', 'D0', 'estable', '2026-11-04T05:48:12Z', 'packet_loss', '0', '%', 'd0_gtp/ping_stability_ue1.log', 'd0_gtp/ping_stability_ue1.log', 'PASS'),
    ('D0-GTP-03', 'D0', 'estable', '2026-11-04T05:48:12Z', 'stability', '600.7', 's', 'd0_gtp/ping_stability_ue1.log', 'd0_gtp/ping_stability_ue1.log', 'PASS'),
    ('D0-GTP-04', 'D0', 'estable', '2026-11-04T05:48:12Z', 'detach_count', '0', 'eventos', 'd0_gtp/open5gs_estabilidad.txt', 'd0_gtp/open5gs_estabilidad.txt', 'PASS'),
    ('D0-CALL-01', 'D0', 'llamada-GTP', '2026-11-04T05:40:04Z', 'call_duration', '15', 's', 'd0_gtp/baresip_dial_1001-1000.log', 'd0_gtp/gtp_dial_1001-1000.pcap', 'PASS'),
    ('D0-CALL-02', 'D0', 'llamada-GTP', '2026-11-04T05:40:04Z', 'active_channels', '1', 'canales', 'd0_gtp/asterisk_channels_post_call.txt', 'd0_gtp/gtp_dial_1001-1000.pcap', 'PASS'),
    ('D0-CALL-03', 'D0', 'llamada-GTP', '2026-11-04T05:40:04Z', 'gtp_teid_ul', '0x5019/0x761a', 'TEID', 'd0_gtp/gtp_teids.txt', 'd0_gtp/gtp_ping_1001-1002.pcap', 'PASS'),
    ('D1-LTE-01', 'D1', 'attach', '2026-11-04T06:03:43Z', 'attach_time', '413.257', 'ms', 'd1_lte_auth/lte_auth_metrics.csv', 'd1_lte_auth/s1ap_attach.pcap', 'PASS'),
    ('D1-LTE-02', 'D1', 'attach', '2026-11-04T06:03:43Z', 'auth_req_to_resp', '33.550', 'ms', 'd1_lte_auth/lte_auth_metrics.csv', 'd1_lte_auth/s1ap_attach.pcap', 'PASS'),
    ('D1-LTE-03', 'D1', 'attach', '2026-11-04T06:03:43Z', 'security_mode', '26.189', 'ms', 'd1_lte_auth/lte_auth_metrics.csv', 'd1_lte_auth/s1ap_attach.pcap', 'PASS'),
    ('D1-LTE-04', 'D1', 'attach', '2026-11-04T06:03:43Z', 'eea', 'EEA0', 'algoritmo', 'd1_lte_auth/lte_auth_detail.txt', 'd1_lte_auth/s1ap_attach.pcap', 'PASS'),
    ('D1-LTE-05', 'D1', 'attach', '2026-11-04T06:03:43Z', 'eia', 'EIA2', 'algoritmo', 'd1_lte_auth/lte_auth_detail.txt', 'd1_lte_auth/s1ap_attach.pcap', 'PASS'),
    ('D1-LTE-06', 'D1', 'attach', '2026-11-04T06:03:43Z', 'ebi', '5', 'EBI', 'd1_lte_auth/lte_auth_sequence.txt', 'd1_lte_auth/s1ap_attach.pcap', 'PASS'),
    ('D2-IMS-01', 'D2', 'register', '2026-11-04T06:37:39Z', 'initial_to_401', '126.006', 'ms', 'd2_ims_auth/ims_auth_metrics.csv', 'd2_ims_auth/ims_auth_clean.pcap', 'PASS'),
    ('D2-IMS-02', 'D2', 'register', '2026-11-04T06:37:39Z', '401_to_200', '126.619', 'ms', 'd2_ims_auth/ims_auth_metrics.csv', 'd2_ims_auth/ims_auth_clean.pcap', 'PASS'),
    ('D2-IMS-03', 'D2', 'register', '2026-11-04T06:37:39Z', 'register_to_200', '252.625', 'ms', 'd2_ims_auth/ims_auth_metrics.csv', 'd2_ims_auth/ims_auth_clean.pcap', 'PASS'),
    ('D2-IMS-04', 'D2', 'negativo', '2026-11-04T06:38:00Z', 'wrong_password', '401', 'status', 'd2_ims_auth/baresip_negative.log', 'd2_ims_auth/ims_auth_negative.pcap', 'PASS'),
    ('D2-IMS-05', 'D2', 'positivo', '2026-11-04T06:38:00Z', 'valid_after_restore', '200', 'status', 'd2_ims_auth/baresip_valid.log', 'd2_ims_auth/ims_auth_clean.pcap', 'PASS'),
    ('D3-V7-01', 'V7', 'vulnerable', '2026-11-04T13:15:04Z', 'channels', '1->0', 'canales', 'v7_d3/v7_vuln_metrics_20261104T131504Z.txt', 'v7_d3/v7_vuln_attack_20261104T131504Z.pcap', 'VULNERABLE'),
    ('D3-V7-02', 'V7', 'vulnerable', '2026-11-04T13:15:04Z', 'bye_packets', '4', 'paquetes', 'v7_d3/v7_bye_packets.txt', 'v7_d3/v7_vuln_attack_20261104T131504Z.pcap', 'VULNERABLE'),
    ('D3-V7-03', 'V7', 'vulnerable', '2026-11-04T13:15:04Z', 'bye_200', '4', 'respuestas', 'v7_d3/v7_bye_packets.txt', 'v7_d3/v7_vuln_attack_20261104T131504Z.pcap', 'VULNERABLE'),
    ('D3-V7-04', 'V7', 'mitigado', '2026-11-04T13:18:37Z', 'channels', '1->1', 'canales', 'v7_d3/v7_mit_metrics_20261104T131837Z.txt', 'v7_d3/v7_mit_attack_20261104T131837Z.pcap', 'MITIGADO'),
    ('D3-V7-05', 'V7', 'mitigado', '2026-11-04T13:18:37Z', 'bye_packets', '3', 'paquetes', 'v7_d3/v7_bye_packets.txt', 'v7_d3/v7_mit_attack_20261104T131837Z.pcap', 'MITIGADO'),
    ('D3-V7-06', 'V7', 'mitigado', '2026-11-04T13:18:37Z', 'bye_403', '3', 'respuestas', 'v7_d3/v7_bye_packets.txt', 'v7_d3/v7_mit_attack_20261104T131837Z.pcap', 'MITIGADO'),
    ('V1-01', 'V1', 'vulnerable', '2026-10-23T01:18:07Z', 'sdp_clear', '4', 'SDP', 'results/README.md', 'v1_mitm_sip_20261023T011807Z.pcapng', 'VULNERABLE'),
    ('V1-02', 'V1', 'vulnerable', '2026-10-23T01:18:07Z', 'rtp_packets', '9980', 'RTP', 'results/README.md', 'v1_audio_20261023T011807Z.wav', 'VULNERABLE'),
    ('V1-03', 'V1', 'mitigado', '2026-10-23T01:41:04Z', 'sdp_clear', '0', 'SDP', 'results/README.md', 'v1_mitm_sip_20261023T014104Z.pcapng', 'MITIGADO'),
    ('V2-01', 'V2', 'vulnerable', '2026-10-23T01:21:39Z', 'rtt_avg', '702', 'ms', 'results/README.md', 'v2_register_3000_20261023T012139Z.csv', 'DEGRADADO'),
    ('V2-02', 'V2', 'vulnerable', '2026-10-23T01:21:39Z', 'rtt_max', '6007', 'ms', 'results/README.md', 'v2_register_3000_20261023T012139Z.csv', 'DEGRADADO'),
    ('V2-03', 'V2', 'mitigado', '2026-10-23T01:42:52Z', 'rtt_avg', '99', 'ms', 'results/README.md', 'v2_register_3000_20261023T014252Z.csv', 'MITIGADO'),
    ('V2-04', 'V2', 'mitigado', '2026-10-23T01:42:52Z', 'rtt_max', '202', 'ms', 'results/README.md', 'v2_register_3000_20261023T014252Z.csv', 'MITIGADO'),
    ('V3-01', 'V3', 'vulnerable', '2026-10-23T01:19:43Z', 'forbidden_403', '0', 'respuestas', 'results/README.md', 'v3_spoof_1001-to-1002_20261023T011943Z.pcapng', 'VULNERABLE'),
    ('V3-02', 'V3', 'mitigado', '2026-10-23T01:51:38Z', 'forbidden_403', '3', 'respuestas', 'results/README.md', 'v3_spoof_1001-to-1002_20261023T015138Z.pcapng', 'MITIGADO'),
]

out = ROOT / 'metrics.csv'
with out.open('w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['test_id', 'vector', 'scenario', 'timestamp_utc', 'metric', 'value',
                'unit', 'source', 'evidence_file', 'sha256', 'result'])
    for row in data:
        test_id, vector, scenario, ts, metric, value, unit, source, evidence, result = row
        w.writerow([test_id, vector, scenario, ts, metric, value, unit, source, evidence,
                    manifest.get(evidence, ''), result])
print(f'metrics.csv: {len(data)} filas')
