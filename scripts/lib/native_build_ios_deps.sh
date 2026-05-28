#!/usr/bin/env bash
# Build OpenSSL, ICU, and Boost for iOS (device + simulator). macOS + Xcode required.
# Usage: native_build_ios_deps [prefix_root]
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"

_ios_deps_ensure_path() {
  export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
}

_ios_deps_find_tool() {
  local name="$1"
  local t
  t="$(command -v "$name" 2>/dev/null || true)"
  [[ -n "$t" && -x "$t" ]] && { echo "$t"; return 0; }
  for t in "/opt/homebrew/bin/$name" "/usr/local/bin/$name"; do
    [[ -x "$t" ]] && { echo "$t"; return 0; }
  done
  return 1
}

# FindBoost expects libboost_<component>.a; b2 tagged layout emits -mt-s-a64 suffixes.
_ios_deps_boost_symlinks() {
  local libdir="$1/lib"
  local f base link
  [[ -d "$libdir" ]] || return 0
  for f in "$libdir"/libboost_*-mt-s-a64.a; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f" .a)
    link="${base%-mt-s-a64}.a"
    ln -sf "$(basename "$f")" "$libdir/$link"
  done
}

native_build_ios_deps() {
  _ios_deps_ensure_path
  local ROOT="${WALLET_ROOT:?}"
  local BASE="${1:-$ROOT/build/ios-deps}"
  local JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
  local OPENSSL_VER="${IOS_OPENSSL_VERSION:-3.0.15}"
  local BOOST_VER="${IOS_BOOST_VERSION:-1.84.0}"
  local ICU_VER="${IOS_ICU_VERSION:-73.2}"
  local PROTOBUF_VER="${IOS_PROTOBUF_VERSION:-21.12}"
  local MIN_IOS="${IOS_MIN_VERSION:-13.0}"

  [[ "$(uname -s)" == "Darwin" ]] || {
    echo "Error: iOS native deps require macOS with Xcode"
    return 1
  }
  xcode-select -p >/dev/null 2>&1 || {
    echo "Error: Xcode command-line tools not found"
    return 1
  }

  for sdk in iphoneos iphonesimulator; do
    _ios_deps_one "$BASE" "$sdk" "$JOBS" "$OPENSSL_VER" "$BOOST_VER" "$ICU_VER" "$PROTOBUF_VER" "$MIN_IOS"
  done
}

_ios_deps_one() {
  local BASE="$1" SDK_NAME="$2" JOBS="$3" OPENSSL_VER="$4" BOOST_VER="$5" ICU_VER="$6" PROTOBUF_VER="$7" MIN_IOS="$8"
  local ROOT="${WALLET_ROOT:?}"
  local PREFIX="$BASE/$SDK_NAME"
  local STAMP="$PREFIX/.deps-ready"
  [[ -f "$STAMP" ]] && {
    echo "==> iOS deps cached: $PREFIX"
    return 0
  }

  local SDK_PATH
  SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
  local CLANG_BIN CLANGXX_BIN
  CLANG_BIN="$(xcrun --sdk "$SDK_NAME" -find clang)"
  CLANGXX_BIN="$(xcrun --sdk "$SDK_NAME" -find clang++)"
  local ARCH_FLAGS="-arch arm64 -isysroot ${SDK_PATH} -m${SDK_NAME}-version-min=${MIN_IOS}"
  # Fresh toolchain env per SDK (avoid iphoneos + iphonesimulator flags mixing in CMake).
  unset CFLAGS CXXFLAGS LDFLAGS SDKROOT DEVELOPER_DIR CC CXX
  export CC="${CLANG_BIN} ${ARCH_FLAGS}"
  export CXX="${CLANGXX_BIN} ${ARCH_FLAGS} -stdlib=libc++"
  export CFLAGS="${ARCH_FLAGS}"
  export CXXFLAGS="${ARCH_FLAGS} -stdlib=libc++"
  export LDFLAGS="${ARCH_FLAGS}"
  export SDKROOT="$SDK_PATH"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$(xcrun --sdk "$SDK_NAME" -find clang | xargs dirname)"

  mkdir -p "$PREFIX/include" "$PREFIX/lib"
  local DL="$ROOT/build/ios-deps-src"
  mkdir -p "$DL"

  echo "==> OpenSSL $OPENSSL_VER for $SDK_NAME"
  local OSSRC="$DL/openssl-${OPENSSL_VER}-${SDK_NAME}"
  if [[ ! -d "$OSSRC" ]]; then
    local OSSL_TAR="$DL/openssl-${OPENSSL_VER}.tar.gz"
    [[ -f "$OSSL_TAR" ]] || curl -fsSL "https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz" -o "$OSSL_TAR"
    rm -rf "$OSSRC"
    mkdir -p "$OSSRC"
    tar -xzf "$OSSL_TAR" -C "$OSSRC" --strip-components=1
  fi
  if [[ "$SDK_NAME" == "iphoneos" ]]; then
    (cd "$OSSRC" && ./Configure ios64-xcrun --prefix="$PREFIX" --openssldir="$PREFIX" no-shared)
  else
    (cd "$OSSRC" && ./Configure iossimulator-xcrun --prefix="$PREFIX" --openssldir="$PREFIX" no-shared)
  fi
  (cd "$OSSRC" && make -j"$JOBS" && make install_sw)

  echo "==> libsodium for $SDK_NAME"
  local SODIUM_SRC="$DL/libsodium"
  if [[ ! -d "$SODIUM_SRC" ]]; then
    git clone --depth 1 --branch 1.0.19-RELEASE https://github.com/jedisct1/libsodium.git "$SODIUM_SRC"
  fi
  [[ -f "$SODIUM_SRC/configure" ]] || (cd "$SODIUM_SRC" && ./autogen.sh -s)
  local SODIUM_BUILD="$SODIUM_SRC/build-${SDK_NAME}"
  rm -rf "$SODIUM_BUILD"
  mkdir -p "$SODIUM_BUILD"
  (cd "$SODIUM_BUILD" && ../configure --prefix="$PREFIX" --disable-shared --enable-static \
    --host=aarch64-apple-darwin10 \
    CC="$CC" CXX="$CXX" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
    && make -j"$JOBS" && make install)

  echo "==> ICU $ICU_VER for $SDK_NAME"
  local ICUSRC="$DL/icu"
  local ICU_RELEASE_TAG="release-${ICU_VER//./-}"
  local ICU_ARCHIVE_VER="${ICU_VER//./_}"
  if [[ ! -d "$ICUSRC/source" ]]; then
    local ICU_TAR="$DL/icu4c-${ICU_ARCHIVE_VER}-src.tgz"
    [[ -f "$ICU_TAR" ]] || curl -fsSL \
      "https://github.com/unicode-org/icu/releases/download/${ICU_RELEASE_TAG}/icu4c-${ICU_ARCHIVE_VER}-src.tgz" \
      -o "$ICU_TAR"
    rm -rf "$ICUSRC"
    tar -xzf "$ICU_TAR" -C "$DL"
    [[ -d "$ICUSRC/source" ]] || {
      echo "Error: ICU extract failed (expected $ICUSRC/source)"
      return 1
    }
  fi
  [[ -d "$ICUSRC/source" ]] || {
    echo "Error: ICU source missing at $ICUSRC/source"
    return 1
  }
  local ICU_HOST_BUILD="$DL/icu-host"
  local ICU_HOST_MARKER="$ICU_HOST_BUILD/.host-macos-built"
  if [[ ! -f "$ICU_HOST_MARKER" ]]; then
    rm -rf "$ICU_HOST_BUILD"
    cp -R "$ICUSRC" "$ICU_HOST_BUILD"
    # Host ICU tools (genrb, pkgdata, …) must run on macOS — not with iPhone SDK flags.
    (
      unset DEVELOPER_DIR IPHONEOS_DEPLOYMENT_TARGET
      export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
      unset CFLAGS CXXFLAGS LDFLAGS CC CXX
      export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
      export CC="$(xcrun --sdk macosx -find clang)"
      export CXX="$(xcrun --sdk macosx -find clang++)"
      cd "$ICU_HOST_BUILD/source"
      ./configure --disable-shared --enable-static
      make -j"$JOBS"
    ) || return 1
    touch "$ICU_HOST_MARKER"
  fi
  local ICUBUILD="$ICUSRC/build-${SDK_NAME}"
  rm -rf "$ICUBUILD"
  mkdir -p "$ICUBUILD"
  local IOS_HOST="arm-apple-darwin"
  [[ "$SDK_NAME" == "iphonesimulator" ]] && IOS_HOST="arm-apple-darwin"
  local CROSS_BUILD
  CROSS_BUILD="$(cd "$ICU_HOST_BUILD/source" && pwd)"
  (cd "$ICUBUILD" && ../source/configure \
    --host="$IOS_HOST" \
    --with-cross-build="$CROSS_BUILD" \
    --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --disable-tools \
    CXX="$CXX" CC="$CC" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
    && PATH="$CROSS_BUILD/bin:${PATH}" make -j"$JOBS" && make install)

  local BOOST_SRC="$DL/boost_${BOOST_VER//./_}"
  if [[ ! -d "$BOOST_SRC" ]]; then
    curl -fsSL "https://archives.boost.io/release/${BOOST_VER}/source/boost_${BOOST_VER//./_}.tar.gz" \
      -o "$DL/boost.tgz"
    tar -xzf "$DL/boost.tgz" -C "$DL"
  fi
  local B2_STAMP="$DL/boost-${BOOST_VER}-b2-host.stamp"
  if [[ ! -x "$BOOST_SRC/b2" ]] || [[ ! -f "$B2_STAMP" ]]; then
    echo "==> Boost bootstrap (macOS host — builds b2 tool only)"
    (
      unset CC CXX CFLAGS CXXFLAGS LDFLAGS SDKROOT DEVELOPER_DIR
      export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
      export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
      export CC="$(xcrun --sdk macosx -find clang)"
      export CXX="$(xcrun --sdk macosx -find clang++)"
      cd "$BOOST_SRC" && ./bootstrap.sh
    ) || return 1
    touch "$B2_STAMP"
  fi
  echo "==> Boost $BOOST_VER for $SDK_NAME"
  # Boost 1.84 knows target-os=iphone only (not iphonesimulator); SDK comes from CC/CXX flags.
  local -a B2_EXTRA=()
  [[ "$SDK_NAME" == "iphonesimulator" ]] && B2_EXTRA+=(define=TARGET_IPHONE_SIMULATOR)
  local IOS_B2_FLAGS=(
    toolset=clang
    target-os=iphone
    architecture=arm
    "${B2_EXTRA[@]}"
    address-model=64
    cxxflags="${CXXFLAGS} -fvisibility=hidden -fvisibility-inlines-hidden"
    linkflags="${LDFLAGS}"
    link=static
    threading=multi
    runtime-link=static
    --prefix="$PREFIX"
    --layout=tagged
    -sICU_PATH="$PREFIX"
    -sOPENSSL_INCLUDE="$PREFIX/include"
    -sOPENSSL_LIBPATH="$PREFIX/lib"
    --with-chrono --with-system --with-filesystem --with-thread
    --with-serialization --with-locale --with-regex --with-program_options --with-date_time
  )
  (cd "$BOOST_SRC" && ./b2 -j"$JOBS" "${IOS_B2_FLAGS[@]}" install)
  _ios_deps_boost_symlinks "$PREFIX"

  echo "==> Protobuf $PROTOBUF_VER for $SDK_NAME"
  local PBSRC="$DL/protobuf-${PROTOBUF_VER}"
  if [[ ! -d "$PBSRC" ]]; then
    local PB_TAR="$DL/protobuf-${PROTOBUF_VER}.tar.gz"
    if [[ ! -f "$PB_TAR" ]]; then
      # v21.12 release asset is protobuf-cpp-3.21.12; GitHub archive also works.
      if ! curl -fsSL \
        "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VER}/protobuf-cpp-3.${PROTOBUF_VER}.tar.gz" \
        -o "$PB_TAR" 2>/dev/null; then
        curl -fsSL \
          "https://github.com/protocolbuffers/protobuf/archive/refs/tags/v${PROTOBUF_VER}.tar.gz" \
          -o "$PB_TAR"
      fi
    fi
    tar -xzf "$PB_TAR" -C "$DL"
    if [[ ! -d "$PBSRC" ]]; then
      local d
      for d in "$DL"/protobuf-*; do
        [[ -d "$d" ]] && PBSRC="$d" && break
      done
    fi
    [[ -d "$PBSRC" ]] || {
      echo "Error: Protobuf extract failed under $DL"
      return 1
    }
  fi
  local PBBUILD="$PBSRC/build-${SDK_NAME}"
  rm -rf "$PBBUILD"
  local PROTOC CMAKE_BIN
  PROTOC="$(_ios_deps_find_tool protoc)" || {
    echo "Error: host protoc required — install on Mac:"
    echo "  brew install protobuf"
    return 1
  }
  CMAKE_BIN="$(_ios_deps_find_tool cmake)" || {
    echo "Error: cmake required — install on Mac:"
    echo "  brew install cmake"
    return 1
  }
  local CLANG_BIN CLANGXX_BIN
  CLANG_BIN="$(xcrun --sdk "$SDK_NAME" -find clang)"
  CLANGXX_BIN="$(xcrun --sdk "$SDK_NAME" -find clang++)"
  # CMake must not inherit CC/CXX with embedded -isysroot from the other iOS SDK.
  (
    unset CC CXX CFLAGS CXXFLAGS LDFLAGS
    export SDKROOT="$SDK_PATH"
    "$CMAKE_BIN" -S "$PBSRC" -B "$PBBUILD" \
      -DCMAKE_TOOLCHAIN_FILE="$ROOT/native/zentra_wallet_ffi/cmake/ios.toolchain.cmake" \
      -DIOS_SDK="$SDK_NAME" \
      -DCMAKE_OSX_SYSROOT="$SDK_PATH" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_C_COMPILER="$CLANG_BIN" \
      -DCMAKE_CXX_COMPILER="$CLANGXX_BIN" \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
      -DCMAKE_NO_SYSTEM_FROM_IMPORTED=ON \
      -Dprotobuf_BUILD_TESTS=OFF \
      -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
      -Dprotobuf_INSTALL=ON \
      -DProtobuf_PROTOC_EXECUTABLE="$PROTOC" \
      || exit 1
    "$CMAKE_BIN" --build "$PBBUILD" --target install --parallel "$JOBS" || exit 1
  ) || return 1

  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP"
  echo "==> iOS deps ready: $PREFIX"
}
