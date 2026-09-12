FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential git curl wget \
    libssl-dev libncurses5-dev libnewt-dev \
    libxml2-dev libsqlite3-dev uuid-dev \
    libjansson-dev libedit-dev \
    libsrtp2-dev libopus-dev \
    python3 python3-pip \
    iproute2 iputils-ping net-tools \
    libasound2-dev libcurl4-openssl-dev \
    libvorbis-dev libogg-dev \
    libspandsp-dev libgsm1-dev \
    libbluetooth-dev libradcli-dev \
    libcorosync-common-dev libcpg-dev \
    libiksemel-dev libneon27-dev \
    libgmime-3.0-dev liblua5.2-dev \
    libpopt-dev libresample1-dev \
    libc-client2007e-dev binutils-dev \
    libsybdb5 freetds-dev \
    libpq-dev unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cd /usr/src && \
    wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-21-current.tar.gz && \
    tar xzf asterisk-21-current.tar.gz && \
    cd asterisk-21*/ && \
    ./configure --with-jansson-bundled && \
    make -j$(nproc) && \
    make install && \
    make samples

WORKDIR /etc/asterisk

CMD ["/bin/bash"]
