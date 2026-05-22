# Ubuntu 22.04 toolchain for libzentra_wallet_ffi.so (glibc compatible with 22.x hosts).
# Build context: this directory only (see ./wallet.sh build-docker).

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    ccache \
    git \
    curl \
    python3 \
    libboost-all-dev \
    libssl-dev \
    libsodium-dev \
    libzmq3-dev \
    libnorm-dev \
    libpgm-dev \
    libunbound-dev \
    libunwind-dev \
    liblzma-dev \
    libreadline-dev \
    libldns-dev \
    libexpat1-dev \
    libpcap-dev \
    libgtest-dev \
    libhidapi-dev \
    libusb-1.0-0-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libudev-dev \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /wallet
