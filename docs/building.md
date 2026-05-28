# Building from source (overview)

Build guides for **every platform** on your own hardware. Each OS has a step-by-step doc from prerequisites through a runnable app.

**Recommended Zentra version:** [v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)

---

## Platform guides

| OS | Guide | Native command | Flutter build |
|----|--------|----------------|---------------|
| **Linux** | [build-linux.md](build-linux.md) | `./wallet.sh build` | `flutter build linux --release` |
| **Windows** | [build-windows.md](build-windows.md) | `./wallet.sh build-windows` (on Linux) | `flutter build windows --release` (on Windows) |
| **Android** | [build-android.md](build-android.md) | `./wallet.sh build-android` | `flutter build apk --release` |
| **macOS** | [build-macos.md](build-macos.md) | `./wallet.sh build-macos` | `flutter build macos --release` |
| **iOS** | [build-ios.md](build-ios.md) | `./wallet.sh build-ios` | `flutter build ios` (+ signing) |

---

## Quick start by host machine

### You are on Linux (Ubuntu)

```bash
git clone … zentra_wallet && cd zentra_wallet
git clone -b v0.1.0 --recurse-submodules … third_party/zentra
sudo ./scripts/ci-install-linux-deps.sh all
./wallet.sh build              # Linux app
./wallet.sh build-android      # optional: APK native libs
./wallet.sh build-windows      # optional: Windows DLL
flutter pub get && flutter build linux --release
```

Details: [build-linux.md](build-linux.md)

### You are on Windows

1. Build **DLL** on a Linux host (MinGW cross-compile) — [build-windows.md](build-windows.md)
2. On your **Windows PC**: `flutter build windows --release`

### You are on macOS

```bash
./wallet.sh build-apps         # macOS .app + iOS simulator (native + Flutter; long first time)
# or step by step:
./wallet.sh build-macos        # macOS desktop dylib
./wallet.sh build-ios          # iPhone/iPad XCFramework (long)
./wallet.sh build-app-macos    # dylib + flutter macos
./wallet.sh build-app-ios      # XCFramework + flutter ios --simulator
```

**Android APK** and **Windows .exe** are not built on macOS — use a **Linux** host (`./wallet.sh build-android`, `build-windows`).

Details: [build-macos.md](build-macos.md), [build-ios.md](build-ios.md)

---

## Pipeline overview

```text
Zentra source (wallet_api + static libs)
        ↓
native/zentra_wallet_ffi
        ↓
packages/zentra_wallet_core/<platform>/libzentra_wallet_ffi.*
        ↓
flutter build <platform>
```

Entry script: **`./wallet.sh`** (see `scripts/wallet.sh`).

```bash
./wallet.sh help
./wallet.sh status
```

| Command | Platform |
|---------|----------|
| `build` | Linux `.so` |
| `build-android` | Android `jniLibs/*.so` |
| `build-windows` | Windows `.dll` (MinGW on Linux) |
| `build-macos` | macOS `.dylib` |
| `build-ios` | iOS `.xcframework` |
| `build-apps` | Native + Flutter apps for current OS (Mac: macOS+iOS; Linux: desktop+APK) |
| `build-app-macos` / `build-app-ios` | Single platform native + app |
| `build-all-native` | Linux + Android + Windows (+ macOS/iOS on Mac) |

---

## Zentra source location

Scripts search in order:

1. `ZENTRA_ROOT` environment variable
2. `../zentra` (sibling directory)
3. `third_party/zentra` inside this repo

Must contain: `src/wallet/api/wallet2_api.h`

```bash
git clone -b v0.1.0 --recurse-submodules \
  https://github.com/Zentra-Privacy/zentra.git third_party/zentra
```

---

## See also

- [Getting started](getting-started.md)
- [Native FFI reference](native-ffi.md)
- [Troubleshooting](troubleshooting.md)
- [Project structure](project-structure.md)
