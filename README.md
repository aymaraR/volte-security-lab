# 📡 Interceptación de Llamadas VoLTE en Redes 4G LTE — Laboratorio de Seguridad

> **Propósito académico:** Este repositorio documenta la investigación, herramientas y configuración de un laboratorio virtualizado para el estudio de vulnerabilidades en redes 4G LTE / VoLTE. Todo el trabajo se realiza en un entorno **completamente aislado y controlado**, sin afectar redes reales.

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

Construir un **laboratorio de seguridad virtualizado** que simule una red 4G LTE completa con soporte VoLTE, para estudiar y demostrar el vector de ataque de **interceptación de llamadas** usando herramientas de código abierto.

### Componentes del Laboratorio

| Componente | Software | Función |
|---|---|---|
| 📱 Teléfono + Antena | srsRAN 4G | UE (dispositivo) y eNodeB (antena) |
| 🧠 Core de Red (EPC) | Open5GS | MME, SGW, PGW, HSS |
| ☎️ Central IMS | Kamailio + Asterisk | SIP proxy + RTP media |
| 🐉 Atacante | Kali Linux | Herramientas de interceptación |
| 👁️ Visor | Wireshark | Captura y análisis de paquetes |

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
