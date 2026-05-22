#!/usr/bin/env bash
# Phase 1 (Ubuntu): build wallet engine from Zentra v0.1.0 — Linux .so, Android ABIs, Windows .dll
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WALLET_ROOT="$ROOT"
export JOBS="${JOBS:-2}"
STAGE="${1:-$ROOT/build/native-engine-bundle}"

mkdir -p "$ROOT/build"
# shellcheck source=lib/native_build_common.sh
source "$ROOT/scripts/lib/native_build_common.sh"
# shellcheck source=lib/native_build.sh
source "$ROOT/scripts/lib/native_build.sh"
# shellcheck source=lib/native_build_android.sh
source "$ROOT/scripts/lib/native_build_android.sh"
# shellcheck source=lib/native_build_mingw.sh
source "$ROOT/scripts/lib/native_build_mingw.sh"

chmod +x "$ROOT/scripts/ci-clone-zentra.sh"
"$ROOT/scripts/ci-clone-zentra.sh" "$ROOT/third_party/zentra"
# shellcheck disable=SC1091
source "$ROOT/build/zentra-checkout.env"
ZENTRA="$zentra_path"

native_prepare_python_shim "$ROOT"

rm -rf "$STAGE"
mkdir -p "$STAGE/linux" "$STAGE/windows" "$STAGE/android/arm64-v8a" "$STAGE/android/armeabi-v7a"

echo "==> Linux x64 (host build, Zentra $zentra_tag)"
native_build_host "$ZENTRA"
cp -f "$ROOT/packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so" "$STAGE/linux/"

echo "==> Android arm64-v8a"
native_build_android "$ZENTRA" arm64-v8a
cp -f "$ROOT/packages/zentra_wallet_core/android/src/main/jniLibs/arm64-v8a/libzentra_wallet_ffi.so" \
  "$STAGE/android/arm64-v8a/"

echo "==> Android armeabi-v7a"
native_build_android "$ZENTRA" armeabi-v7a
cp -f "$ROOT/packages/zentra_wallet_core/android/src/main/jniLibs/armeabi-v7a/libzentra_wallet_ffi.so" \
  "$STAGE/android/armeabi-v7a/"

echo "==> Windows x64 (MinGW)"
native_build_mingw "$ZENTRA"
cp -f "$ROOT/packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll" "$STAGE/windows/"

{
  echo "zentra_tag=${zentra_tag}"
  echo "zentra_commit=${zentra_commit}"
  echo "built_ubuntu=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$STAGE/VERSION.txt"

chmod +x "$ROOT/scripts/ci-verify-native-engine.sh"
"$ROOT/scripts/ci-verify-native-engine.sh" "$STAGE"

find "$STAGE" -type f -exec ls -lh {} \;
