FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake build-essential git curl \
    bison flex python3 \
    libmysqlclient-dev libssl-dev libcurl4-openssl-dev \
    libxml2-dev libpcre3-dev libunistring-dev \
    libsctp-dev libmnl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 5.8 https://github.com/kamailio/kamailio.git /kamailio && \
    cd /kamailio && \
    make cfg && \
    make include_modules="db_mysql tls websocket presence ims_registrar_pcscf \
        ims_usrloc_pcscf ims_ipsec_pcscf cdp cdp_avp \
        ims_registrar_scscf ims_usrloc_scscf ims_dialog \
        ims_charging" cfg && \
    make -j$(nproc) && \
    make install

WORKDIR /kamailio

CMD ["/bin/bash"]
