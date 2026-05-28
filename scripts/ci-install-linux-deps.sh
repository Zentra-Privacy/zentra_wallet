#!/usr/bin/env bash
# Install Ubuntu packages for Zentra Wallet (local builds).
#   flutter — flutter build linux
#   native  — ./wallet.sh build (Zentra source; matches Zentra install-deps.sh)
#   all     — both (recommended for full local dev)
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
# MinGW: required for Windows DLL cross-compile (contrib/depends HOST=x86_64-w64-mingw32).
_configure_mingw_posix() {
  # protobuf / C++11 need posix threading, not win32 (see docs/build-windows.md).
  if [[ -x "$(dirname "$0")/ci-configure-mingw-posix.sh" ]]; then
    bash "$(dirname "$0")/ci-configure-mingw-posix.sh"
  fi
}

_native_deps() {
  apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config git python3 curl \
    libtinfo5 \
    g++-mingw-w64-x86-64 gcc-mingw-w64-x86-64 mingw-w64 \
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
  native)  _native_deps; _configure_mingw_posix ;;
  all)     _flutter_deps; _native_deps; _configure_mingw_posix ;;
  *)
    echo "Usage: $0 [flutter|native|all]"
    exit 1
    ;;
esac

echo "Done ($MODE)."
