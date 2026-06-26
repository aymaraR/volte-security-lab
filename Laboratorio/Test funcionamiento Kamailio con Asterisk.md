# Integración IMS — Kamailio + Asterisk

Una vez que las imágenes de Kamailio y Asterisk están construidas y el `docker-compose.yml` está corriendo, este paso configura y arranca los tres nodos IMS de Kamailio (P-CSCF, I-CSCF, S-CSCF) y verifica que Asterisk se registra correctamente en el S-CSCF.

## Requisitos previos

- Todos los contenedores corriendo: `docker ps` debe mostrar 6 servicios `Up`
- Imágenes disponibles: `kamailio-ims:latest` y `asterisk-ims:latest`

## Archivos de configuración

Los archivos de configuración ya están copiados al contenedor `kamailio` en sesiones anteriores. Si el contenedor fue recreado con `--force-recreate` o `docker compose down`, hay que volver a copiarlos desde WSL2:

```bash
docker cp ~/voLTE-lab/kamailio/scscf/scscf.cfg kamailio:/usr/local/etc/kamailio/scscf.cfg
docker cp ~/voLTE-lab/kamailio/scscf/scscf_diameter.xml kamailio:/usr/local/etc/kamailio/scscf_diameter.xml
docker cp ~/voLTE-lab/kamailio/icscf/icscf.cfg kamailio:/usr/local/etc/kamailio/icscf.cfg
docker cp ~/voLTE-lab/kamailio/icscf/icscf_diameter.xml kamailio:/usr/local/etc/kamailio/icscf_diameter.xml
docker cp ~/voLTE-lab/kamailio/pcscf/pcscf.cfg kamailio:/usr/local/etc/kamailio/pcscf.cfg
docker cp ~/voLTE-lab/asterisk/pjsip.conf asterisk:/etc/asterisk/pjsip.conf
docker cp ~/voLTE-lab/asterisk/extensions.conf asterisk:/etc/asterisk/extensions.conf
```

> ⚠️ Ningún contenedor tiene bind mount — los configs se pierden si el contenedor se recrea.

## Arquitectura de puertos IMS

| Rol | Puerto | IP |
|---|---|---|
| P-CSCF | 4060 UDP/TCP | 172.20.0.6 |
| I-CSCF | 5060 UDP/TCP | 172.20.0.6 |
| S-CSCF | 6060 UDP/TCP | 172.20.0.6 |
| Asterisk TAS | 5061 UDP | 172.20.0.7 |

## Ejecución — requiere 4 terminales simultáneas

Abre 4 ventanas de la app "Ubuntu" (sin cerrar las anteriores).

**Terminal 1 — S-CSCF (arrancar primero):**
```bash
docker exec -it kamailio kamailio -DD -E -e -f /usr/local/etc/kamailio/scscf.cfg
```
Espera a ver `Listening on udp: 172.20.0.6:6060` antes de continuar.

**Terminal 2 — P-CSCF:**
```bash
docker exec -it kamailio kamailio -DD -E -e -f /usr/local/etc/kamailio/pcscf.cfg
```

**Terminal 3 — I-CSCF:**
```bash
docker exec -it kamailio kamailio -DD -E -e -f /usr/local/etc/kamailio/icscf.cfg
```

**Terminal 4 — Asterisk:**
```bash
docker exec -it asterisk asterisk -cvvv
```

## Warnings esperados e inofensivos

**En S-CSCF e I-CSCF:**
```
WARNING: cdp [receiver.c:993]: peer_connect(): Error opening connection to
hss.ims.mnc070.mcc999.3gppnetwork.org:3868 > Name or service not known
```
El HSS IMS via Diameter (interfaz Cx) no está configurado aún. No bloquea el funcionamiento básico.

**En P-CSCF:**
```
ERROR: ims_ipsec_pcscf [ipsec.c:652]: clean_sa(): Error sending delete SAs command
WARNING: ims_ipsec_pcscf [cmd.c:1406]: ipsec_cleanall(): Error cleaning IPSec Security associations
```
No hay kernel IPSec en Docker. Inofensivo en un lab con radio simulada ZMQ.

**En Asterisk:**
```
ERROR: res_config_pgsql.c: Failed to connect database asterisk
ERROR: cel_tds declined to load.
ERROR: cdr_radius declined to load.
```
Módulos que no se usan en este lab. Inofensivos.

## Verificación

Una vez que los 4 procesos estén corriendo, en la Terminal 4 donde aparece el prompt `*CLI>` de Asterisk, escribe:

```
pjsip show registrations
```

## Resultado esperado

```
Asterisk Ready.
*CLI>   == Endpoint scscf is now Reachable
    -- Contact scscf/sip:172.20.0.6:6060 is now Reachable.  RTT: 74.832 msec
*CLI> pjsip show registrations
 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================
 scscf-reg/sip:172.20.0.6:6060                           scscf-auth                  Registered        (exp. 3510s)
Objects found: 1
```

Esto confirma que:
- Asterisk alcanza el S-CSCF ✅
- Asterisk está registrado en el S-CSCF como TAS ✅
- El stack IMS completo está operativo ✅

## Siguiente paso

Con el IMS funcionando, el paso siguiente es levantar el eNB y UE (srsRAN), hacer el attach LTE, y configurar un cliente SIP en el UE para registrarse en IMS vía P-CSCF y probar una llamada VoLTE end-to-end.
