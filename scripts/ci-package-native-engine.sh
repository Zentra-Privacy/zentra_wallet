#!/usr/bin/env bash
# Merge engine artifacts into native-engine-bundle for app CI jobs.
# Usage: ./scripts/ci-package-native-engine.sh <ubuntu-dir> [macos-dir] [output-dir]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UB="${1:?ubuntu staging dir required}"
MAC="${2:-}"
OUT="${3:-$ROOT/build/native-engine-bundle}"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -a "$UB/." "$OUT/"

if [[ -n "$MAC" && -d "$MAC/macos/lib" ]]; then
  mkdir -p "$OUT/macos/lib"
  cp -f "$MAC/macos/lib/libzentra_wallet_ffi.dylib" "$OUT/macos/lib/" 2>/dev/null || true
  if [[ -d "$MAC/ios/lib/zentra_wallet_ffi.xcframework" ]]; then
    mkdir -p "$OUT/ios/lib"
    cp -a "$MAC/ios/lib/zentra_wallet_ffi.xcframework" "$OUT/ios/lib/"
  fi
fi

{
  cat "$UB/VERSION.txt" 2>/dev/null || true
  [[ -n "$MAC" ]] && cat "$MAC/VERSION.txt" 2>/dev/null || true
  echo "bundle_created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | sort -u > "$OUT/VERSION.txt"

chmod +x "$ROOT/scripts/ci-verify-native-engine.sh"
"$ROOT/scripts/ci-verify-native-engine.sh" "$OUT"
