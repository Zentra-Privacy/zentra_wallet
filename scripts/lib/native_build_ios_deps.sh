#!/usr/bin/env bash
# Build OpenSSL, ICU, and Boost for iOS (device + simulator). macOS + Xcode required.
# Usage: native_build_ios_deps [prefix_root]
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=native_build_common.sh
source "$_LIB_DIR/native_build_common.sh"

native_build_ios_deps() {
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
  local CC
  CC="$(xcrun --sdk "$SDK_NAME" -find clang)"
  local CXX
  CXX="$(xcrun --sdk "$SDK_NAME" -find clang++)"
  local ARCH_FLAGS="-arch arm64 -isysroot ${SDK_PATH} -m${SDK_NAME}-version-min=${MIN_IOS}"
  export CC="${CC} ${ARCH_FLAGS}"
  export CXX="${CXX} ${ARCH_FLAGS} -stdlib=libc++"
  export CFLAGS="${ARCH_FLAGS}"
  export CXXFLAGS="${ARCH_FLAGS} -stdlib=libc++"
  export LDFLAGS="${ARCH_FLAGS} -stdlib=libc++"
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
  local ICUROOT="$DL/icu-${ICU_VER//./-}"
  if [[ ! -d "$ICUSRC/source" ]]; then
    curl -fsSL "https://github.com/unicode-org/icu/releases/download/release-${ICU_VER//./-}/icu4c-${ICU_VER}_2-src.tgz" \
      -o "$DL/icu.tgz"
    tar -xzf "$DL/icu.tgz" -C "$DL"
  fi
  [[ -d "$ICUSRC/source" ]] || {
    echo "Error: ICU source missing at $ICUSRC/source"
    return 1
  }
  local ICU_HOST_BUILD="$DL/icu-host"
  if [[ ! -f "$ICU_HOST_BUILD/source/Makefile" ]]; then
    rm -rf "$ICU_HOST_BUILD"
    cp -R "$ICUSRC" "$ICU_HOST_BUILD"
    (cd "$ICU_HOST_BUILD/source" && ./configure --disable-shared --enable-static && make -j"$JOBS")
  fi
  local ICUBUILD="$ICUSRC/build-${SDK_NAME}"
  rm -rf "$ICUBUILD"
  mkdir -p "$ICUBUILD"
  local IOS_HOST="arm-apple-darwin"
  [[ "$SDK_NAME" == "iphonesimulator" ]] && IOS_HOST="arm-apple-darwin"
  (cd "$ICUBUILD" && ../source/configure \
    --host="$IOS_HOST" \
    --with-cross-build="$ICU_HOST_BUILD/source" \
    --prefix="$PREFIX" \
    --disable-shared --enable-static \
    CXX="$CXX" CC="$CC" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
    && make -j"$JOBS" && make install)

  echo "==> Boost $BOOST_VER for $SDK_NAME"
  local BOOST_SRC="$DL/boost_${BOOST_VER//./_}"
  if [[ ! -d "$BOOST_SRC" ]]; then
    curl -fsSL "https://archives.boost.io/release/${BOOST_VER}/source/boost_${BOOST_VER//./_}.tar.gz" \
      -o "$DL/boost.tgz"
    tar -xzf "$DL/boost.tgz" -C "$DL"
  fi
  (cd "$BOOST_SRC" && ./bootstrap.sh --prefix="$PREFIX")
  local B2_TARGET_OS=iphone
  [[ "$SDK_NAME" == "iphonesimulator" ]] && B2_TARGET_OS=iphonesimulator
  local IOS_B2_FLAGS=(
    toolset=clang
    target-os="${B2_TARGET_OS}"
    architecture=arm
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

  echo "==> Protobuf $PROTOBUF_VER for $SDK_NAME"
  local PBSRC="$DL/protobuf-${PROTOBUF_VER}"
  if [[ ! -d "$PBSRC" ]]; then
    curl -fsSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VER}/protobuf-${PROTOBUF_VER}.tar.gz" \
      -o "$DL/protobuf.tgz"
    tar -xzf "$DL/protobuf.tgz" -C "$DL"
  fi
  local PBBUILD="$PBSRC/build-${SDK_NAME}"
  rm -rf "$PBBUILD"
  local PROTOC
  PROTOC="$(command -v protoc || true)"
  [[ -n "$PROTOC" ]] || {
    echo "Error: host protoc required (brew install protobuf)"
    return 1
  }
  cmake -S "$PBSRC" -B "$PBBUILD" \
    -DCMAKE_TOOLCHAIN_FILE="$ROOT/native/zentra_wallet_ffi/cmake/ios.toolchain.cmake" \
    -DIOS_SDK="$SDK_NAME" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
    -Dprotobuf_INSTALL=ON \
    -DProtobuf_PROTOC_EXECUTABLE="$PROTOC" \
    || return 1
  cmake --build "$PBBUILD" --target install --parallel "$JOBS" || return 1

  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP"
  echo "==> iOS deps ready: $PREFIX"
}
