#!/usr/bin/env bash
# Ensure release APK contains wallet native libraries per ABI.
set -euo pipefail

APK="${1:?path to app-release.apk}"
command -v unzip >/dev/null 2>&1 || {
  echo "::error::unzip required"
  exit 1
}

echo "==> Verifying Android APK: $APK"
[[ -f "$APK" ]] || {
  echo "::error::APK not found: $APK"
  exit 1
}

_list() {
  unzip -l "$APK" | awk '{print $4}' | grep -E '^lib/' || true
}

for abi in arm64-v8a armeabi-v7a; do
  if ! _list | grep -q "lib/${abi}/libzentra_wallet_ffi.so"; then
    echo "::error::Missing lib/${abi}/libzentra_wallet_ffi.so in APK"
    echo "Native engine was not packaged. Rebuild engine bundle and Phase 2 android job."
    _list | head -40
    exit 1
  fi
  echo "  OK lib/${abi}/libzentra_wallet_ffi.so"
  if ! _list | grep -q "lib/${abi}/libc++_shared.so"; then
    echo "::error::Missing lib/${abi}/libc++_shared.so in APK"
    exit 1
  fi
  echo "  OK lib/${abi}/libc++_shared.so"
done

apk_mb="$(du -m "$APK" | cut -f1)"
if [[ "$apk_mb" -lt 25 ]]; then
  echo "::warning::APK is only ${apk_mb} MiB — wallet .so may be missing or stripped"
fi

echo "==> Android APK native libs OK"
