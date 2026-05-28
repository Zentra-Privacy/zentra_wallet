# Build guide — Linux

End-to-end steps to build **Zentra Wallet** on **Linux x64** from source on your Linux machine.

**Output:** `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so` + runnable Linux desktop app.

**Pinned Zentra (recommended):** tag **[v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)**

---

## 1. What you need

| Item | Details |
|------|---------|
| **OS** | Ubuntu 22.04 / 24.04 or similar Debian-based (best tested) |
| **CPU / RAM** | 4+ cores, 8 GB+ RAM for Zentra compile |
| **Disk** | ~15–25 GB (Zentra build + depends) |
| **Time** | First native build: **30–90 min**; Flutter app: **5–15 min** |
| **Flutter** | Stable channel, Linux desktop enabled |
| **Zentra** | Full source tree with submodules |

---

## 2. Install system packages

```bash
sudo apt update
sudo ./scripts/ci-install-linux-deps.sh all
```

This installs:

- **Flutter Linux desktop:** GTK, clang, cmake, ninja, libsecret, …
- **Native / Zentra:** Boost, OpenSSL, Protobuf, libsodium, libusb, libtinfo5, …

Install Flutter separately: [https://docs.flutter.dev/get-started/install/linux](https://docs.flutter.dev/get-started/install/linux)

```bash
flutter doctor
flutter config --enable-linux-desktop
```

---

## 3. Clone repositories

```bash
# Wallet
git clone https://github.com/Zentra-Privacy/zentra_wallet.git
cd zentra_wallet

# Zentra core (pick one layout)
git clone -b v0.1.0 --recurse-submodules \
  https://github.com/Zentra-Privacy/zentra.git third_party/zentra
```

**Alternative paths** (auto-detected by `./wallet.sh`):

- `../zentra` (sibling folder)
- `export ZENTRA_ROOT=/absolute/path/to/zentra`

Verify:

```bash
test -f third_party/zentra/src/wallet/api/wallet2_api.h && echo OK
```

---

## 4. Build the native wallet engine

From the wallet repo root:

```bash
./wallet.sh status
./wallet.sh build
```

Or with explicit Zentra path:

```bash
export ZENTRA_ROOT="$PWD/third_party/zentra"
./wallet.sh build
```

**What happens:**

1. Configures/builds Zentra `wallet_api` → `libwallet_api.a`
2. CMake build `native/zentra_wallet_ffi` → shared library
3. Copies to `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`

**Shortcut:** the repo may already contain a committed `.so` for quick UI work. Run `./wallet.sh status` — if the `.so` exists, you can skip to step 5 (rebuild before releases).

---

## 5. Build the Flutter app

```bash
flutter pub get
flutter build linux --release
```

**Debug (faster iteration):**

```bash
flutter build linux --debug
```

**Run without installing:**

```bash
./wallet.sh run
# or
flutter run -d linux
```

**Release bundle location:**

```text
build/linux/x64/release/bundle/
```

Archive for distribution:

```bash
cd build/linux/x64/release/bundle
tar -czf ~/zentra-wallet-linux-x64.tar.gz .
```

---

## 6. Verify the build

| Check | Command |
|-------|---------|
| Native lib exists | `ls -lh packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so` |
| App binary | `ls build/linux/x64/release/bundle/zentra_wallet` |
| Wallet engine loads | Run app → create/open wallet (no “Wallet engine unavailable”) |

```bash
./wallet.sh status
```

---

## 7. Manual CMake (optional)

If `./wallet.sh build` fails and you need to debug:

```bash
export ZENTRA_ROOT="$PWD/third_party/zentra"
export ZENTRA_BUILD_DIR="$ZENTRA_ROOT/build/release"

# Build wallet_api in Zentra first
cmake -S "$ZENTRA_ROOT" -B "$ZENTRA_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ZENTRA_BUILD_DIR" --target wallet_api -j"$(nproc)"

# Build FFI
cmake -S native/zentra_wallet_ffi -B build/native_ffi \
  -DCMAKE_BUILD_TYPE=Release \
  -DZENTRA_ROOT="$ZENTRA_ROOT" \
  -DZENTRA_BUILD_DIR="$ZENTRA_BUILD_DIR"
cmake --build build/native_ffi -j"$(nproc)"
cp build/native_ffi/libzentra_wallet_ffi.so packages/zentra_wallet_core/linux/
```

---

## 8. Troubleshooting

| Problem | Fix |
|---------|-----|
| Zentra not found | Set `ZENTRA_ROOT` or clone into `third_party/zentra` |
| Missing Boost / OpenSSL | `sudo ./scripts/ci-install-linux-deps.sh native` |
| `libwallet_api.a not found` | Wait for Zentra cmake; run `cmake --build … --target wallet_api` |
| “Wallet engine unavailable” | Re-run `./wallet.sh build`; check `.so` path and `ldd` on the `.so` |
| Flutter: Linux desktop disabled | `flutter config --enable-linux-desktop` |

More: [troubleshooting.md](troubleshooting.md)

---

## 9. Build other platforms from Linux

From the same machine you can cross-build **Android** and **Windows** native libs:

| Platform | Command |
|----------|---------|
| Android | `./wallet.sh build-android` → [build-android.md](build-android.md) |
| Windows DLL | `./wallet.sh build-windows` → [build-windows.md](build-windows.md) |

**macOS / iOS** require a **Mac** → [build-macos.md](build-macos.md), [build-ios.md](build-ios.md)

---

## See also

- [Building overview](building.md)
- [Native FFI](native-ffi.md)
- [Getting started](getting-started.md)
