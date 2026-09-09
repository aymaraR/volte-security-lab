# 📡 Laboratorio de seguridad VoLTE sobre Redes 4G/LTE 

> **Propósito académico:** Este repositorio documenta la investigación, herramientas y configuración de un laboratorio virtualizado para el estudio de vulnerabilidades en redes 4G LTE / VoLTE. Todo el trabajo se realiza en un entorno **completamente aislado y controlado**, sin afectar redes reales.

---
 
## ❓ Pregunta a resolver
 
¿De qué manera un entorno de experimentación por software permite identificar y mitigar vulnerabilidades en la señalización (SIP/IMS) y el transporte (RTP) de una red VoLTE, sin comprometer infraestructuras reales de un operador?
 
---
 
## 🧩 Problema
 
Las redes VoLTE combinan varias capas críticas —radio LTE, core de red (EPC), señalización SIP/IMS y transporte de voz (RTP)— y cada una tiene superficies de ataque conocidas (interceptación, denegación de servicio, suplantación de identidad, cifrado débil) que son difíciles y riesgosas de validar directamente sobre una red comercial en producción.
 
---
 
## 💡 Propuesta de solución
 
Un laboratorio 100% software, sin costo de hardware, que emula la cadena VoLTE completa mediante componentes de código abierto (srsRAN en modo ZeroMQ, Open5GS, Kamailio, Asterisk) desplegados en contenedores Docker sobre una red aislada. Sobre ese entorno se ejecutan siete vectores de ataque documentados, cada uno con su procedimiento, métricas de éxito y contramedida validada, siguiendo una metodología reproducible de cuatro fases (reconocimiento, análisis de configuración, explotación, validación de contramedida).
 
---
 
## 🏢 Valor para la empresa
 
- **Validación previa a producción:** permite probar configuraciones y parches de seguridad antes de desplegarlos en la red comercial, reduciendo el riesgo de interrupciones.
- **Evidencia reproducible y verificable:** capturas con hash SHA-256, métricas cuantitativas y logs, útiles para auditorías internas o cumplimiento normativo (GSMA, protección de datos).
- **Entrenamiento del equipo de ciberseguridad:** cada vector de ataque viene con su contramedida exacta, sirviendo como runbook operativo.
- **Reducción de pérdidas económicas:** identificación temprana de vulnerabilidades que podrían derivar en fraude tarifario, robo de identidad o sanciones regulatorias.
- **Costo de infraestructura casi nulo:** al no requerir SDR ni terminales físicos, es replicable y escalable como práctica recurrente del equipo, no solo como ejercicio puntual.
---

## 🆚 Diferencias entre el laboratorio y una red real
 
| Aspecto | Laboratorio | Red real |
|---|---|---|
| Canal de radio | Loopback ZMQ, sin efectos de propagación | RF física con fading, interferencia y movilidad |
| Escala | 1-2 UE emulados | Miles/millones de suscriptores concurrentes |
| Software | Open-source de referencia (srsRAN, Open5GS, Kamailio) | Core comercial certificado con hardening propietario |
| Interconexión | Red bridge aislada, sin exposición externa | Roaming, señalización SS7/Diameter externa, integración OSS/BSS |
| Terminales | UE emulado con credenciales en MongoDB | Smartphones comerciales con USIM certificada |
| Generación | Solo 4G/LTE | Coexistencia con 5G y otras generaciones |
 
Estas diferencias son la razón por la que el desafío original propone, como evolución, una **arquitectura híbrida**: sumar un nodo de acceso inalámbrico real y terminales físicos como paso intermedio entre el laboratorio y la red de producción.

---

## 🗂️ Estructura del Repositorio

```
📦 volte-security-lab/
├── 📄 README.md                        ← Estás aquí
│
├── 📁 docs/
│   ├── 📁 01_investigacion/
│   │   ├── 01_redes_4G_LTE.md          ← Arquitectura y funcionamiento de LTE
│   │   ├── 02_VoLTE.md                 ← Protocolo de voz sobre LTE
│   │   └── 03_vectores_ataque.md       ← Superficie de ataque y vulnerabilidades
│   │
│   ├── 📁 02_herramientas/
│   │   ├── 01_docker.md                ← Contenedores y Docker Compose
│   │   ├── 02_srsRAN_4G.md             ← Emulador de UE y eNB
│   │   ├── 03_open5gs.md               ← Core LTE (EPC)
│   │   ├── 04_kamailio.md              ← Servidor SIP / IMS
│   │   ├── 05_asterisk.md              ← PBX y media server
│   │   ├── 06_kali_linux.md            ← Plataforma de pentesting
│   │   └── 07_wireshark.md             ← Análisis de paquetes
│   │
│   └── 📁 03_arquitectura/
│       ├── 01_diagrama_laboratorio.md  ← Topología del entorno
│       └── 02_flujo_llamada_volte.md   ← Ciclo de vida de una llamada VoLTE
│
└── 📁 Laboratorio/                        ← (Próximamente) Implementación
```

---

## 🎯 Objetivo del Proyecto

Construir y operar un laboratorio de seguridad VoLTE 100% software, aislado y sin costo de hardware, como base para validar los siete vectores de ataque documentados en [`docs/01_investigacion/03_vectores_ataque.md`](docs/01_investigacion/03_vectores_ataque.md).

---
### Componentes del Laboratorio

| Capa | Software | Función |
|---|---|---|
| Radio (RAN) | srsRAN 4G (modo ZMQ) | UE y eNodeB emulados |
| Core de red (EPC) | Open5GS | MME, SGW, PGW, HSS, PCRF |
| Base de datos de suscriptores | MongoDB | Almacena credenciales SIM emuladas |
| IMS | Kamailio + Asterisk + FHoSS | Señalización SIP y media RTP |
| Orquestación | Docker + Docker Compose | Despliegue de contenedores aislados |
| Ataque | Kali Linux (contenedor) | Suite de pentesting |
| Análisis | Wireshark / tshark | Captura y análisis de protocolos |

---

## 📚 Fases del Proyecto

- [x] **Fase 0:** Definición del alcance y objetivos
- [x] **Fase 1:** Investigación teórica (redes 4G LTE y VoLTE)
- [x] **Fase 2:** Documentación de herramientas
- [x] **Fase 3:** Diseño de arquitectura del laboratorio
- [ ] **Fase 4:** Implementación y configuración
- [ ] **Fase 5:** Ejecución de pruebas y análisis de resultados

---

## ⚠️ Advertencia Legal y Ética

Este proyecto es **exclusivamente educativo**. El uso de estas técnicas sobre redes reales sin autorización explícita es **ilegal** y puede derivar en sanciones penales. Todo el laboratorio opera en redes virtuales aisladas, sin espectro radioeléctrico real ni conexión a infraestructura de operadores.

---

## 📖 Cómo Navegar la Documentación

Empieza por [`docs/01_investigacion/01_redes_4G_LTE.md`](docs/01_investigacion/01_redes_4G_LTE.md) para entender la base teórica, luego avanza por las herramientas y la arquitectura antes de ir al directorio `proyecto/`.
