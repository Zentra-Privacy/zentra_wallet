#!/usr/bin/env bash
# Install Ubuntu packages for Zentra Wallet (Flutter Linux + native FFI build).
# Native packages align with Zentra scripts/install-deps.sh (Zentra-Privacy/zentra).
# Usage: sudo ./scripts/ci-install-linux-deps.sh [flutter|native|all]
set -euo pipefail

MODE="${1:-all}"

_flutter_deps() {
  apt-get install -y --no-install-recommends \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    libsecret-1-dev
}

# Matches Zentra scripts/install-deps.sh (required to build wallet_api + zentrad).
_native_deps() {
  apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config git python3 curl \
    libboost-all-dev libssl-dev libsodium-dev \
    libzmq3-dev libnorm-dev libpgm-dev libunbound-dev \
    libunwind-dev libreadline-dev libldns-dev libexpat1-dev \
    libpcap-dev libgtest-dev libhidapi-dev libusb-1.0-0-dev \
    libprotobuf-dev protobuf-compiler libudev-dev
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run with sudo: sudo $0 [$MODE]"
  exit 1
fi

apt-get update
case "$MODE" in
  flutter) _flutter_deps ;;
  native)  _native_deps ;;
  all)     _flutter_deps; _native_deps ;;
  *)
    echo "Usage: $0 [flutter|native|all]"
    exit 1
    ;;
esac

echo "Done ($MODE)."
