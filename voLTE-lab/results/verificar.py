#!/usr/bin/env python3
"""Verifica MANIFEST.csv contra los archivos de results/."""
import csv
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / 'MANIFEST.csv'


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


if not MANIFEST.exists():
    print('FALTA MANIFEST.csv')
    sys.exit(2)

ok = 0
missing = []
mismatch = []
with MANIFEST.open(newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        path = ROOT / row['path']
        if not path.is_file():
            missing.append(row['path'])
        elif sha256(path) != row['sha256']:
            mismatch.append(row['path'])
        else:
            ok += 1

print(f'OK: {ok}')
print(f'FALTANTES: {len(missing)}')
for p in missing:
    print('  FALTA', p)
print(f'DIFERENTES: {len(mismatch)}')
for p in mismatch:
    print('  DIFERENTE', p)

sys.exit(1 if (missing or mismatch) else 0)
