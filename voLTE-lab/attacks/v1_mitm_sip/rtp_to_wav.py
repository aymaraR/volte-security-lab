#!/usr/bin/env python3
"""rtp_to_wav.py — Reconstruye audio desde payloads RTP extraídos con tshark.

Reemplazo de rtpbreak (no disponible en kali): solo usa stdlib
(sin audioop: implementa G.711 en Python puro, funciona en 3.13+).

Entrada: archivo de texto con líneas producidas por:
  tshark -r CAP.pcapng -Y rtp -T fields -e rtp.ssrc -e rtp.p_type -e rtp.payload
  (formato: SSRC<TAB>PT<TAB>payload_hex)

Proceso: agrupa por (SSRC, PT), elige el flujo con más paquetes y decodifica
  PT 0 (PCMU/G711u) y PT 8 (PCMA/G711a).
Salida: WAV mono 8 kHz 16-bit + estadísticas por stdout.

Uso: python3 rtp_to_wav.py rtp.txt salida.wav
"""
import struct
import sys
import wave
from collections import defaultdict


def ulaw2lin(b):
    b = (~b) & 0xFF
    sign = b & 0x80
    exp = (b >> 4) & 0x07
    mant = b & 0x0F
    sample = (((mant << 3) + 0x84) << exp) - 0x84
    return -sample if sign else sample


def alaw2lin(b):
    b ^= 0x55
    sign = b & 0x80
    exp = (b >> 4) & 0x07
    mant = b & 0x0F
    if exp == 0:
        sample = (mant << 4) + 8
    else:
        sample = ((mant << 4) + 0x108) << (exp - 1)
    return sample if sign else -sample


def main():
    if len(sys.argv) != 3:
        print("uso: rtp_to_wav.py <rtp.txt> <salida.wav>", file=sys.stderr)
        return 1
    flows = defaultdict(list)
    total = 0
    with open(sys.argv[1], "r", errors="replace") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3 or not parts[2].strip():
                continue
            ssrc, pt, hexpay = parts[0].strip(), parts[1].strip(), parts[2].strip()
            try:
                raw = bytes.fromhex(hexpay)
            except ValueError:
                continue
            if pt not in ("0", "8"):
                continue  # solo G711u/a; otros codecs se omiten
            flows[(ssrc, pt)].append(raw)
            total += 1
    if not flows:
        print("sin payloads G711 (PT 0/8) en %s (lineas RTP totales: %d)" % (sys.argv[1], total))
        return 2
    for key in sorted(flows, key=lambda k: len(flows[k])):
        print("flujo ssrc=%s pt=%s pkts=%d" % (key[0], key[1], len(flows[key])))
    (ssrc, pt), pkts = max(flows.items(), key=lambda kv: len(kv[1]))
    decode = ulaw2lin if pt == "0" else alaw2lin
    pcm = b"".join(struct.pack("<%dh" % len(p), *[decode(x) for x in p]) for p in pkts)
    with wave.open(sys.argv[2], "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(8000)
        w.writeframes(pcm)
    secs = len(pcm) / 2 / 8000
    print("OK ssrc=%s pt=%s pkts=%d salida=%s dur=%.1fs" % (ssrc, pt, len(pkts), sys.argv[2], secs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
