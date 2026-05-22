# Build guide — macOS (manual, no CI)

Build the **macOS desktop** app with the full **wallet2** engine.

**Must run on:** a **Mac** with Xcode Command Line Tools (Apple Silicon or Intel).

**Output:**

- `packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib`
- `build/macos/Build/Products/Release/zentra_wallet.app`

**Zentra pin:** [v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)

---

## 1. What you need

| Item | Details |
|------|---------|
| **macOS** | 12+ recommended |
| **Xcode CLT** | `xcode-select --install` |
| **Homebrew** (recommended) | cmake, boost, openssl, protobuf, … |
| **Flutter** | macOS desktop enabled |
| **Time** | First native build: **1–3 hours** (Zentra depends) |

---

## 2. Install tools

### Xcode

```bash
xcode-select --install
xcode-select -p    # should print a path
```

### Homebrew packages

```bash
brew install cmake python3 pkg-config openssl protobuf boost git
```

### Flutter

[https://docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos)

```bash
flutter doctor
flutter config --enable-macos-desktop
```

---

## 3. Clone repositories

```bash
git clone https://github.com/Zentra-Privacy/zentra_wallet.git
cd zentra_wallet

git clone -b v0.1.0 --recurse-submodules \
  https://github.com/Zentra-Privacy/zentra.git third_party/zentra
```

Or sibling folder `../zentra` / `export ZENTRA_ROOT=…`

Verify:

```bash
test -f third_party/zentra/src/wallet/api/wallet2_api.h && echo OK
```

---

## 4. Build native dylib

```bash
./wallet.sh status
./wallet.sh build-macos
```

**Architecture:**

| Mac | Zentra depends HOST |
|-----|---------------------|
| Apple Silicon (M1/M2/M3) | `aarch64-apple-darwin11` |
| Intel | `x86_64-apple-darwin11` |

Verify:

```bash
ls -lh packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib
file packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib
```

CocoaPods will vendor this dylib via `packages/zentra_wallet_core/macos/zentra_wallet_core.podspec`.

---

## 5. Build the Flutter macOS app

```bash
flutter pub get
cd macos && pod install && cd ..
flutter build macos --release
```

**App bundle:**

```text
build/macos/Build/Products/Release/zentra_wallet.app
```

**Zip for sharing:**

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/macos/Build/Products/Release/zentra_wallet.app \
  zentra-wallet-macos.zip
```

---

## 6. Run

```bash
flutter run -d macos
```

Or open the `.app` from Finder (you may need to allow unsigned apps in **Privacy & Security** if not notarized).

---

## 7. Verify

| Check | Expected |
|-------|----------|
| Dylib exists | `macos/lib/libzentra_wallet_ffi.dylib` |
| App launches | No “Wallet engine unavailable” |
| Wallet works | Create/restore wallet, sync |

```bash
./wallet.sh status
```

---

## 8. Build iOS on the same Mac

After macOS dylib, you can build the iOS engine on the **same machine**:

```bash
./wallet.sh build-ios
```

See [build-ios.md](build-ios.md) (longer; separate XCFramework).

Or both:

```bash
./wallet.sh build-macos
./wallet.sh build-ios
```

---

## 9. Troubleshooting

| Problem | Fix |
|---------|-----|
| Zentra not found | `ZENTRA_ROOT` or `third_party/zentra` |
| Depends build fails | Free disk; retry; check `brew` deps |
| `pod install` fails | `cd macos && pod repo update && pod install` |
| Dylib missing at runtime | Re-run `build-macos` before `flutter build macos` |
| Gatekeeper blocks app | Sign/notarize for distribution, or allow in System Settings |

---

## See also

- [build-ios.md](build-ios.md)
- [build-linux.md](build-linux.md) — cross-build Android/Windows from Linux
- [building.md](building.md)
