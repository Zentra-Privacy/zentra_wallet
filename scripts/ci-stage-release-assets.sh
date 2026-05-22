#!/usr/bin/env bash
# Stage downloaded CI artifacts for GitHub Release upload (Linux, Windows, Android).
# Usage: ./scripts/ci-stage-release-assets.sh <release-files-dir> [output-dir]
set -euo pipefail

IN="${1:?release-files directory required}"
OUT="${2:-staged}"

mkdir -p "$OUT"
test -f "$IN/zentra-wallet-linux-x64/zentra-wallet-linux-x64.tar.gz"
test -f "$IN/zentra-wallet-windows-x64/zentra-wallet-windows-x64.zip"
test -f "$IN/zentra-wallet-android-apk/app-release.apk"

cp "$IN/zentra-wallet-linux-x64/zentra-wallet-linux-x64.tar.gz" "$OUT/"
cp "$IN/zentra-wallet-windows-x64/zentra-wallet-windows-x64.zip" "$OUT/"
cp "$IN/zentra-wallet-android-apk/app-release.apk" "$OUT/zentra-wallet-android.apk"

# Optional macOS / iOS if present in the workflow run
if [[ -f "$IN/zentra-wallet-macos/zentra-wallet-macos.zip" ]]; then
  cp "$IN/zentra-wallet-macos/zentra-wallet-macos.zip" "$OUT/"
fi
if [[ -f "$IN/zentra-wallet-ios/zentra-wallet-ios.zip" ]]; then
  cp "$IN/zentra-wallet-ios/zentra-wallet-ios.zip" "$OUT/"
fi

ls -la "$OUT/"
