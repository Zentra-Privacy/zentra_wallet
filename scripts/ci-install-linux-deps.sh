#!/usr/bin/env bash
# Install Ubuntu packages for Zentra Wallet (Flutter Linux + native FFI build).
# Usage: sudo ./scripts/ci-install-linux-deps.sh [flutter|native|all]
set -euo pipefail

MODE="${1:-all}"

_flutter_deps() {
  apt-get install -y --no-install-recommends \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev
}

_native_deps() {
  apt-get install -y --no-install-recommends \
    build-essential cmake git python3 \
    libboost-all-dev libssl-dev \
    libprotobuf-dev protobuf-compiler \
    libunbound-dev libzmq3-dev \
    libsodium-dev libhidapi-libusb0 libusb-1.0-0-dev \
    libpgm-dev libnorm-dev
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
