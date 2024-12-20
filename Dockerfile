# Base para compilação
FROM ubuntu:22.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo

RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update && apt-get install -y \
    build-essential \
    gcc-12 \
    g++-12 \
    automake \
    git-core \
    autoconf \
    make \
    patch \
    libmysql++-dev \
    libtool \
    libssl-dev \
    grep \
    binutils \
    zlib1g-dev \
    libbz2-dev \
    cmake \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100

ARG BUILD_METRICS=NO
ARG BUILD_REALM=YES
ARG BUILD_WORLD=YES

ARG CMAKE_INSTALL_PREFIX=/opt/cmangos
ARG CXX_FLAGS="-O3 -march=native -mtune=native -DNDEBUG"

ENV CXXFLAGS="${CXX_FLAGS}"

WORKDIR /source
COPY . .

RUN mkdir build
WORKDIR /source/build
RUN cmake .. \
    -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} \
    -DBUILD_LOGIN_SERVER=${BUILD_REALM} \
    -DBUILD_GAME_SERVER=${BUILD_WORLD} \
    -DBUILD_METRICS=${BUILD_METRICS} \
    -DCMAKE_BUILD_TYPE=Release \
    -DPCH=1 \
    -DDEBUG=0 \
    && make -j$(nproc) \
    && make install

RUN ls -al /opt/cmangos/bin \
    && mv -f /opt/cmangos/bin/realmd /opt/cmangos/realmd 2> /dev/null; true \
    && mv -f /opt/cmangos/bin/mangosd /opt/cmangos/mangosd 2> /dev/null; true

FROM ubuntu:22.04 AS realm
RUN apt-get update && apt-get install -y \
    zlib1g-dev \
    libssl-dev \
    libmysql++-dev \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/cmangos /opt/cmangos
COPY --from=build /source/configs/realmd.conf /opt/cmangos/realmd.conf
EXPOSE 3724
WORKDIR /opt/cmangos
ENTRYPOINT ["./realmd", "-c", "/opt/cmangos/realmd.conf"]

FROM ubuntu:22.04 AS world
RUN apt-get update && apt-get install -y \
    zlib1g-dev \
    libssl-dev \
    libmysql++-dev \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/cmangos /opt/cmangos
COPY --from=build /source/configs/mangosd.conf /opt/cmangos/etc/mangosd.conf

EXPOSE 8085
WORKDIR /opt/cmangos
ENTRYPOINT ["./mangosd", "-c", "/opt/cmangos/etc/mangosd.conf"]
