#!/usr/bin/env bash
# macOS libzentra_wallet_ffi.dylib (Homebrew or Zentra contrib/depends).
# Usage: native_build_macos [zentra_root]
#   ZENTRA_MACOS_USE_DEPENDS=1  force contrib/depends (slow, portable)
#   ZENTRA_MACOS_USE_BREW=1     force Homebrew + existing zentra/build/release
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"

native_build_macos_brew() {
  local ZENTRA_ROOT="${1:?}"
  local ROOT="${WALLET_ROOT:?}"
  local JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
  local OUT="$ROOT/packages/zentra_wallet_core/macos/lib"
  local ZENTRA_BUILD="${ZENTRA_BUILD:-$ZENTRA_ROOT/build/release}"
  local WALLET_API="$ZENTRA_BUILD/lib/libwallet_api.a"
  local ffibuild="$ROOT/build/native_ffi/darwin-brew"

  echo "==> macOS FFI via Homebrew (Zentra build: $ZENTRA_BUILD)"
  if [[ ! -f "$ZENTRA_BUILD/CMakeCache.txt" ]]; then
    echo "Error: configure Zentra first: cd $ZENTRA_ROOT && scripts/build.sh"
    return 1
  fi
  if [[ ! -f "$WALLET_API" ]]; then
    echo "==> Building wallet_api in $ZENTRA_BUILD"
    cmake --build "$ZENTRA_BUILD" --target wallet_api --parallel "$JOBS" || return 1
  fi
  [[ -f "$WALLET_API" ]] || { echo "Error: $WALLET_API missing"; return 1; }

  mkdir -p "$ffibuild" "$OUT"
  local arch
  arch="$(uname -m)"
  local -a cmake_extra=(
    -DCMAKE_OSX_ARCHITECTURES="$arch"
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
  )
  if command -v brew >/dev/null 2>&1; then
    local brew_prefix
    brew_prefix="$(brew --prefix)"
    cmake_extra+=(
      -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR:-$brew_prefix/opt/openssl@3}"
      -DBoost_ROOT="${Boost_ROOT:-$brew_prefix}"
    )
  fi
  cmake -S "$ROOT/native/zentra_wallet_ffi" -B "$ffibuild" \
    -DCMAKE_BUILD_TYPE=Release \
    -DZENTRA_ROOT="$ZENTRA_ROOT" \
    -DZENTRA_BUILD_DIR="$ZENTRA_BUILD" \
    "${cmake_extra[@]}" || return 1
  cmake --build "$ffibuild" --parallel "$JOBS" || return 1

  local ext=dylib
  if [[ -f "$ffibuild/libzentra_wallet_ffi.$ext" ]]; then
    cp -f "$ffibuild/libzentra_wallet_ffi.$ext" "$OUT/libzentra_wallet_ffi.$ext"
  else
    echo "Error: FFI output not found under $ffibuild"
    return 1
  fi
  echo "==> Installed $OUT/libzentra_wallet_ffi.$ext"
  file "$OUT/libzentra_wallet_ffi.$ext" || true
  ls -la "$OUT"
  echo "    Note: Homebrew-linked dylib needs Homebrew libs on the target Mac."
  echo "    For portable release builds use: ZENTRA_MACOS_USE_DEPENDS=1 ./wallet.sh build-macos"
}

native_build_macos() {
  local ZENTRA_ROOT="${1:-}"
  local ROOT="${WALLET_ROOT:?}"
  local JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
  local OUT="$ROOT/packages/zentra_wallet_core/macos/lib"

  [[ -n "$ZENTRA_ROOT" ]] || ZENTRA_ROOT="$(native_resolve_zentra)" || {
    echo "Error: Zentra source not found"; return 1
  }

  if [[ "${ZENTRA_MACOS_USE_BREW:-0}" == "1" ]]; then
    native_build_macos_brew "$ZENTRA_ROOT"
    return $?
  fi
  if [[ "${ZENTRA_MACOS_USE_DEPENDS:-0}" != "1" ]] \
    && [[ -f "$ZENTRA_ROOT/build/release/CMakeCache.txt" ]]; then
    echo "==> Using Homebrew Zentra build (set ZENTRA_MACOS_USE_DEPENDS=1 for contrib/depends)"
    native_build_macos_brew "$ZENTRA_ROOT"
    return $?
  fi

  local arch
  arch="$(uname -m)"
  local HOST
  if [[ "$arch" == "arm64" ]]; then
    HOST="aarch64-apple-darwin11"
  else
    HOST="x86_64-apple-darwin11"
  fi

  local patch_sh="${ROOT}/scripts/ci-patch-zentra-depends.sh"
  if [[ -x "$patch_sh" ]]; then
    "$patch_sh" "$ZENTRA_ROOT" || return 1
  fi

  native_build_depends "$ZENTRA_ROOT" "$HOST" "$JOBS" || return 1

  local toolchain="$ZENTRA_ROOT/contrib/depends/$HOST/share/toolchain.cmake"
  local -a zextra=(-DBUILD_64=ON)
  if [[ "$arch" == "arm64" ]]; then
    zextra+=(-DARCH="armv8-a")
  else
    zextra+=(-DARCH="x86-64")
  fi
  local zbuild="$ZENTRA_ROOT/build/darwin-$arch/release"
  native_build_zentra_wallet_api "$ZENTRA_ROOT" "$HOST" "darwin-$arch" "$JOBS" \
    "${zextra[@]}" || return 1

  native_build_ffi_cmake "$ROOT" "$ZENTRA_ROOT" "$zbuild" "$toolchain" "$OUT" "darwin-$arch" "$JOBS" || return 1
  echo "==> macOS dylib ready for flutter build macos"
}
