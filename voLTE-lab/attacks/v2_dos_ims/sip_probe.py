#!/usr/bin/env python3
"""sip_probe.py — sonda SIP legítima para métricas V2 (reemplaza sipsak).
sipsak no sirve aquí: el S-CSCF no responde OPTIONS y sipsak sale mudo.
Esta sonda envía REGISTER (el S-CSCF siempre responde: 401 = vivo,
503 = saturado) u OPTIONS, mide RTT real y extrae el status-code.
Uso: PROBE_TARGET=172.20.0.6 PROBE_PORT=6060 PROBE_USER=1000 \
     PROBE_DOMAIN=... PROBE_METHOD=REGISTER python3 sip_probe.py
Salida: rtt_ms=<n> status=<200|401|403|503|TIMEOUT>
"""
import os
import random
import socket
import time

TGT = os.environ.get("PROBE_TARGET", "172.20.0.6")
PORT = int(os.environ.get("PROBE_PORT", "6060"))
USER = os.environ.get("PROBE_USER", "1000")
DOMAIN = os.environ.get("PROBE_DOMAIN", "ims.mnc070.mcc999.3gppnetwork.org")
METHOD = os.environ.get("PROBE_METHOD", "REGISTER").upper()
TIMEOUT = float(os.environ.get("PROBE_TIMEOUT", "6"))
SRC = os.environ.get("PROBE_SRC_IP", "172.20.0.99")


def build():
    callid = "probe-%d@%s" % (random.randint(1, 1 << 30), SRC)
    branch = "z9hG4bKprobe%d" % random.randint(1, 1 << 30)
    if METHOD == "REGISTER":
        return (("REGISTER sip:%s SIP/2.0\r\n"
                 "Via: SIP/2.0/UDP %s:5060;branch=%s;rport\r\n"
                 "From: <sip:%s@%s>;tag=probe1\r\n"
                 "To: <sip:%s@%s>\r\n"
                 "Call-ID: %s\r\nCSeq: 1 REGISTER\r\n"
                 "Contact: <sip:probe@%s:5060>\r\n"
                 "Expires: 3600\r\nContent-Length: 0\r\n\r\n")
                % (DOMAIN, SRC, branch, USER, DOMAIN, USER, DOMAIN, callid, SRC)).encode()
    return (("OPTIONS sip:%s@%s SIP/2.0\r\n"
             "Via: SIP/2.0/UDP %s:5060;branch=%s;rport\r\n"
             "From: <sip:probe@%s>;tag=probe1\r\n"
             "To: <sip:%s@%s>\r\n"
             "Call-ID: %s\r\nCSeq: 1 OPTIONS\r\n"
             "Content-Length: 0\r\n\r\n")
            % (USER, DOMAIN, SRC, branch, DOMAIN, USER, DOMAIN, callid)).encode()


def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(TIMEOUT)
    s.bind(("0.0.0.0", 0))
    t0 = time.monotonic()
    s.sendto(build(), (TGT, PORT))
    status, ms = "TIMEOUT", int((time.monotonic() - t0) * 1000)
    try:
        while True:
            data, _ = s.recvfrom(65535)
            ms = int((time.monotonic() - t0) * 1000)
            line = data.decode("utf-8", "replace").split("\r\n", 1)[0]
            if line.startswith("SIP/2.0"):
                status = line.split()[1]
                break
            if ms / 1000 >= TIMEOUT:
                break
    except socket.timeout:
        ms = int((time.monotonic() - t0) * 1000)
    print("rtt_ms=%d status=%s" % (ms, status))


if __name__ == "__main__":
    main()
