#!/usr/bin/env bash
# Build libzentra_wallet_ffi for iOS (device + simulator XCFramework). macOS + Xcode required.
# Usage: native_build_ios [zentra_root]
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"
# shellcheck source=native_build_ios_deps.sh
source "$_LIB_DIR/native_build_ios_deps.sh"

native_build_ios() {
  local ZENTRA_ROOT="${1:-}"
  local ROOT="${WALLET_ROOT:?}"
  local JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
  local OUT="$ROOT/packages/zentra_wallet_core/ios/lib"
  local DEPS_BASE="${IOS_DEPS_ROOT:-$ROOT/build/ios-deps}"
  local XCFRAMEWORK="$OUT/zentra_wallet_ffi.xcframework"
  local HDR="$ROOT/native/zentra_wallet_ffi/include"

  [[ "$(uname -s)" == "Darwin" ]] || {
    echo "Error: iOS builds require macOS with Xcode"
    return 1
  }
  [[ -n "$ZENTRA_ROOT" ]] || ZENTRA_ROOT="$(native_resolve_zentra)" || {
    echo "Error: Zentra source not found"
    return 1
  }

  native_build_ios_deps "$DEPS_BASE"

  mkdir -p "$OUT"
  rm -rf "$XCFRAMEWORK"
  local -a XCF_ARGS=()

  for sdk in iphoneos iphonesimulator; do
    local PREFIX="$DEPS_BASE/$sdk"
    local PLATFORM_TAG="ios-${sdk}"
    local ZBUILD="$ZENTRA_ROOT/build/${PLATFORM_TAG}/release"
    local FFIBUILD="$ROOT/build/native_ffi/${PLATFORM_TAG}"
    local ARCH_FLAG="-DARCH=arm64"
    local IOS_PLATFORM="OS"
    [[ "$sdk" == "iphonesimulator" ]] && IOS_PLATFORM="SIMULATOR64"

    local PROTOC
    PROTOC="$(command -v protoc || true)"
    [[ -n "$PROTOC" ]] || {
      echo "Error: host protoc required for Zentra (brew install protobuf)"
      return 1
    }

    echo "==> Zentra wallet_api ($PLATFORM_TAG)"
    rm -rf "$ZBUILD"
    mkdir -p "$ZBUILD"
    cmake -S "$ZENTRA_ROOT" -B "$ZBUILD" \
      -DIOS=ON \
      -DIOS_PLATFORM="$IOS_PLATFORM" \
      $ARCH_FLAG \
      -DCMAKE_BUILD_TYPE=Release \
      -DSTATIC=ON \
      -DBUILD_TESTS=OFF \
      -DBUILD_DOCUMENTATION=OFF \
      -DMANUAL_SUBMODULES=1 \
      -DBUILD_GUI_DEPS=ON \
      -DUSE_DEVICE_TREZOR=OFF \
      -DProtobuf_PROTOC_EXECUTABLE="$PROTOC" \
      -DBoost_NO_BOOST_CMAKE=ON \
      -DBoost_USE_STATIC_LIBS=ON \
      -DBoost_INCLUDE_DIR="$PREFIX/include" \
      -DBoost_LIBRARY_DIR="$PREFIX/lib" \
      -DOPENSSL_ROOT_DIR="$PREFIX" \
      -DOPENSSL_INCLUDE_DIR="$PREFIX/include" \
      -DOPENSSL_LIBRARIES="$PREFIX/lib/libssl.a;$PREFIX/lib/libcrypto.a" \
      -DProtobuf_ROOT="$PREFIX" \
      -DCMAKE_PREFIX_PATH="$PREFIX" \
      || return 1
    cmake --build "$ZBUILD" --target wallet_api --parallel "$JOBS" || return 1
    [[ -f "$ZBUILD/lib/libwallet_api.a" ]] || {
      echo "Error: $ZBUILD/lib/libwallet_api.a missing"
      return 1
    }

    echo "==> FFI static lib ($PLATFORM_TAG)"
    rm -rf "$FFIBUILD"
    cmake -S "$ROOT/native/zentra_wallet_ffi" -B "$FFIBUILD" \
      -DCMAKE_TOOLCHAIN_FILE="$ROOT/native/zentra_wallet_ffi/cmake/ios.toolchain.cmake" \
      -DIOS_SDK="$sdk" \
      -DFFI_IOS=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DZENTRA_ROOT="$ZENTRA_ROOT" \
      -DZENTRA_BUILD_DIR="$ZBUILD" \
      -DIOS_DEPS_PREFIX="$PREFIX" \
      -DBoost_NO_BOOST_CMAKE=ON \
      -DBoost_USE_STATIC_LIBS=ON \
      -DBoost_INCLUDE_DIR="$PREFIX/include" \
      -DBoost_LIBRARY_DIR="$PREFIX/lib" \
      -DOPENSSL_ROOT_DIR="$PREFIX" \
      -DProtobuf_ROOT="$PREFIX" \
      -DCMAKE_PREFIX_PATH="$PREFIX" \
      || return 1
    cmake --build "$FFIBUILD" --parallel "$JOBS" || return 1
    [[ -f "$FFIBUILD/libzentra_wallet_ffi.a" ]] || {
      echo "Error: $FFIBUILD/libzentra_wallet_ffi.a missing"
      return 1
    }

    local SLICE="$OUT/build-${sdk}"
    mkdir -p "$SLICE"
    cp -f "$FFIBUILD/libzentra_wallet_ffi.a" "$SLICE/"
    XCF_ARGS+=(-library "$SLICE/libzentra_wallet_ffi.a" -headers "$HDR")
  done

  echo "==> Creating XCFramework"
  xcodebuild -create-xcframework "${XCF_ARGS[@]}" -output "$XCFRAMEWORK"
  rm -rf "$OUT/build-iphoneos" "$OUT/build-iphonesimulator"
  echo "==> iOS XCFramework ready for flutter build ios"
  ls -la "$OUT"
}
