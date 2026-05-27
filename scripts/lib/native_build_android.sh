#!/usr/bin/env bash
# Build libzentra_wallet_ffi.so for Android ABIs and install into jniLibs/.
# Usage (sourced): native_build_android <zentra_root> [abi...]
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"
# shellcheck source=android_libcxx.sh
source "$_LIB_DIR/android_libcxx.sh"

native_build_android() {
  local ZENTRA_ROOT="$1"
  shift || true

  local ROOT="${WALLET_ROOT:?WALLET_ROOT not set}"
  local JNILIBS="$ROOT/packages/zentra_wallet_core/android/src/main/jniLibs"
  local JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
  local DEPENDS_DIR="$ZENTRA_ROOT/contrib/depends"

  if [[ ! -f "$ZENTRA_ROOT/src/wallet/api/wallet2_api.h" ]]; then
    echo "Error: Zentra wallet API not found under $ZENTRA_ROOT"
    return 1
  fi

  native_prepare_python_shim "$ROOT"
  _android_has_libtinfo() {
    ldconfig -p 2>/dev/null | grep -q 'libtinfo.so.5' && return 0
    [[ -e /lib/x86_64-linux-gnu/libtinfo.so.5 ]] && return 0
    [[ -e /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ]] && return 0
    return 1
  }
  if ! _android_has_libtinfo; then
    echo "Error: libtinfo.so.5 not found — sudo apt install libtinfo5"
    return 1
  fi

  local -a ABIS=()
  if [[ $# -gt 0 ]]; then
    ABIS=("$@")
  elif [[ -n "${ANDROID_ABIS:-}" ]]; then
    read -r -a ABIS <<< "${ANDROID_ABIS}"
  else
    ABIS=(arm64-v8a armeabi-v7a x86_64)
  fi

  _abi_host() {
    case "$1" in
      arm64-v8a) echo "aarch64-linux-android" ;;
      armeabi-v7a) echo "arm-linux-androideabi" ;;
      x86_64) echo "x86_64-linux-android" ;;
      x86) echo "i686-linux-android" ;;
      *)
        echo "Error: unknown ABI: $1 (use arm64-v8a, armeabi-v7a, x86_64, x86)" >&2
        return 1
        ;;
    esac
  }

  _abi_arch() {
    case "$1" in
      arm64-v8a) echo "aarch64" ;;
      armeabi-v7a) echo "arm" ;;
      x86_64|x86) echo "x86_64" ;;
    esac
  }

  _abi_build64() {
    case "$1" in
      arm64-v8a|x86_64) echo "ON" ;;
      *) echo "OFF" ;;
    esac
  }

  _abi_arm_arch() {
    case "$1" in
      arm64-v8a) echo "armv8-a" ;;
      armeabi-v7a) echo "armv7-a" ;;
      x86_64|x86) echo "" ;;
    esac
  }

  _build_depends() {
    local host="$1"
    local toolchain="$DEPENDS_DIR/$host/share/toolchain.cmake"
    if [[ -f "$toolchain" && "${SKIP_DEPENDS:-0}" == "1" ]]; then
      echo "==> Depends for $host (skipped, toolchain present)"
      return 0
    fi
    echo "==> Building Zentra depends for $host (first time can take 30–90 min)..."
    (
      cd "$DEPENDS_DIR"
      make HOST="$host" -j"$JOBS"
    ) || return 1
    [[ -f "$toolchain" ]] || {
      echo "Error: missing $toolchain after depends build"
      return 1
    }
  }

  _build_zentra_wallet_api() {
    local abi="$1"
    local host="$2"
    local arch="$(_abi_arch "$abi")"
    local build64="$(_abi_build64 "$abi")"
    local arm_arch="$(_abi_arm_arch "$abi")"
    local toolchain="$DEPENDS_DIR/$host/share/toolchain.cmake"
    local prefix="$DEPENDS_DIR/$host"
    local zbuild="$ZENTRA_ROOT/build/android-$abi/release"

    echo "==> Zentra wallet_api for $abi ($host)"
    rm -rf "$zbuild/CMakeCache.txt" "$zbuild/CMakeFiles" 2>/dev/null || true
    mkdir -p "$zbuild"
    local -a cmake_args=(
      -S "$ZENTRA_ROOT" -B "$zbuild"
      -DCMAKE_TOOLCHAIN_FILE="$toolchain"
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_TESTS=OFF
      -DBUILD_DOCUMENTATION=OFF
      -DMANUAL_SUBMODULES=1
      -DSTATIC=ON
      -DANDROID=ON
      -DUSE_DEVICE_TREZOR=OFF
      -DBUILD_64="$build64"
      -DOPENSSL_ROOT_DIR="$prefix"
      -DOPENSSL_INCLUDE_DIR="$prefix/include"
      -DOPENSSL_LIBRARIES="$prefix/lib/libssl.a;$prefix/lib/libcrypto.a"
    )
    if [[ -n "$arm_arch" ]]; then
      cmake_args+=(-DARCH="$arm_arch")
    fi
    cmake "${cmake_args[@]}" || return 1
    cmake --build "$zbuild" --target wallet_api --parallel "$JOBS" || return 1

    [[ -f "$zbuild/lib/libwallet_api.a" ]] || {
      echo "Error: $zbuild/lib/libwallet_api.a not found"
      return 1
    }
  }

  _build_ffi() {
    local abi="$1"
    local host="$2"
    local zbuild="$3"
    local toolchain="$DEPENDS_DIR/$host/share/toolchain.cmake"

    echo "==> FFI library for $abi"
    mkdir -p "$JNILIBS/$abi"
    native_build_ffi_cmake "$ROOT" "$ZENTRA_ROOT" "$zbuild" "$toolchain" "$JNILIBS/$abi" "android-$abi" "$JOBS" \
      -DANDROID=ON || return 1
    _bundle_android_cpp_shared "$abi" "$JNILIBS/$abi" || return 1
    echo "==> Installed $JNILIBS/$abi/libzentra_wallet_ffi.so ($(du -h "$JNILIBS/$abi/libzentra_wallet_ffi.so" | cut -f1))"
  }

  _bundle_android_cpp_shared() {
    local abi="$1" dest="$2"
    local triple lib=""
    case "$abi" in
      arm64-v8a) triple=aarch64-linux-android ;;
      armeabi-v7a) triple=arm-linux-androideabi ;;
      x86_64) triple=x86_64-linux-android ;;
      x86) triple=i686-linux-android ;;
      *) return 0 ;;
    esac

    # Must match the NDK used by Zentra depends. Flutter/SDK NDK libc++ causes SIGSEGV
    # in __gxx_personality_v0 during wallet daemon connect.
    local lib=""
    lib="$(android_find_libcxx_shared "$ZENTRA_ROOT" "$abi" "$triple" || true)"
    if [[ ! -f "$lib" ]]; then
      if android_has_depends_ndk "$ZENTRA_ROOT"; then
        echo "::error::Zentra depends NDK is present but libc++_shared.so not found for $abi"
        echo "       Expected under contrib/depends/SDKs/.../sources/cxx-stl/llvm-libc++/libs/${abi}/"
        return 1
      fi
      lib="$(android_find_libcxx_shared_fallback "$triple" || true)"
      if [[ -f "$lib" ]]; then
        echo "::warning::Using SDK NDK libc++ (build Zentra depends for production/CI)"
      fi
    fi
    if [[ ! -f "$lib" ]]; then
      echo "::error::libc++_shared.so not found for $abi (build Zentra depends first, or install Android NDK)"
      return 1
    fi
    if [[ "$lib" == *"/Android/Sdk/ndk/"* ]] || [[ "$lib" == *"/android/sdk/ndk/"* ]]; then
      echo "::warning::Bundling Flutter/SDK libc++ — prefer Zentra depends NDK for release builds"
    fi
    cp -f "$lib" "$dest/libc++_shared.so"
    android_verify_libcxx_shared_size "$dest/libc++_shared.so" "$abi" "bundled libc++" || return 1
    echo "==> Bundled $dest/libc++_shared.so (from $lib)"
  }

  echo "==> Android native build"
  echo "    Zentra: $ZENTRA_ROOT"
  echo "    ABIs:   ${ABIS[*]}"

  local abi host zbuild
  for abi in "${ABIS[@]}"; do
    host="$(_abi_host "$abi")" || return 1
    _build_depends "$host" || return 1
    zbuild="$ZENTRA_ROOT/build/android-${abi}/release"
    _build_zentra_wallet_api "$abi" "$host" || return 1
    _build_ffi "$abi" "$host" "$zbuild" || return 1
  done

  echo "==> Done. Build APK: flutter build apk --release"
  echo "    Or: flutter build apk --target-platform android-arm64"
}
