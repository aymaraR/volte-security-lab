#!/usr/bin/env python3
"""Cliente IMS-AKA minimo para el laboratorio.

Se ejecuta dentro del contenedor pyhss_hss, que ya tiene MILENAGE y PyCryptodome.
No usa baresip ni PJSIP: habla SIP/TLS contra el P-CSCF y demuestra el
intercambio RAND/AUTN -> RES -> Digest AKAv1-MD5.
"""
import base64
import hashlib
import re
import socket
import ssl
import sys
import time

sys.path.insert(0, "/opt/pyhss/lib")
from milenage import Milenage  # noqa: E402

IMPI = "001010123456791@ims.mnc070.mcc999.3gppnetwork.org"
IMPU_USER = "1003"
IMPU = f"sip:{IMPU_USER}@ims.mnc070.mcc999.3gppnetwork.org"
REALM = "ims.mnc070.mcc999.3gppnetwork.org"
PCSCF = ("172.20.0.6", 5061)
LOCAL_IP = "172.20.0.10"
K = bytes.fromhex("00112233445566778899aabbccddeef1")
OPC = bytes.fromhex("63bfa50ee6523365ff14c1f45f88737d")
CALLID = "aka-%d@lab" % int(time.time())
FROMTAG = "aka-%d" % int(time.time() * 1000)
BRANCH = "z9hG4bKaka%d" % int(time.time() * 1000)


def md5(s):
    if isinstance(s, str):
        s = s.encode()
    return hashlib.md5(s).hexdigest()


def header_value(headers, name):
    for k, v in headers:
        if k.lower() == name.lower():
            return v
    return None


def parse_digest(value):
    return {m.group(1).lower(): (m.group(3) if m.group(3) is not None else m.group(2))
            for m in re.finditer(r'(\w+)\s*=\s*(?:"([^"]*)"|([^,\s]+))', value)}


class SipTls:
    def __init__(self):
        raw = socket.create_connection(PCSCF, timeout=15)
        ctx = ssl._create_unverified_context()
        self.s = ctx.wrap_socket(raw, server_hostname="pcscf.ims.mnc070.mcc999.3gppnetwork.org")
        self.buf = b""

    def send(self, text):
        self.s.sendall(text.replace("\n", "\r\n").encode())

    def recv_message(self):
        while b"\r\n\r\n" not in self.buf:
            chunk = self.s.recv(65535)
            if not chunk:
                raise RuntimeError("conexion cerrada")
            self.buf += chunk
        head, rest = self.buf.split(b"\r\n\r\n", 1)
        lines = head.decode(errors="replace").split("\r\n")
        headers = []
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers.append((k.strip(), v.strip()))
        clen = 0
        for k, v in headers:
            if k.lower() == "content-length":
                try:
                    clen = int(v)
                except ValueError:
                    clen = 0
        while len(rest) < clen:
            chunk = self.s.recv(65535)
            if not chunk:
                raise RuntimeError("conexion cerrada en body")
            rest += chunk
        body, self.buf = rest[:clen], rest[clen:]
        return lines[0], headers, body

    def wait_final(self):
        last = None
        while True:
            first, headers, body = self.recv_message()
            m = re.match(r"SIP/2\.0\s+(\d{3})", first)
            code = int(m.group(1)) if m else 0
            last = (code, first, headers, body)
            if code >= 200:
                return last

    def close(self):
        try:
            self.s.close()
        except Exception:
            pass


def register(auth_header=None, cseq=1):
    lines = [
        "REGISTER sip:ims.mnc070.mcc999.3gppnetwork.org SIP/2.0",
        f"Via: SIP/2.0/TLS {LOCAL_IP}:5061;branch={BRANCH};rport",
        f"Route: <sip:172.20.0.6:5061;transport=tls;lr>",
        f"Max-Forwards: 70",
        f"Contact: <sip:{IMPU_USER}@{LOCAL_IP}:5061;transport=tls>;expires=600",
        f"To: <{IMPU}>",
        f"From: <{IMPU}>;tag={FROMTAG}",
        f"Call-ID: {CALLID}",
        f"CSeq: {cseq} REGISTER",
        f"Expires: 600",
        f"User-Agent: AKA-Test",
        f"Allow: INVITE,ACK,BYE,CANCEL,OPTIONS,NOTIFY,SUBSCRIBE,INFO,MESSAGE,REFER",
    ]
    if auth_header:
        lines.append(auth_header)
    lines.append("Content-Length: 0")
    return "\n".join(lines) + "\n\n"


def main():
    sip = SipTls()
    try:
        sip.send(register())
        code, first, headers, _ = sip.wait_final()
        print("REGISTER_1_STATUS=%d" % code)
        print("REGISTER_1_REASON=%s" % first)
        if code != 401:
            print("RESULT=FAIL (se esperaba 401)")
            return 1

        challenge = header_value(headers, "WWW-Authenticate")
        print("WWW_AUTHENTICATE=%s" % challenge)
        d = parse_digest(challenge or "")
        alg = d.get("algorithm", "")
        nonce = d.get("nonce", "")
        realm = d.get("realm", REALM)
        qop = (d.get("qop") or "auth").split(",")[0].strip()
        print("ALGORITHM=%s" % alg)
        if alg.lower() != "akav1-md5":
            print("RESULT=FAIL (el servidor no ofrecio AKAv1-MD5)")
            return 1

        nb = base64.b64decode(nonce + "=" * (-len(nonce) % 4))
        if len(nb) != 32:
            print("RESULT=FAIL (nonce no contiene RAND||AUTN de 32 bytes: %d)" % len(nb))
            return 1
        rand, autn = nb[:16], nb[16:]
        res = Milenage.f2(K, rand, OPC)
        print("RAND=%s" % rand.hex())
        print("AUTN=%s" % autn.hex())
        print("RES=%s" % res.hex())

        cnonce = "abcdef0123456789"
        nc = "00000001"
        uri = "sip:ims.mnc070.mcc999.3gppnetwork.org"
        # En AKAv1-MD5, Kamailio usa el RES binario (8 bytes) como password.
        variant = __import__("os").environ.get("VARIANT", "raw")
        username = IMPI
        password = res
        if variant == "hex":
            password = res.hex()
        elif variant == "hex_upper":
            password = res.hex().upper()
        elif variant == "impu":
            username = f"{IMPU_USER}@ims.mnc070.mcc999.3gppnetwork.org"
        elif variant == "uri_impu":
            uri = IMPU
        ha1 = md5(username.encode() + b":" + realm.encode() + b":" + password)
        ha2 = md5(b"REGISTER:" + uri.encode())
        response = md5(("%s:%s:%s:%s:%s:%s" % (ha1, nonce, nc, cnonce, qop, ha2)).encode())
        auth = (
            'Authorization: Digest username="%s", realm="%s", nonce="%s", '
            'uri="%s", response="%s", algorithm=AKAv1-MD5, cnonce="%s", '
            'nc=%s, qop=%s'
        ) % (username, realm, nonce, uri, response, cnonce, nc, qop)
        if d.get("opaque"):
            auth += ', opaque="%s"' % d["opaque"]
        if header_value(headers, "Security-Server"):
            auth += "\nSecurity-Verify: %s" % header_value(headers, "Security-Server")

        sip.send(register(auth, cseq=2))
        code2, first2, headers2, _ = sip.wait_final()
        print("REGISTER_2_STATUS=%d" % code2)
        print("REGISTER_2_REASON=%s" % first2)
        print("REGISTER_2_WWW=%s" % (header_value(headers2, "WWW-Authenticate") or ""))
        if code2 == 200:
            print("RESULT=PASS (IMS-AKA autenticado)")
            return 0
        print("RESULT=FAIL (segundo REGISTER no fue 200)")
        return 1
    finally:
        sip.close()


if __name__ == "__main__":
    raise SystemExit(main())
