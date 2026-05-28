#!/usr/bin/env bash
# Build Flutter app bundles for each supported platform on this host.
# Requires WALLET_ROOT and sourced wallet helpers (native_build_*, _resolve_zentra).

build_apps_flutter_pub() {
  (cd "${WALLET_ROOT:?}" && flutter pub get)
}

build_apps_macos_native() {
  local z="$1"
  native_build_macos "$z"
}

package_apple_dist() {
  local root="${WALLET_ROOT:?}"
  local dist="$root/dist/apple"
  mkdir -p "$dist"
  local mac_app="$root/build/macos/Build/Products/Profile/zentra_wallet.app"
  [[ -d "$mac_app" ]] || mac_app="$root/build/macos/Build/Products/Release/zentra_wallet.app"
  if [[ -d "$mac_app" ]]; then
    ditto -c -k --sequesterRsrc --keepParent "$mac_app" "$dist/zentra-wallet-macos.zip"
    echo "==> macOS zip: $dist/zentra-wallet-macos.zip"
  fi
  local ios_app
  for ios_app in \
    "$root/build/ios/iphoneos/Runner.app" \
    "$root/build/ios/Release-iphoneos/Runner.app" \
    "$root/build/ios/iphonesimulator/Runner.app"; do
    if [[ -d "$ios_app" ]]; then
      local name
      name="$(basename "$(dirname "$ios_app")")-Runner.app.zip"
      ditto -c -k --sequesterRsrc --keepParent "$ios_app" "$dist/$name"
      echo "==> iOS zip: $dist/$name"
    fi
  done
  ls -lh "$dist" 2>/dev/null || true
}

build_apps_macos_flutter() {
  local root="${WALLET_ROOT:?}"
  local dylib="$root/packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib"
  [[ -f "$dylib" ]] || {
    echo "Error: macOS FFI missing — run: ./wallet.sh build-macos"
    return 1
  }
  (cd "$root/macos" && pod install)
  # Production on Mac without Apple cert: profile + ad-hoc. Set MACOS_FLUTTER_BUILD_MODE=release when Signing.xcconfig exists.
  local mode="${MACOS_FLUTTER_BUILD_MODE:-profile}"
  if [[ "${BUILD_PRODUCTION:-0}" == "1" && -f "$root/macos/Runner/Configs/Signing.xcconfig" ]]; then
    mode="release"
  fi
  echo "==> flutter build macos --$mode (arm64)"
  (
    cd "$root"
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES EXCLUDED_ARCHS=x86_64 \
      flutter build "macos" "--$mode"
  )
  local app
  case "$mode" in
    profile) app="$root/build/macos/Build/Products/Profile/zentra_wallet.app" ;;
    release) app="$root/build/macos/Build/Products/Release/zentra_wallet.app" ;;
    debug) app="$root/build/macos/Build/Products/Debug/zentra_wallet.app" ;;
    *) echo "Error: unknown MACOS_FLUTTER_BUILD_MODE=$mode"; return 1 ;;
  esac
  [[ -d "$app" ]] || {
    echo "Error: expected app at $app"
    return 1
  }
  echo "==> macOS app: $app"
  if [[ "${BUILD_PRODUCTION:-0}" == "1" ]]; then
    package_apple_dist
  fi
}

build_apps_ios_native() {
  local z="$1"
  native_build_ios "$z"
}

build_apps_ios_flutter() {
  local root="${WALLET_ROOT:?}"
  local xcf="$root/packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework"
  [[ -d "$xcf" ]] || {
    echo "Error: iOS XCFramework missing — run: ./wallet.sh build-ios"
    return 1
  }
  build_apps_flutter_pub
  (cd "$root/ios" && pod install --repo-update)
  local target="${IOS_FLUTTER_TARGET:-simulator}"
  if [[ "${BUILD_PRODUCTION:-0}" == "1" ]]; then
    target="device"
  fi
  case "$target" in
    simulator)
      echo "==> flutter build ios --simulator (no signing)"
      (cd "$root" && flutter build ios --simulator)
      echo "==> iOS simulator .app under build/ios/iphonesimulator/"
      ;;
    device|release)
      if security find-identity -p codesigning -v 2>/dev/null | grep -q "Apple Development"; then
        echo "==> flutter build ios --release"
        (cd "$root" && flutter build ios --release)
      else
        echo "==> No Apple Development cert — flutter build ios --release --no-codesign (sideload / re-sign for TestFlight)"
        (cd "$root" && flutter build ios --release --no-codesign)
      fi
      echo "==> iOS device build under build/ios/iphoneos/ or build/ios/Release-iphoneos/"
      ;;
    *)
      echo "Error: IOS_FLUTTER_TARGET must be simulator or device (got: $target)"
      return 1
      ;;
  esac
  if [[ "${BUILD_PRODUCTION:-0}" == "1" ]]; then
    package_apple_dist
  fi
}

build_apps_android_flutter() {
  local root="${WALLET_ROOT:?}"
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Error: flutter not in PATH"
    return 1
  fi
  if ! flutter doctor -v 2>/dev/null | grep -q "Android toolchain.*✓"; then
    echo "Error: Android SDK not configured (flutter doctor). Install Android Studio, then:"
    echo "  flutter config --android-sdk <path>"
    echo "  flutter doctor --android-licenses"
    return 1
  fi
  local jni="$root/packages/zentra_wallet_core/android/src/main/jniLibs/arm64-v8a/libzentra_wallet_ffi.so"
  [[ -f "$jni" ]] || {
    echo "Error: Android FFI missing — on Linux run: ./wallet.sh build-android"
    return 1
  }
  build_apps_flutter_pub
  echo "==> flutter build apk --release"
  (cd "$root" && flutter build apk --release)
  echo "==> APK: $root/build/app/outputs/flutter-apk/app-release.apk"
}

# Build macOS + iOS native engines and Flutter apps (Darwin only).
build_apps_darwin() {
  local z="$1"
  local skip_native="${BUILD_APPS_SKIP_NATIVE:-0}"
  echo "========================================"
  echo "  Zentra Wallet — build apps (macOS host)"
  echo "========================================"

  if [[ "$skip_native" != "1" ]]; then
    build_apps_macos_native "$z" || return 1
    build_apps_ios_native "$z" || return 1
  fi

  build_apps_flutter_pub || return 1
  build_apps_macos_flutter || return 1
  build_apps_ios_flutter || return 1
  package_apple_dist || true

  echo ""
  echo "==> Ship files: ${WALLET_ROOT:?}/dist/apple/"
  echo "==> Android: native libs need Linux — see docs/build-android.md"
  echo "==> Windows: DLL needs Linux MinGW — see docs/build-windows.md"
  echo "==> App Store / TestFlight: Apple Developer signing required (Xcode Team + flutter build ios --release)"
  echo "========================================"
  echo "  Done (macOS + iOS on this Mac)"
  echo "========================================"
}

# Production Apple builds: native engines + macOS app + unsigned iOS device .app → dist/apple/
build_apple_production() {
  local z="$1"
  export BUILD_PRODUCTION=1
  export IOS_FLUTTER_TARGET=device
  build_apps_darwin "$z"
}

build_apps_linux() {
  local z="$1"
  echo "========================================"
  echo "  Zentra Wallet — build apps (Linux host)"
  echo "========================================"
  native_build_host "$z" || return 1
  build_apps_flutter_pub || return 1
  echo "==> flutter build linux --release"
  (cd "${WALLET_ROOT:?}" && flutter build linux --release)
  echo "==> Linux binary under build/linux/x64/release/bundle/"
  if [[ "${BUILD_APPS_ANDROID:-1}" == "1" ]]; then
    native_build_android "$z" || return 1
    build_apps_android_flutter || return 1
  fi
  echo "========================================"
  echo "  Done (Linux + optional Android)"
  echo "========================================"
}

build_apps_auto() {
  local z="$1"
  [[ -n "$z" ]] || z="$(native_resolve_zentra)" || {
    echo "Error: Zentra source not found"
    return 1
  }
  case "$(uname -s)" in
    Darwin) build_apps_darwin "$z" ;;
    Linux) build_apps_linux "$z" ;;
    *)
      echo "Error: build-apps on $(uname -s) — use Linux or macOS"
      echo "  Windows: build DLL on Linux, then flutter build windows on Windows"
      return 1
      ;;
  esac
}
