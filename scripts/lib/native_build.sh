#!/usr/bin/env bash
# Host native build: Zentra wallet_api + libzentra_wallet_ffi.so
# Usage (sourced): native_build_host <zentra_root> [zentra_build_dir]
# Env: WALLET_ROOT, FFI_BUILD, JOBS
native_build_host() {
  local ZENTRA_ROOT="$1"
  local ZENTRA_BUILD="${2:-${ZENTRA_BUILD:-$ZENTRA_ROOT/build/release}}"
  local ROOT="${WALLET_ROOT:?WALLET_ROOT not set}"

  if ! command -v cmake >/dev/null 2>&1; then
    echo "Error: cmake not in PATH."
    return 1
  fi

  ZENTRA_ROOT="$(cd "$ZENTRA_ROOT" && pwd)"
  mkdir -p "$ZENTRA_BUILD"
  ZENTRA_BUILD="$(cd "$ZENTRA_BUILD" && pwd)"

  local FFI_BUILD="${FFI_BUILD:-$ROOT/build/native_ffi}"
  local WALLET_API_LIB="$ZENTRA_BUILD/lib/libwallet_api.a"
  local JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
  local _DEFAULT_BUILD="$ZENTRA_ROOT/build/release"

  if [[ ! -f "$ZENTRA_ROOT/src/wallet/api/wallet2_api.h" ]]; then
    echo "Error: Zentra wallet API not found at $ZENTRA_ROOT/src/wallet/api"
    return 1
  fi

  echo "==> Zentra root: $ZENTRA_ROOT"
  echo "==> Zentra build: $ZENTRA_BUILD"

  _zentra_cmake_cache_matches() {
    [[ -f "$ZENTRA_BUILD/CMakeCache.txt" ]] || return 1
    local cached
    cached="$(grep -m1 '^CMAKE_HOME_DIRECTORY:INTERNAL=' "$ZENTRA_BUILD/CMakeCache.txt" 2>/dev/null | cut -d= -f2- | tr -d '\r')"
    [[ -n "$cached" && "$cached" == "$ZENTRA_ROOT" ]]
  }

  _configure_zentra_cmake() {
    mkdir -p "$ZENTRA_BUILD"
    if [[ ! -f "$ZENTRA_BUILD/CMakeCache.txt" ]]; then
      echo "==> CMake configure → $ZENTRA_BUILD"
      (
        cd "$ZENTRA_BUILD"
        cmake \
          -D CMAKE_BUILD_TYPE=Release \
          -D BUILD_TESTS=OFF \
          -D BUILD_DOCUMENTATION=OFF \
          -D MANUAL_SUBMODULES=1 \
          "$ZENTRA_ROOT"
      )
    fi
  }

  local _need=0
  if [[ ! -f "$ZENTRA_BUILD/Makefile" && ! -f "$ZENTRA_BUILD/build.ninja" ]]; then _need=1; fi
  if [[ ! -f "$WALLET_API_LIB" ]]; then _need=1; fi
  if [[ -f "$ZENTRA_BUILD/CMakeCache.txt" ]] && ! _zentra_cmake_cache_matches; then
    echo "==> Removing stale CMake cache (configured for a different path than $ZENTRA_ROOT)"
    rm -rf "$ZENTRA_BUILD"
    _need=1
  fi

  if [[ "$_need" -eq 1 ]]; then
    if [[ "$ZENTRA_BUILD" == "$_DEFAULT_BUILD" ]] && [[ -x "$ZENTRA_ROOT/scripts/build.sh" ]]; then
      echo "==> Configuring & building Zentra (release) via scripts/build.sh..."
      (cd "$ZENTRA_ROOT" && scripts/build.sh release)
    else
      _configure_zentra_cmake
      echo "==> Building wallet_api and dependencies..."
      cmake --build "$ZENTRA_BUILD" --target wallet_api --parallel "$JOBS"
    fi
  else
    echo "==> Building wallet_api target..."
    cmake --build "$ZENTRA_BUILD" --target wallet_api --parallel "$JOBS"
  fi

  if [[ ! -f "$WALLET_API_LIB" ]]; then
    echo "Error: $WALLET_API_LIB not found after wallet_api build"
    return 1
  fi

  mkdir -p "$FFI_BUILD"
  export ZENTRA_ROOT ZENTRA_BUILD_DIR="$ZENTRA_BUILD"
  cmake -S "$ROOT/native/zentra_wallet_ffi" -B "$FFI_BUILD" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$FFI_BUILD" --parallel "$JOBS"

  local OUT_SO="$FFI_BUILD/libzentra_wallet_ffi.so"
  if [[ ! -f "$OUT_SO" ]]; then
    echo "Error: $OUT_SO not produced"
    return 1
  fi

  local LINUX_PLUGIN="$ROOT/packages/zentra_wallet_core/linux"
  mkdir -p "$LINUX_PLUGIN"
  cp -f "$OUT_SO" "$LINUX_PLUGIN/libzentra_wallet_ffi.so"
  echo "==> Installed $LINUX_PLUGIN/libzentra_wallet_ffi.so"
}
