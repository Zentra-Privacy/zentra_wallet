# Building from source

How to compile the native wallet engine and run the Flutter app on your machine.

---

## Build pipeline overview

```
Zentra source (wallet_api, static libs)
        ↓
native/zentra_wallet_ffi  →  libzentra_wallet_ffi.so
        ↓
packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so
        ↓
flutter run -d linux
```

The entry script **`./wallet.sh`** (wrapper for `scripts/wallet.sh`) orchestrates this.

---

## Step 1 — Prepare Zentra

Clone and build the Zentra project so `wallet_api` exists:

```bash
cd /path/to/zentra
scripts/build.sh release   # if available
# or cmake configure + build in build/release
```

The wallet FFI build expects:

`$ZENTRA_BUILD/lib/libwallet_api.a`

**Note:** Zentra’s default `scripts/build.sh release` may **not** build `wallet_api` (it can be `EXCLUDE_FROM_ALL`). The wallet script runs:

```bash
cmake --build "$ZENTRA_BUILD" --target wallet_api
```

when the archive is missing.

---

## Step 2 — Build the FFI library

From the wallet repo:

```bash
export ZENTRA_ROOT=/path/to/zentra   # if not auto-detected
./wallet.sh build
```

What `scripts/lib/native_build.sh` does:

1. Resolves `ZENTRA_ROOT` and `ZENTRA_BUILD` (default `build/release`)
2. Configures/builds Zentra if caches or libs are missing
3. Builds target **`wallet_api`**
4. CMake configure `native/zentra_wallet_ffi` with env `ZENTRA_ROOT` and `ZENTRA_BUILD_DIR`
5. Links the shared library against Zentra static archives + Boost, OpenSSL, Protobuf, etc.
6. Copies `.so` to `packages/zentra_wallet_core/linux/`

---

## Step 3 — Run the Flutter app

```bash
./wallet.sh run
# equivalent to flutter run -d linux (via scripts/lib/flutter_run.sh)
```

List devices:

```bash
./wallet.sh devices
```

---

## Manual CMake (advanced)

If you need to debug the FFI layer alone:

```bash
export ZENTRA_ROOT=/path/to/zentra
export ZENTRA_BUILD_DIR=/path/to/zentra/build/release

cmake -S native/zentra_wallet_ffi -B build/native_ffi -DCMAKE_BUILD_TYPE=Release
cmake --build build/native_ffi --parallel "$(nproc)"

cp build/native_ffi/libzentra_wallet_ffi.so packages/zentra_wallet_core/linux/
```

Required static libs are listed in `native/zentra_wallet_ffi/CMakeLists.txt` (wallet, cryptonote_core, ringct, randomx, …).

---

## System dependencies (Linux)

Typical packages on Ubuntu/Debian (names may vary):

- `build-essential`, `cmake`
- `libboost-all-dev` (chrono, filesystem, thread, serialization, locale, regex, program_options, date_time)
- `libssl-dev`
- `libprotobuf-dev`, `protobuf-compiler`
- `libunbound-dev`, `libzmq3-dev`
- `libsodium-dev`, `libhidapi-libusb0`, `libusb-1.0-0-dev`
- Optional: `libpgm-dev`, `libnorm-dev`

Match what the [Zentra](https://github.com/Zentra-Privacy/zentra) README requires for building the full node.

---

## Android notes

- `packages/zentra_wallet_core/android/build.gradle` + `CMakeLists.txt` build the small **`zentra_core`** helper, not the full FFI.
- For a production Android APK you must extend the build to compile and package `libzentra_wallet_ffi.so` for each ABI (arm64-v8a, etc.) and cross-compile Zentra static libs — same dependency closure as Linux.
- Dart loads the library with `DynamicLibrary.open('libzentra_wallet_ffi.so')` on Android.

---

## iOS / macOS / Windows

Flutter platform folders exist. **macOS/iOS** build the light `zentra_core` plugin via CocoaPods (`packages/zentra_wallet_core/macos|ios/`). The **full wallet engine** (`libzentra_wallet_ffi`) is only bundled on **Linux** today.

---

## Flutter dependencies

```bash
flutter pub get
```

Local package:

- `packages/zentra_wallet_core` — FFI bindings + light native helpers

No `http` package — intentional.

---

## `wallet.sh` command reference

| Command | Action |
|---------|--------|
| *(no args)* | Interactive menu |
| `status` | Zentra path, `.so` presence, Flutter version |
| `build` | Build `libzentra_wallet_ffi.so` |
| `run` | Run Linux app |
| `full` | `build` then `run` |
| `devices` | `flutter devices` |
| `clean-data` | Remove local test wallet data |
| `help` | Short help text |

---

## CI / reproducibility tips

GitHub Actions workflows in `.github/workflows/`:

| Workflow | Purpose |
|----------|---------|
| `ci.yml` | Analyze, test, Linux debug build — every **PR** and push to `main` / `master` |
| `build-artifacts.yml` | Two-phase release: engine from Zentra **v0.1.0**, then Linux/Windows/Android/macOS apps |

Install the same Ubuntu packages locally: `sudo ./scripts/ci-install-linux-deps.sh all`

- Pin Zentra commit when releasing wallet builds
- Build `.so` on the same distro/glibc as end users
- Do not commit a stale `.so` built on a different machine without rebuilding
- Use `./wallet.sh status` before tagging releases

---

## See also

- [Native FFI reference](native-ffi.md)
- [Project structure](project-structure.md)
- [Troubleshooting](troubleshooting.md)
