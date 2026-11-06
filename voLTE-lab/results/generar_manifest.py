#!/usr/bin/env python3
"""Genera MANIFEST.csv y hashes.txt a partir de results/."""
import csv
import hashlib
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXCLUDE = {
    'MANIFEST.csv', 'hashes.txt', 'hashes_historico.txt',
    'generar_manifest.py', 'verificar.py', 'verificar.sh',
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def classify(rel: str):
    p = rel.replace('\\', '/')
    name = Path(p).name
    if p.startswith('d0_gtp/'):
        return 'D0', 'GTP-U', 'captura/log D0'
    if p.startswith('d1_lte_auth/'):
        return 'D1', 'LTE', 'captura/log D1'
    if p.startswith('d2_ims_auth/'):
        return 'D2', 'IMS', 'captura/log D2'
    if p.startswith('v7_d3/'):
        scenario = 'mitigado' if 'v7_mit' in p else 'vulnerable'
        if 'dialog' in p:
            scenario += '-dialogo'
        elif 'attack' in p:
            scenario += '-ataque'
        return 'V7-D3', scenario, 'evidencia V7 D3'
    if p.startswith('v6_d3/'):
        scenario = 'mitigado' if 'v6_mit' in p else ('vulnerable' if 'v6_vuln' in p else 'descubrimiento')
        return 'V6-D3', scenario, 'evidencia V6 D3'
    if p.startswith('aka_d3/'):
        return 'AKA-D3', 'autenticacion', 'evidencia IMS-AKA'
    if p.startswith('v5_d3/'):
        return 'V5-D3', 'no-reproducible', 'evidencia V5 D3'
    if name.startswith('v1_'):
        scenario = 'mitigado' if '014104' in name else 'vulnerable'
        return 'V1', scenario, 'evidencia V1'
    if name.startswith('v2_'):
        scenario = 'mitigado' if '014252' in name else 'vulnerable'
        return 'V2', scenario, 'evidencia V2'
    if name.startswith('v3_'):
        scenario = 'mitigado' if '015138' in name else 'vulnerable'
        return 'V3', scenario, 'evidencia V3'
    if name.startswith('v5_'):
        return 'V5', 'ejecutado', 'evidencia V5'
    if name.startswith('v7_'):
        scenario = 'mitigado' if '014557' in name else 'vulnerable'
        return 'V7', scenario, 'evidencia V7 histórica'
    if name.startswith('baseline'):
        return 'baseline', 'referencia', 'RTP de referencia'
    return 'DOC', 'final', 'documento'


def timestamp(rel: str, path: Path) -> str:
    m = re.search(r'(20\d{6})T(\d{6})Z', rel)
    if m:
        return f'{m.group(1)[:4]}-{m.group(1)[4:6]}-{m.group(1)[6:]}T{m.group(2)[:2]}:{m.group(2)[2:4]}:{m.group(2)[4:]}Z'
    return datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


rows = []
for path in sorted(ROOT.rglob('*')):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix()
    if rel in EXCLUDE:
        continue
    vector, scenario, source = classify(rel)
    rows.append({
        'path': rel,
        'vector': vector,
        'scenario': scenario,
        'timestamp_utc': timestamp(rel, path),
        'size_bytes': path.stat().st_size,
        'sha256': sha256(path),
        'status': 'present',
        'source': source,
        'notes': '',
    })

manifest = ROOT / 'MANIFEST.csv'
with manifest.open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

with (ROOT / 'hashes.txt').open('w', encoding='utf-8', newline='\n') as f:
    f.write('# hashes.txt - SHA-256 del set final (generado desde MANIFEST.csv).\n')
    f.write('# Formato: <sha256>  <archivo>  <vector>  <timestamp-UTC>  <descripcion>\n')
    f.write('# Historico completo: hashes_historico.txt\n')
    for r in rows:
        f.write(f"{r['sha256']}  {r['path']}  {r['vector']}  {r['timestamp_utc']}  {r['scenario']}\n")

print(f'MANIFEST.csv: {len(rows)} archivos')
print(f'hashes.txt: {len(rows)} entradas')
