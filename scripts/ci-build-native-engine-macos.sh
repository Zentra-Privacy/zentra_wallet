#!/usr/bin/env bash
# Phase 1 (macOS): build wallet engine dylib from Zentra v0.1.0 (optional / local).
# Not required for Linux + Windows + Android CI releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WALLET_ROOT="$ROOT"
export JOBS="${JOBS:-2}"
# Portable dylib (no Homebrew runtime on target Macs) — same as docs/build-macos.md CI guidance.
export ZENTRA_MACOS_USE_DEPENDS="${ZENTRA_MACOS_USE_DEPENDS:-1}"
STAGE="${1:-$ROOT/build/native-engine-macos}"

# shellcheck source=lib/native_build_common.sh
source "$ROOT/scripts/lib/native_build_common.sh"
# shellcheck source=lib/native_build_macos.sh
source "$ROOT/scripts/lib/native_build_macos.sh"

mkdir -p "$ROOT/build"
chmod +x "$ROOT/scripts/ci-clone-zentra.sh"
"$ROOT/scripts/ci-clone-zentra.sh" "$ROOT/third_party/zentra"
# shellcheck disable=SC1091
source "$ROOT/build/zentra-checkout.env"

rm -rf "$STAGE"
mkdir -p "$STAGE/macos/lib"

native_build_macos "$zentra_path"
cp -f "$ROOT/packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib" "$STAGE/macos/lib/"

{
  echo "zentra_tag=${zentra_tag}"
  echo "zentra_commit=${zentra_commit}"
  echo "built_macos=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$STAGE/VERSION.txt"
find "$STAGE" -type f -exec ls -lh {} \;
