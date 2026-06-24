# ☎️ Herramienta: Kamailio

## 1. ¿Qué es Kamailio?

**Kamailio** es un servidor SIP de código abierto de alto rendimiento, originalmente conocido como OpenSER. En el contexto de IMS, actúa como el **P-CSCF / S-CSCF**, siendo el núcleo de señalización de la central telefónica IMS.

- **Licencia:** GPLv2
- **Repositorio:** https://github.com/kamailio/kamailio
- **Lenguaje:** C
- **Versión actual:** 5.x

---

## 2. Rol en el Laboratorio

```
[ srsUE ] ──(SIP REGISTER)──> [ Kamailio: P-CSCF / S-CSCF ]
                                           |
                               (SIP INVITE routing)
                                           |
                              [ Asterisk (B2BUA/media) ]
```

Kamailio gestiona:
- Registro de usuarios SIP (REGISTER)
- Enrutamiento de llamadas (INVITE, BYE)
- Autenticación SIP (Digest Auth)
- Interconexión con el HSS de Open5GS (Cx/Dx mediante Diameter o base de datos local)

---

## 3. Arquitectura de Módulos

Kamailio funciona mediante módulos cargables. Los principales para IMS:

| Módulo | Función |
|---|---|
| `registrar` | Gestión de registros SIP (REGISTER) |
| `usrloc` | Base de datos de ubicaciones de usuarios |
| `auth_db` | Autenticación digest contra base de datos |
| `dispatcher` | Balanceo y enrutamiento hacia Asterisk |
| `tm` (transaction) | Manejo de transacciones SIP |
| `sl` (stateless) | Respuestas sin estado |
| `rr` (record-route) | Mantener el camino de la sesión |
| `ims_registrar_pcscf` | Lógica específica P-CSCF |
| `ims_registrar_scscf` | Lógica específica S-CSCF |
| `cdp` | Interfaz Diameter (para HSS) |

---

## 4. Configuración Básica — kamailio.cfg

```c
# kamailio.cfg — configuración mínima para laboratorio IMS

#!KAMAILIO

####### Global Parameters #########
debug=2
log_stderror=yes
log_facility=LOG_LOCAL0
fork=yes
children=4

listen=udp:172.21.0.10:5060
listen=tcp:172.21.0.10:5060

####### Modules Section ########
loadmodule "tm.so"
loadmodule "sl.so"
loadmodule "rr.so"
loadmodule "registrar.so"
loadmodule "usrloc.so"
loadmodule "auth.so"
loadmodule "auth_db.so"
loadmodule "dispatcher.so"

modparam("usrloc", "db_mode", 0)    # 0 = solo memoria (laboratorio)
modparam("auth_db", "db_url", "mysql://kamailio:password@db/kamailio")
modparam("dispatcher", "list_file", "/etc/kamailio/dispatcher.list")

####### Routing Logic ########
request_route {
    # Mantener ruta de la sesión
    if (is_method("REGISTER")) {
        if (!save("location")) {
            sl_reply_error();
        }
        exit;
    }

    if (is_method("INVITE")) {
        record_route();
        # Enrutar hacia Asterisk
        if (!ds_select_dst("1", "4")) {
            send_reply("503", "Service Unavailable");
            exit;
        }
    }

    t_relay();
}
```

---

## 5. Dispatcher — Lista de Destinos

`/etc/kamailio/dispatcher.list`

```
# Grupo 1: Asterisk media server
1 sip:172.21.0.20:5060
```

---

## 6. Instalación con Docker

```yaml
services:
  kamailio:
    image: kamailio/kamailio-ci:5.7-bullseye
    container_name: kamailio
    volumes:
      - ./config/kamailio:/etc/kamailio
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp"
    networks:
      ims-net:
        ipv4_address: 172.21.0.10
```

---

## 7. Herramientas de Diagnóstico

```bash
# Verificar que Kamailio está escuchando
ss -ulnp | grep 5060

# Ver registros SIP activos
kamctl ul show

# Enviar un SIP OPTIONS de prueba (desde otro contenedor)
sipsak -s sip:172.21.0.10

# Activar debug en vivo
kamctl fifo debug 4
```

---

## 8. Recursos

- Documentación oficial: https://www.kamailio.org/wiki/
- Kamailio IMS tutorial: https://www.kamailio.org/docs/tutorials/
- GitHub: https://github.com/kamailio/kamailio
