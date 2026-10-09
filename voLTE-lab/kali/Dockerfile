# =============================================================================
# kali/Dockerfile — imagen del contenedor atacante del laboratorio VoLTE.
#
# Rellena un gap del repo: docker-compose.yml referencia `kali-lab:latest` pero
# ningun Dockerfile del repositorio la construia (el "Paso 1" de README.md y
# Readme.md no la incluye), por lo que `docker compose up -d kali` fallaba.
#
# El paquete de herramientas esta fijado por el inventario verificado de
# kali.md (seccion "0. Inventario verificado", 2026-10-02):
#   arpspoof (dsniff) | inviteflood | sipp | python3-scapy | sipsak
#   tshark | sipvicious (svmap/svwar) | tcpdump
#
# LIMITACIONES DEL CONTENEDOR (documentadas en kali.md, no cambiar sin releerlo):
# - SIN procps: no existen `ps`, `pgrep` ni `pkill`. Los scripts de ataque usan
#   `kallikill()` (barrido de /proc/cmdline). Se instala con
#   --no-install-recommends y se marca procps como excluido para reproducirlo.
# - python3 >= 3.13: SIN `audioop` (eliminado en 3.13). Los helpers de audio
#   usan stdlib puro: attacks/v1_mitm_sip/rtp_to_wav.py.
# =============================================================================
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

# 'pidof' (sysvinit-utils) y 'kill' (builtin de bash) son las unicas vias de
# gestion de procesos disponibles; procps queda excluido a proposito.
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      dsniff \
      inviteflood \
      sipp \
      sipsak \
      sipvicious \
      tshark \
      tcpdump \
      python3 \
      python3-scapy \
      python3-pip \
      file \
      less \
      vim-tiny \
      netcat-traditional \
      curl \
      iproute2 \
 && apt-get purge -y -qq procps procps-ng 2>/dev/null || true \
 && apt-get autoremove -y -qq \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*/*

# tshark: sin prompts interactivos en la captura (equivale a --no-root pero el
# contenedor corre como root con NET_RAW, asi que basta con fijar el default).
RUN echo "wireshark-common wireshark-common/install-setuid boolean false" \
      | debconf-set-selections \
 && echo "tshark-common tshark-common/tshark/ui_is_not_root boolean true" \
      | debconf-set-selections

WORKDIR /root

CMD ["/bin/bash"]