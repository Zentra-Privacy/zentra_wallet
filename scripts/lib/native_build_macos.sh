#!/usr/bin/env bash
# macOS libzentra_wallet_ffi.dylib (Zentra depends + Apple SDK).
# Usage: native_build_macos [zentra_root]
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"

native_build_macos() {
  local ZENTRA_ROOT="${1:-}"
  local ROOT="${WALLET_ROOT:?}"
  local JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
  local OUT="$ROOT/packages/zentra_wallet_core/macos/lib"

  [[ -n "$ZENTRA_ROOT" ]] || ZENTRA_ROOT="$(native_resolve_zentra)" || {
    echo "Error: Zentra source not found"; return 1
  }

  local arch
  arch="$(uname -m)"
  local HOST
  if [[ "$arch" == "arm64" ]]; then
    HOST="aarch64-apple-darwin11"
  else
    HOST="x86_64-apple-darwin11"
  fi

  native_build_depends "$ZENTRA_ROOT" "$HOST" "$JOBS" || return 1

  local toolchain="$ZENTRA_ROOT/contrib/depends/$HOST/share/toolchain.cmake"
  local -a zextra=(-DBUILD_64=ON)
  if [[ "$arch" == "arm64" ]]; then
    zextra+=(-DARCH="armv8-a")
  else
    zextra+=(-DARCH="x86-64")
  fi
  local zbuild
  zbuild="$(native_build_zentra_wallet_api "$ZENTRA_ROOT" "$HOST" "darwin-$arch" "$JOBS" \
    "${zextra[@]}")" || return 1

  native_build_ffi_cmake "$ROOT" "$ZENTRA_ROOT" "$zbuild" "$toolchain" "$OUT" "darwin-$arch" "$JOBS" || return 1
  echo "==> macOS dylib ready for flutter build macos"
}
