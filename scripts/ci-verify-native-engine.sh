#!/usr/bin/env bash
# Verify native-engine-bundle has libraries required for CI app builds.
# Default: Linux + Windows + Android (Release pipeline).
# Optional: INCLUDE_MACOS=1, INCLUDE_IOS=1 for extended bundles.
set -euo pipefail

BUNDLE="${1:?native-engine-bundle directory required}"

_req() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "::error::Missing native engine file: $f"
    exit 1
  fi
  echo "  OK $(basename "$f") ($(du -h "$f" | cut -f1))"
}

echo "==> Verifying native engine bundle: $BUNDLE"
[[ -f "$BUNDLE/VERSION.txt" ]] || { echo "::error::VERSION.txt missing"; exit 1; }
cat "$BUNDLE/VERSION.txt"

_req "$BUNDLE/linux/libzentra_wallet_ffi.so"
_req "$BUNDLE/windows/libzentra_wallet_ffi.dll"
_req "$BUNDLE/android/arm64-v8a/libzentra_wallet_ffi.so"
_req "$BUNDLE/android/armeabi-v7a/libzentra_wallet_ffi.so"

if [[ "${INCLUDE_MACOS:-0}" == "1" ]]; then
  _req "$BUNDLE/macos/lib/libzentra_wallet_ffi.dylib"
fi
if [[ "${INCLUDE_IOS:-0}" == "1" ]]; then
  if [[ ! -d "$BUNDLE/ios/lib/zentra_wallet_ffi.xcframework" ]]; then
    echo "::error::Missing iOS XCFramework: $BUNDLE/ios/lib/zentra_wallet_ffi.xcframework"
    exit 1
  fi
  echo "  OK zentra_wallet_ffi.xcframework"
fi

echo "==> Core native engine libraries present (Linux, Windows, Android)"
