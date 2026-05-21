#!/usr/bin/env bash
# Build embedded Zentra wallet2 FFI library (Monero-style, no wallet-rpc).
#
# Prerequisites:
#   cd ../zentra && scripts/install-deps.sh && scripts/build.sh
#
# Usage:
#   ./scripts/build_native_wallet.sh
#   ./scripts/build_native_wallet.sh /path/to/zentra
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZENTRA_ROOT="${1:-$(cd "$ROOT/../zentra" && pwd)}"
ZENTRA_BUILD="${ZENTRA_BUILD:-$ZENTRA_ROOT/build/release}"
FFI_BUILD="$ROOT/build/native_ffi"

if [[ ! -d "$ZENTRA_ROOT/src/wallet/api" ]]; then
  echo "Error: Zentra source not found at $ZENTRA_ROOT"
  exit 1
fi

echo "==> Zentra root: $ZENTRA_ROOT"
echo "==> Zentra build: $ZENTRA_BUILD"

if [[ ! -f "$ZENTRA_BUILD/Makefile" && ! -f "$ZENTRA_BUILD/build.ninja" ]]; then
  echo "==> Configuring & building Zentra (release)..."
  (cd "$ZENTRA_ROOT" && scripts/build.sh release)
fi

echo "==> Building wallet_api target..."
cmake --build "$ZENTRA_BUILD" --target wallet_api --parallel "$(nproc 2>/dev/null || echo 4)"

mkdir -p "$FFI_BUILD"
export ZENTRA_ROOT ZENTRA_BUILD_DIR="$ZENTRA_BUILD"
cmake -S "$ROOT/native/zentra_wallet_ffi" -B "$FFI_BUILD" -DCMAKE_BUILD_TYPE=Release
cmake --build "$FFI_BUILD" --parallel "$(nproc 2>/dev/null || echo 4)"

OUT_SO="$FFI_BUILD/libzentra_wallet_ffi.so"
if [[ ! -f "$OUT_SO" ]]; then
  echo "Error: $OUT_SO not produced"
  exit 1
fi

LINUX_PLUGIN="$ROOT/packages/zentra_wallet_core/linux"
mkdir -p "$LINUX_PLUGIN"
cp -f "$OUT_SO" "$LINUX_PLUGIN/libzentra_wallet_ffi.so"
echo "==> Installed $LINUX_PLUGIN/libzentra_wallet_ffi.so"
echo "==> Run: ./scripts/build_and_run.sh -d linux"
