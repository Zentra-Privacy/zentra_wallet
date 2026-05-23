#!/usr/bin/env bash
# Shared helpers for cross-platform Zentra FFI builds.
native_resolve_zentra() {
  local root="${WALLET_ROOT:?}"
  if [[ -n "${ZENTRA_ROOT:-}" && -d "${ZENTRA_ROOT}/src/wallet/api" ]]; then
    echo "$(cd "$ZENTRA_ROOT" && pwd)"
    return 0
  fi
  if [[ -d "$root/../zentra/src/wallet/api" ]]; then
    echo "$(cd "$root/../zentra" && pwd)"
    return 0
  fi
  if [[ -d "$root/third_party/zentra/src/wallet/api" ]]; then
    echo "$(cd "$root/third_party/zentra" && pwd)"
    return 0
  fi
  return 1
}

native_ensure_zentra_depends_patched() {
  local zentra_root="$1"
  local patch_sh="${WALLET_ROOT:?}/scripts/ci-patch-zentra-depends.sh"
  [[ -f "$zentra_root/contrib/depends/packages/zeromq.mk" ]] || return 0
  if grep -q 'config_opts_mingw32=--with-cv-impl=pthread' "$zentra_root/contrib/depends/packages/zeromq.mk"; then
    return 0
  fi
  [[ -x "$patch_sh" ]] || {
    echo "Error: MinGW zeromq patch missing. Run: ./scripts/ci-patch-zentra-depends.sh"
    return 1
  }
  "$patch_sh" "$zentra_root"
}

native_prepare_python_shim() {
  local root="$1"
  if command -v python >/dev/null 2>&1; then
    return 0
  fi
  command -v python3 >/dev/null 2>&1 || return 1
  local pyshim="$root/.build/bin"
  mkdir -p "$pyshim"
  ln -sf "$(command -v python3)" "$pyshim/python"
  export PATH="$pyshim:$PATH"
}

native_build_depends() {
  local zentra_root="$1"
  local host="$2"
  local jobs="${3:-4}"
  local depends_dir="$zentra_root/contrib/depends"
  local toolchain="$depends_dir/$host/share/toolchain.cmake"

  if [[ -f "$toolchain" && "${SKIP_DEPENDS:-0}" == "1" ]]; then
    echo "==> Depends $host (cached)"
    return 0
  fi

  echo "==> Depends $host (may take 30–90 min first time)"
  (cd "$depends_dir" && make HOST="$host" -j"$jobs") || return 1
  [[ -f "$toolchain" ]] || {
    echo "Error: missing $toolchain"
    return 1
  }
}

native_build_zentra_wallet_api() {
  local zentra_root="$1"
  local host="$2"
  local platform_tag="$3"
  local jobs="${4:-4}"
  local depends_dir="$zentra_root/contrib/depends"
  local toolchain="$depends_dir/$host/share/toolchain.cmake"
  local zbuild="$zentra_root/build/$platform_tag/release"

  shift 4
  local -a extra=("$@")

  echo "==> Zentra wallet_api ($platform_tag)"
  mkdir -p "$zbuild"
  cmake -S "$zentra_root" -B "$zbuild" \
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=OFF \
    -DBUILD_DOCUMENTATION=OFF \
    -DMANUAL_SUBMODULES=1 \
    -DSTATIC=ON \
    "${extra[@]}" || return 1
  cmake --build "$zbuild" --target wallet_api --parallel "$jobs" || return 1
  [[ -f "$zbuild/lib/libwallet_api.a" ]] || {
    echo "Error: $zbuild/lib/libwallet_api.a missing"
    return 1
  }
}

native_build_ffi_cmake() {
  local root="$1"
  local zentra_root="$2"
  local zbuild="$3"
  local toolchain="$4"
  local out_dir="$5"
  local ffi_tag="$6"
  local jobs="${7:-4}"
  shift 7
  local -a extra=("$@")

  local depends_prefix
  depends_prefix="$(cd "$(dirname "$toolchain")/.." && pwd)"
  local ffibuild="$root/build/native_ffi/$ffi_tag"
  mkdir -p "$ffibuild"
  cmake -S "$root/native/zentra_wallet_ffi" -B "$ffibuild" \
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" \
    -DCMAKE_BUILD_TYPE=Release \
    -DZENTRA_ROOT="$zentra_root" \
    -DZENTRA_BUILD_DIR="$zbuild" \
    -DZENTRA_DEPENDS_PREFIX="$depends_prefix" \
    "${extra[@]}" || return 1
  cmake --build "$ffibuild" --parallel "$jobs" || return 1
  mkdir -p "$out_dir"
  local ext
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) ext="dll" ;;
    Darwin*) ext="dylib" ;;
    *) ext="so" ;;
  esac
  if [[ -f "$ffibuild/libzentra_wallet_ffi.$ext" ]]; then
    cp -f "$ffibuild/libzentra_wallet_ffi.$ext" "$out_dir/libzentra_wallet_ffi.$ext"
  elif [[ -f "$ffibuild/libzentra_wallet_ffi.so" ]]; then
    cp -f "$ffibuild/libzentra_wallet_ffi.so" "$out_dir/libzentra_wallet_ffi.so"
  elif [[ -f "$ffibuild/libzentra_wallet_ffi.dll" ]]; then
    cp -f "$ffibuild/libzentra_wallet_ffi.dll" "$out_dir/libzentra_wallet_ffi.dll"
  elif [[ -f "$ffibuild/libzentra_wallet_ffi.dylib" ]]; then
    cp -f "$ffibuild/libzentra_wallet_ffi.dylib" "$out_dir/libzentra_wallet_ffi.dylib"
  elif [[ -f "$ffibuild/libzentra_wallet_ffi.a" ]]; then
    cp -f "$ffibuild/libzentra_wallet_ffi.a" "$out_dir/libzentra_wallet_ffi.a"
  else
    echo "Error: FFI output not found under $ffibuild"
    return 1
  fi
  echo "==> Installed $out_dir"
  ls -la "$out_dir"
}
