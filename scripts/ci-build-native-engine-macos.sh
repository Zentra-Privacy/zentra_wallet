#!/usr/bin/env bash
# Phase 1 (macOS): build wallet engine dylib from Zentra v0.1.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WALLET_ROOT="$ROOT"
export JOBS="${JOBS:-2}"
STAGE="${1:-$ROOT/build/native-engine-macos}"

# shellcheck source=lib/native_build_common.sh
source "$ROOT/scripts/lib/native_build_common.sh"
# shellcheck source=lib/native_build_macos.sh
source "$ROOT/scripts/lib/native_build_macos.sh"
# shellcheck source=lib/native_build_ios.sh
source "$ROOT/scripts/lib/native_build_ios.sh"

mkdir -p "$ROOT/build"
chmod +x "$ROOT/scripts/ci-clone-zentra.sh"
"$ROOT/scripts/ci-clone-zentra.sh" "$ROOT/third_party/zentra"
# shellcheck disable=SC1091
source "$ROOT/build/zentra-checkout.env"

rm -rf "$STAGE"
mkdir -p "$STAGE/macos/lib" "$STAGE/ios/lib"

native_build_macos "$zentra_path"
cp -f "$ROOT/packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib" "$STAGE/macos/lib/"

native_build_ios "$zentra_path"
cp -a "$ROOT/packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework" "$STAGE/ios/lib/"

{
  echo "zentra_tag=${zentra_tag}"
  echo "zentra_commit=${zentra_commit}"
  echo "built_macos=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "built_ios=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$STAGE/VERSION.txt"
find "$STAGE" -type f -exec ls -lh {} \;
