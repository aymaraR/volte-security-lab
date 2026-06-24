# 🧠 Herramienta: Open5GS

## 1. ¿Qué es Open5GS?

**Open5GS** es una implementación de código abierto del **EPC (Evolved Packet Core) LTE** y del **5GC (5G Core)**. Desarrollado principalmente por Sukchan Lee, permite desplegar un core de red móvil completo en software.

- **Licencia:** AGPLv3
- **Repositorio:** https://github.com/open5gs/open5gs
- **Lenguaje:** C
- **Versiones:** LTE (4G EPC) y 5G SA

---

## 2. Componentes del EPC en Open5GS

| Proceso | Función LTE | Interfaz |
|---|---|---|
| **MME** | Mobility Management Entity — señalización NAS, autenticación | S1-MME, S6a, S11 |
| **SGW-C** | Serving GW (Control) — control de sesiones | S11, S5 |
| **SGW-U** | Serving GW (User) — plano de usuario | S1-U, S5-U |
| **PGW-C / SMF** | PDN GW (Control) — políticas, direccionamiento IP | S5, Gx |
| **PGW-U / UPF** | PDN GW (User) — forwarding de paquetes | S5-U, SGi |
| **HSS** | Home Subscriber Server — base de datos de suscriptores | S6a (Diameter) |
| **PCRF** | Policy and Charging Rules — QoS y billing | Gx |

---

## 3. Open5GS WebUI — Gestión de Suscriptores

Open5GS incluye una interfaz web para gestionar suscriptores (equivalente al HLR/HSS de un operador real).

```bash
# Acceder a WebUI (por defecto en puerto 9999)
http://localhost:9999

# Credenciales por defecto
usuario: admin
contraseña: 1423
```

### Agregar un suscriptor (SIM virtual)

Desde la WebUI:
1. **Subscribers → Add Subscriber**
2. Completar:
   - **IMSI:** `001010123456780`
   - **Subscriber Key (K):** `00112233445566778899AABBCCDDEEFF`
   - **OPC:** `63BFA50EE6523365FF14C1F45F88737D`
   - **APN:** `internet`

> Los valores de IMSI, K y OPC deben coincidir exactamente con la configuración del srsUE.

---

## 4. Configuración del MME

Archivo: `/etc/open5gs/mme.yaml`

```yaml
mme:
  freeDiameter: /etc/freeDiameter/mme.conf
  s1ap:
    - addr: 172.20.0.10      # IP donde escucha conexiones del eNB
  gtpc:
    - addr: 172.20.0.10
  gummei:
    plmn_id:
      mcc: 001               # Debe coincidir con srsENB
      mnc: 01
    mme_gid: 2
    mme_code: 1
  tai:
    plmn_id:
      mcc: 001
      mnc: 01
    tac: 1
  security:
    integrity_order : [ EIA2, EIA1, EIA0 ]
    ciphering_order : [ EEA0, EEA1, EEA2 ]  # EEA0 = sin cifrado (laboratorio)
  network_name:
    full: TestNetwork
  mme_name: open5gs-mme0
```

---

## 5. Configuración para IMS / VoLTE

Para habilitar VoLTE, el MME debe anunciar soporte IMS al UE:

```yaml
# En mme.yaml, agregar sección IMS
  sms:
    - addr: 127.0.0.2   # SMS over IMS (opcional)

# PCRF debe habilitar QCI 1 y QCI 5 para VoLTE
```

El PGW debe crear bearers dedicados para IMS (QCI 5) automáticamente cuando el UE registra con el APN `ims`.

---

## 6. Instalación con Docker

```yaml
# Fragmento docker-compose.yml para Open5GS
services:
  open5gs:
    image: gradiant/open5gs:2.7.0
    container_name: open5gs
    environment:
      - COMPONENT_NAME=mme-sgw-pgw-smf-upf-hss-pcrf
      - MCC=001
      - MNC=01
      - MME_S1AP_IP=172.20.0.10
      - SMF_GTPC_IP=172.20.0.10
    volumes:
      - ./config/open5gs:/etc/open5gs
    cap_add:
      - NET_ADMIN
    networks:
      lte-core:
        ipv4_address: 172.20.0.10
```

---

## 7. Monitoreo y Logs

```bash
# Ver logs del MME en tiempo real
docker exec -it open5gs tail -f /var/log/open5gs/mme.log

# Verificar que el eNB se conectó correctamente
# Debe aparecer: "eNB-S1 accepted"
grep "eNB-S1" /var/log/open5gs/mme.log

# Verificar attach de UE
grep "UE IMSI" /var/log/open5gs/mme.log
```

---

## 8. Recursos

- Documentación oficial: https://open5gs.org/open5gs/docs/
- GitHub: https://github.com/open5gs/open5gs
- Guía de instalación en Ubuntu: https://open5gs.org/open5gs/docs/guide/02-building-open5gs-from-sources/
