# Building from source (overview)

Manual build guides for **every platform** — no GitHub Actions required. Each OS has its own step-by-step doc from prerequisites through a runnable app.

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

1. Build **DLL** on Linux (or download from CI) — [build-windows.md](build-windows.md)
2. On Windows: `flutter build windows --release`

### You are on macOS

```bash
./wallet.sh build-macos        # macOS desktop
./wallet.sh build-ios          # iPhone/iPad (long)
flutter build macos --release
flutter build ios --release    # needs signing for device
```

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

## Prefer pre-built binaries?

Use CI artifacts or releases instead of compiling:

- [download-builds.md](download-builds.md)
- [ci-pipeline.md](ci-pipeline.md) — how automated builds work

---

## See also

- [Getting started](getting-started.md)
- [Native FFI reference](native-ffi.md)
- [Troubleshooting](troubleshooting.md)
- [Project structure](project-structure.md)
