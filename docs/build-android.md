# Build guide — Android (manual, no CI)

Build a **release APK** with the full **wallet2** engine on every supported CPU ABI.

Without `libzentra_wallet_ffi.so` in `jniLibs/`, the APK installs but shows **“Wallet engine unavailable”**.

**Output:**

- `packages/zentra_wallet_core/android/src/main/jniLibs/<abi>/libzentra_wallet_ffi.so`
- `build/app/outputs/flutter-apk/app-release.apk`

**Zentra pin:** [v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)

---

## 1. What you need

| Item | Details |
|------|---------|
| **Build host** | **Linux** (Ubuntu 22.04 recommended) |
| **Disk** | ~5–10 GB per ABI for Zentra depends cache |
| **Time** | First ABI: **30–90 min**; extra ABIs add more time |
| **Flutter + Android SDK** | For APK packaging (after native libs) |
| **Zentra source** | With submodules |

Windows/macOS hosts are **not** supported for `build-android` (Zentra Android depends expect Linux).

---

## 2. Install dependencies

```bash
sudo apt update
sudo ./scripts/ci-install-linux-deps.sh all
```

**Required for Zentra Android depends:**

- `libtinfo5` (NDK r17b used by depends)
- `python3` on PATH (`wallet.sh` adds a `python` shim if needed)

Install Flutter + Android SDK: [Flutter Android setup](https://docs.flutter.dev/get-started/install/linux/android)

```bash
flutter doctor
flutter doctor --android-licenses   # accept licenses
```

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

## 4. Build native `.so` per ABI

### Recommended (phones + emulators)

```bash
./wallet.sh build-android
```

Builds:

| ABI | Devices |
|-----|---------|
| **arm64-v8a** | Modern phones (required) |
| **armeabi-v7a** | Older 32-bit ARM phones |
| **x86_64** | 64-bit emulators |

### Single ABI (faster test)

```bash
./wallet.sh build-android arm64-v8a
```

Other ABIs: `armeabi-v7a`, `x86_64`, `x86`

### Check output

```bash
find packages/zentra_wallet_core/android/src/main/jniLibs -name '*.so' -exec ls -lh {} \;
```

Expected paths:

```text
packages/zentra_wallet_core/android/src/main/jniLibs/arm64-v8a/libzentra_wallet_ffi.so
packages/zentra_wallet_core/android/src/main/jniLibs/armeabi-v7a/libzentra_wallet_ffi.so
packages/zentra_wallet_core/android/src/main/jniLibs/x86_64/libzentra_wallet_ffi.so
```

---

## 5. Build the APK

```bash
flutter pub get
flutter build apk --release
```

**Output:**

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Install on device

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Verify native lib inside APK

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep libzentra_wallet_ffi
```

You should see `lib/arm64-v8a/libzentra_wallet_ffi.so` (and other ABIs you built).

---

## 6. Run in emulator / device (debug)

```bash
flutter devices
flutter run -d <device-id>
```

---

## 7. Optional — commit jniLibs for faster rebuilds

Large binaries are gitignored until you add them:

```bash
git add packages/zentra_wallet_core/android/src/main/jniLibs/
git commit -m "Add Android libzentra_wallet_ffi for release ABIs"
```

---

## 8. What the script does (reference)

For each ABI, `scripts/lib/native_build_android.sh`:

1. Maps ABI → Zentra depends `HOST` (e.g. `aarch64-linux-android`)
2. `make HOST=…` in `zentra/contrib/depends` (first time: long)
3. CMake cross-build Zentra `wallet_api`
4. CMake cross-build `native/zentra_wallet_ffi` → `.so`
5. Installs into `jniLibs/<abi>/`

Environment:

```bash
export ZENTRA_ROOT="$PWD/third_party/zentra"
export JOBS=4
export SKIP_DEPENDS=1    # only if toolchain already built
./wallet.sh build-android
```

---

## 9. Troubleshooting

| Problem | Fix |
|---------|-----|
| Depends download fails | Check network; `curl`, `unzip`, `sha256sum` installed |
| `libtinfo.so.5` missing | `sudo apt install libtinfo5` |
| `libwallet_api.a not found` | Let Zentra finish; inspect `zentra/build/android-*/release/lib/` |
| APK: engine unavailable | Rebuild jniLibs **then** `flutter clean && flutter build apk` |
| Emulator ABI mismatch | Build `x86_64` or use an arm64 emulator image |

---

## See also

- [build-linux.md](build-linux.md)
- [building.md](building.md)
- [download-builds.md](download-builds.md)
