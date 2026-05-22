#!/usr/bin/env bash
# Merge Ubuntu + macOS engine artifacts into one bundle for app CI jobs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UB="${1:?ubuntu staging dir}"
MAC="${2:?macos staging dir}"
OUT="${3:-$ROOT/build/native-engine-bundle}"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -a "$UB/." "$OUT/"
mkdir -p "$OUT/macos/lib" "$OUT/ios/lib"
cp -f "$MAC/macos/lib/libzentra_wallet_ffi.dylib" "$OUT/macos/lib/"
[[ -d "$MAC/ios/lib/zentra_wallet_ffi.xcframework" ]] || {
  echo "::error::engine-macos artifact missing ios/lib/zentra_wallet_ffi.xcframework"
  exit 1
}
cp -a "$MAC/ios/lib/zentra_wallet_ffi.xcframework" "$OUT/ios/lib/"

{
  cat "$UB/VERSION.txt" 2>/dev/null || true
  cat "$MAC/VERSION.txt" 2>/dev/null || true
  echo "bundle_created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | sort -u > "$OUT/VERSION.txt"

chmod +x "$ROOT/scripts/ci-verify-native-engine.sh"
"$ROOT/scripts/ci-verify-native-engine.sh" "$OUT"
