#!/usr/bin/env bash
# Find and verify Android libc++_shared.so (Zentra depends NDK r17b layout).
# Sourced by native_build_android.sh and ci-verify-*.sh — do not execute directly.

# Zentra Android depends (NDK r17b) require libtinfo.so.5 on the Linux host.
android_has_libtinfo5() {
  ldconfig -p 2>/dev/null | grep -q 'libtinfo.so.5' && return 0
  [[ -e /lib/x86_64-linux-gnu/libtinfo.so.5 ]] && return 0
  [[ -e /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ]] && return 0
  return 1
}

# Find libc++ matching the NDK used to build libzentra_wallet_ffi.so.
# Prints absolute path on success; returns 1 if not found.
android_find_libcxx_shared() {
  local zentra_root="$1" abi="$2" triple="$3"
  local lib="" sdks="$zentra_root/contrib/depends/SDKs"

  # NDK r17b (Zentra depends android_ndk): sources/cxx-stl layout
  if [[ -d "$sdks" ]]; then
    lib="$(find "$sdks" -path "*/sources/cxx-stl/llvm-libc++/libs/${abi}/libc++_shared.so" 2>/dev/null | head -1)"
    if [[ -f "$lib" ]]; then
      echo "$lib"
      return 0
    fi

    # Newer NDK sysroot layout (if depends ever bumps NDK)
    lib="$(find "$sdks" -path "*/$triple/libc++_shared.so" 2>/dev/null | head -1)"
    if [[ -f "$lib" ]]; then
      echo "$lib"
      return 0
    fi
  fi

  # Depends work tree (android_ndk package; SDKs/ may be absent on local builds)
  lib="$(find "$zentra_root/contrib/depends/work" -path "*/sources/cxx-stl/llvm-libc++/libs/${abi}/libc++_shared.so" 2>/dev/null | head -1)"
  if [[ -f "$lib" ]]; then
    echo "$lib"
    return 0
  fi

  # Per-host native sysroot shipped with depends prefix
  lib="$(find "$zentra_root/contrib/depends" -maxdepth 6 -path "*/native/${triple}/lib/libc++_shared.so" 2>/dev/null | head -1)"
  if [[ -f "$lib" ]]; then
    echo "$lib"
    return 0
  fi

  return 1
}

android_has_depends_ndk() {
  local zentra_root="$1"
  local sdks="$zentra_root/contrib/depends/SDKs"
  if [[ -d "$sdks" ]] && find "$sdks" -maxdepth 1 -type d -name 'android-ndk-*' 2>/dev/null | grep -q .; then
    return 0
  fi
  find "$zentra_root/contrib/depends/work" -path '*/android-ndk-*/sources/cxx-stl/llvm-libc++' 2>/dev/null | grep -q . \
    || find "$zentra_root/contrib/depends" -maxdepth 6 -name 'libc++_shared.so' 2>/dev/null | grep -q .
}

# Optional Flutter/SDK NDK fallback — only when Zentra depends NDK was not built.
android_find_libcxx_shared_fallback() {
  local triple="$1"
  local ndk="${ANDROID_NDK:-${ANDROID_NDK_HOME:-}}"
  if [[ -z "$ndk" && -n "${ANDROID_HOME:-}" ]]; then
    ndk="$(find "$ANDROID_HOME/ndk" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
  fi
  [[ -n "$ndk" ]] || return 1
  local lib="$ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$triple/libc++_shared.so"
  [[ -f "$lib" ]] || return 1
  echo "$lib"
}

# Reject wrong/stripped libc++ in engine bundle or APK (bytes on disk / in zip).
android_verify_libcxx_shared_size() {
  local file="$1" abi="$2" context="${3:-libc++_shared.so}"
  local size min max
  size="$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")"

  case "$abi" in
    arm64-v8a) min=900000 max=3000000 ;;
    armeabi-v7a) min=400000 max=2000000 ;;
    x86_64) min=900000 max=3000000 ;;
    x86) min=400000 max=2000000 ;;
    *)
      echo "::error::Unknown ABI for libc++ verify: $abi"
      return 1
      ;;
  esac

  if [[ "$size" -lt "$min" || "$size" -gt "$max" ]]; then
    echo "::error::${context} size ${size} bytes out of range [${min}, ${max}] for ${abi}"
    echo "       Likely wrong NDK libc++ or Gradle stripped libc++ in APK."
    return 1
  fi
  echo "  OK ${context} size ${size} bytes (${abi})"
  return 0
}
