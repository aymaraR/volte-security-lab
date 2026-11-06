import json
import urllib.request

BASE = 'http://127.0.0.1:8080'


def get(path):
    with urllib.request.urlopen(BASE + path, timeout=10) as r:
        text = r.read().decode()
        return json.loads(text) if text and text != 'null' else None


def put(path, payload):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(payload).encode(),
        headers={'Content-Type': 'application/json'},
        method='PUT',
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode())


# APN por defecto para los suscriptores IMS
apns = get('/apn/list') or []
if apns:
    apn_id = apns[0]['apn_id']
else:
    apn_id = put('/apn/', {
        'apn': 'srsapn',
        'ip_version': 0,
        'apn_ambr_dl': 1000000,
        'apn_ambr_ul': 1000000,
        'qci': 9,
    })['apn_id']

for imsi, msisdn, k in [
    ('001010123456789', '1001', '00112233445566778899aabbccddeeff'),
    ('001010123456790', '1002', '00112233445566778899aabbccddeef0'),
    # Suscriptor exclusivo para la prueba IMS-AKA (no interfiere con baresip).
    ('001010123456791', '1003', '00112233445566778899aabbccddeef1'),
]:
    auc = get('/auc/imsi/' + imsi)
    if auc:
        auc_id = auc['auc_id']
    else:
        auc_id = put('/auc/', {
            'imsi': imsi,
            'ki': k,
            'opc': '63bfa50ee6523365ff14c1f45f88737d',
            'amf': '8000',
            'sqn': 0,
        })['auc_id']

    if not get('/subscriber/imsi/' + imsi):
        put('/subscriber/', {
            'imsi': imsi,
            'msisdn': msisdn,
            'auc_id': auc_id,
            'default_apn': apn_id,
            'apn_list': str(apn_id),
        })
        print('subscriber created', imsi, flush=True)

print('IMS auth provisioning OK', flush=True)
