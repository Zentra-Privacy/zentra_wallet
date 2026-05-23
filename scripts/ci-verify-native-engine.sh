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

_check_elf() {
  local f="$1" expect="$2"
  if ! command -v file >/dev/null 2>&1; then
    return 0
  fi
  local info
  info="$(file -b "$f")"
  if [[ "$info" != *"$expect"* ]]; then
    echo "::error::Unexpected architecture for $f"
    echo "       file: $info"
    echo "       expected substring: $expect"
    exit 1
  fi
  echo "  arch OK: $info"
}

echo "==> Verifying native engine bundle: $BUNDLE"
[[ -f "$BUNDLE/VERSION.txt" ]] || { echo "::error::VERSION.txt missing"; exit 1; }
cat "$BUNDLE/VERSION.txt"

LINUX_SO="$BUNDLE/linux/libzentra_wallet_ffi.so"
WIN_DLL="$BUNDLE/windows/libzentra_wallet_ffi.dll"
ARM64_SO="$BUNDLE/android/arm64-v8a/libzentra_wallet_ffi.so"
ARM32_SO="$BUNDLE/android/armeabi-v7a/libzentra_wallet_ffi.so"

_req "$LINUX_SO"
_req "$WIN_DLL"
_req "$ARM64_SO"
_req "$ARM32_SO"

_check_elf "$LINUX_SO" "x86-64"
_check_elf "$ARM64_SO" "aarch64"
_check_elf "$ARM32_SO" "ARM"

if command -v file >/dev/null 2>&1; then
  _win_info="$(file -b "$WIN_DLL")"
  if [[ "$_win_info" != *"PE32"* ]]; then
    echo "::error::Windows DLL is not a PE32 executable: $_win_info"
    exit 1
  fi
  echo "  arch OK: $_win_info"
fi
if [[ -f "$WIN_DLL" ]] && command -v x86_64-w64-mingw32-objdump >/dev/null 2>&1; then
  x86_64-w64-mingw32-objdump -f "$WIN_DLL" | head -3 || true
fi

# Reject empty or suspiciously small engine binaries (< 1 MiB).
_min_bytes=1048576
for f in "$LINUX_SO" "$WIN_DLL" "$ARM64_SO" "$ARM32_SO"; do
  size="$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f")"
  if [[ "$size" -lt "$_min_bytes" ]]; then
    echo "::error::Engine library too small ($size bytes): $f"
    exit 1
  fi
done

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
