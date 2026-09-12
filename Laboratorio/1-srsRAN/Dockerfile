FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake build-essential git \
    libfftw3-dev libmbedtls-dev libboost-all-dev \
    libconfig++-dev libsctp-dev \
    libzmq3-dev \
    python3 python3-pip \
    iproute2 iputils-ping net-tools \
    baresip-core \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/srsran/srsRAN_4G.git /srsran && \
    cd /srsran && \
    mkdir build && cd build && \
    cmake .. -DENABLE_ZMQ=ON && \
    make -j$(nproc) && \
    make install && \
    ldconfig

WORKDIR /srsran/build

CMD ["/bin/bash"]
