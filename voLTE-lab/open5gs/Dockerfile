FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3-pip python3-setuptools python3-wheel \
    ninja-build build-essential flex bison git \
    cmake libsctp-dev libgnutls28-dev libgcrypt-dev \
    libssl-dev libidn11-dev libmongoc-dev libbson-dev \
    libyaml-dev libnghttp2-dev libmicrohttpd-dev \
    libcurl4-gnutls-dev libnghttp2-dev libtins-dev \
    libtalloc-dev meson curl wget iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Instalar mongo-c-driver actualizado
RUN pip3 install meson

COPY --from=open5gs-src /open5gs /open5gs

RUN cd /open5gs && \
    meson build --prefix=/usr && \
    ninja -C build && \
    ninja -C build install

WORKDIR /open5gs

CMD ["/bin/bash"]
