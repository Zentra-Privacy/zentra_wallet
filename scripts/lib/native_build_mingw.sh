#!/usr/bin/env bash
# Windows x64 libzentra_wallet_ffi.dll via MinGW (Zentra depends).
# Usage: native_build_mingw [zentra_root]
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"

native_build_mingw() {
  local ZENTRA_ROOT="${1:-}"
  local ROOT="${WALLET_ROOT:?}"
  local JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
  local HOST="x86_64-w64-mingw32"
  local OUT="$ROOT/packages/zentra_wallet_core/windows"

  [[ -n "$ZENTRA_ROOT" ]] || ZENTRA_ROOT="$(native_resolve_zentra)" || {
    echo "Error: Zentra source not found"; return 1
  }

  native_prepare_python_shim "$ROOT"
  native_ensure_zentra_depends_patched "$ZENTRA_ROOT" || return 1
  if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    echo "Error: x86_64-w64-mingw32-gcc not found."
    echo "  Install: sudo apt install -y g++-mingw-w64-x86-64 gcc-mingw-w64-x86-64 mingw-w64"
    return 1
  fi
  if ! x86_64-w64-mingw32-gcc -dumpmachine >/dev/null 2>&1; then
    echo "Error: x86_64-w64-mingw32-gcc cannot run (broken MinGW toolchain)."
    return 1
  fi
  native_build_depends "$ZENTRA_ROOT" "$HOST" "$JOBS" || return 1

  local toolchain="$ZENTRA_ROOT/contrib/depends/$HOST/share/toolchain.cmake"
  local zbuild="$ZENTRA_ROOT/build/mingw-win64/release"
  native_build_zentra_wallet_api "$ZENTRA_ROOT" "$HOST" "mingw-win64" "$JOBS" \
    -DBUILD_64=ON -DARCH="x86-64" -DUSE_DEVICE_TREZOR=OFF -DANDROID=OFF || return 1

  native_build_ffi_cmake "$ROOT" "$ZENTRA_ROOT" "$zbuild" "$toolchain" "$OUT" "mingw-win64" "$JOBS" || return 1
  _bundle_mingw_runtime_dlls "$OUT"
  echo "==> Windows DLL ready for flutter build windows"
}

_bundle_mingw_runtime_dlls() {
  local dest="$1"
  local gxx="x86_64-w64-mingw32-g++"
  command -v "$gxx" >/dev/null 2>&1 || return 0
  for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
    local path
    path="$("$gxx" -print-file-name="$dll" 2>/dev/null || true)"
    [[ -n "$path" && -f "$path" ]] || continue
    cp -f "$path" "$dest/$(basename "$path")"
    echo "==> Bundled $dest/$(basename "$path")"
  done
}
