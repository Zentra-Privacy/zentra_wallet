#!/usr/bin/env bash
# Copy native-engine-bundle into plugin paths before flutter build.
# Usage: ./scripts/ci-apply-native-libs.sh <native-engine-bundle-dir>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${1:?native-engine-bundle directory required}"

chmod +x "$ROOT/scripts/ci-verify-native-engine.sh"
"$ROOT/scripts/ci-verify-native-engine.sh" "$BUNDLE"

_apply() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$dest"
  echo "==> $dest"
}

_apply "$BUNDLE/linux/libzentra_wallet_ffi.so" \
  "$ROOT/packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so"
mkdir -p "$ROOT/packages/zentra_wallet_core/windows"
for dll in "$BUNDLE/windows"/*.dll; do
  [[ -f "$dll" ]] || continue
  _apply "$dll" "$ROOT/packages/zentra_wallet_core/windows/$(basename "$dll")"
done
[[ -f "$ROOT/packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll" ]] || {
  echo "::error::Missing libzentra_wallet_ffi.dll in native-engine-bundle/windows"
  exit 1
}

for abi_dir in "$BUNDLE/android"/*; do
  [[ -d "$abi_dir" ]] || continue
  abi="$(basename "$abi_dir")"
  mkdir -p "$ROOT/packages/zentra_wallet_core/android/src/main/jniLibs/$abi"
  for so in "$abi_dir"/*.so; do
    [[ -f "$so" ]] || continue
    _apply "$so" "$ROOT/packages/zentra_wallet_core/android/src/main/jniLibs/$abi/$(basename "$so")"
  done
done

if [[ -f "$BUNDLE/macos/lib/libzentra_wallet_ffi.dylib" ]]; then
  _apply "$BUNDLE/macos/lib/libzentra_wallet_ffi.dylib" \
    "$ROOT/packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib"
fi

if [[ -d "$BUNDLE/ios/lib/zentra_wallet_ffi.xcframework" ]]; then
  rm -rf "$ROOT/packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework"
  mkdir -p "$ROOT/packages/zentra_wallet_core/ios/lib"
  cp -a "$BUNDLE/ios/lib/zentra_wallet_ffi.xcframework" \
    "$ROOT/packages/zentra_wallet_core/ios/lib/"
  echo "==> $ROOT/packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework"
fi

echo "==> Native engine applied (Zentra $(grep zentra_tag "$BUNDLE/VERSION.txt" | cut -d= -f2))"
