# Build guide — iOS (manual, no CI)

Build **iPhone / iPad** app with the full **wallet2** engine.

**Must run on:** **macOS** with full **Xcode** (not CLT alone for all steps).

**Output:**

- `packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework`
- `build/ios/iphoneos/Runner.app` (or Release-iphoneos path)

**Zentra pin:** [v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)

---

## 1. What you need

| Item | Details |
|------|---------|
| **Mac** | Apple Silicon or Intel |
| **Xcode** | From App Store; `xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| **Homebrew** | cmake, protobuf, curl, git, … |
| **Flutter** | iOS toolchain (`flutter doctor`) |
| **Apple Developer account** | Only for **device install / TestFlight / App Store** |
| **Disk** | ~20–40 GB for deps + builds |
| **Time** | First run: **several hours** (deps + Zentra × 2 SDKs) |

---

## 2. Install tools

```bash
# Xcode from App Store, then:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version

brew install cmake python3 pkg-config openssl protobuf boost curl git
```

Flutter: [https://docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos)

```bash
flutter doctor
```

Fix any iOS / CocoaPods issues `flutter doctor` reports.

---

## 3. Clone repositories

```bash
git clone https://github.com/Zentra-Privacy/zentra_wallet.git
cd zentra_wallet

git clone -b v0.1.0 --recurse-submodules \
  https://github.com/Zentra-Privacy/zentra.git third_party/zentra
```

Verify:

```bash
test -f third_party/zentra/src/wallet/api/wallet2_api.h && echo OK
```

---

## 4. Build native XCFramework

```bash
./wallet.sh status
./wallet.sh build-ios
```

### What this does

| Step | Result |
|------|--------|
| `native_build_ios_deps.sh` | OpenSSL, libsodium, ICU, Boost, Protobuf for **iphoneos** + **iphonesimulator** |
| Zentra `wallet_api` | `-DIOS=ON` per SDK → static libs |
| FFI `-DFFI_IOS=ON` | `libzentra_wallet_ffi.a` per SDK |
| `xcodebuild -create-xcframework` | `zentra_wallet_ffi.xcframework` |

Verify:

```bash
ls packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework
```

**Cache:** second run is faster if `build/ios-deps/` is intact.

**Host `protoc` required:**

```bash
brew install protobuf
which protoc
```

---

## 5. Build the Flutter iOS app

```bash
flutter pub get
cd ios
pod install --repo-update
cd ..
```

### Simulator (no signing)

```bash
flutter build ios --simulator
flutter run -d "iPhone 16"   # pick simulator from flutter devices
```

### Physical iPhone / iPad (signing required)

1. Build native engine first (required — CI does not do this):

   ```bash
   ./wallet.sh build-ios
   ls packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework
   ```

2. Install pods:

   ```bash
   flutter pub get
   cd ios && pod install --repo-update && cd ..
   ```

3. Open Xcode and set signing:

   ```bash
   open ios/Runner.xcworkspace
   ```

   - **Runner** → **Signing & Capabilities** → select your **Team**
   - Connect the device via USB; select it as run destination

4. Run on device:

   ```bash
   flutter devices
   flutter run -d <your-iphone-id> --release
   ```

   Or press **Run** in Xcode.

5. First launch on device: **Settings → General → VPN & Device Management** → trust the developer cert if iOS asks.

### Unsigned release (CI-style / sideload prep)

```bash
flutter build ios --release --no-codesign
```

**.app path (varies by Flutter version):**

```text
build/ios/iphoneos/Runner.app
# or
build/ios/Release-iphoneos/Runner.app
```

Zip:

```bash
APP="build/ios/iphoneos/Runner.app"
test -d "$APP" || APP="build/ios/Release-iphoneos/Runner.app"
ditto -c -k --sequesterRsrc --keepParent "$APP" zentra-wallet-ios.zip
```

---

## 6. App Store / TestFlight (optional)

```bash
flutter build ipa
```

Requires:

- Paid **Apple Developer Program**
- Provisioning profile + distribution certificate in Xcode

Upload with **Transporter** or Xcode **Organizer**.

---

## 7. Verify

| Check | Expected |
|-------|----------|
| XCFramework | Directory exists under `ios/lib/` |
| `pod install` | No error about missing `zentra_wallet_ffi.xcframework` |
| App runs | No “Wallet engine unavailable” |
| Wallet | Create/restore works |

```bash
./wallet.sh status
```

---

## 8. Troubleshooting

| Problem | Fix |
|---------|-----|
| `build-ios` fails at OpenSSL | Xcode 14+; full Xcode selected in `xcode-select` |
| Missing `protoc` | `brew install protobuf` |
| Pod: XCFramework missing | Run `./wallet.sh build-ios` first |
| Engine unavailable | Clean: `flutter clean`, rebuild ios, `pod install` |
| Signing errors | Set Team in Xcode; use `--no-codesign` for unsigned test |
| Boost / ICU errors | `rm -rf build/ios-deps` and re-run `build-ios` |

---

## 9. Relation to macOS build

| Command | Output |
|---------|--------|
| `./wallet.sh build-macos` | macOS `.dylib` |
| `./wallet.sh build-ios` | iOS `.xcframework` |

You can run both on the same Mac. They share Zentra source but use different toolchains.

---

## See also

- [build-macos.md](build-macos.md)
- [building.md](building.md)
- [download-builds.md](download-builds.md)
