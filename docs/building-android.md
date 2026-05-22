# Building Android wallet (full `wallet2` FFI)

The APK needs **`libzentra_wallet_ffi.so` per CPU ABI** under:

`packages/zentra_wallet_core/android/src/main/jniLibs/<abi>/`

Without these libraries the app installs but shows **“Wallet engine unavailable”**.

---

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| **Zentra source** | `../zentra`, `third_party/zentra`, or `ZENTRA_ROOT` |
| **Linux host** | Ubuntu 22.04 recommended (same as Zentra depends) |
| **Build tools** | `sudo ./scripts/ci-install-linux-deps.sh all` (includes `libtinfo5` for Zentra’s NDK r17b) |
| **python** | `python3` on PATH (script adds a `python` shim if missing) |
| **Disk / time** | First run ~2–4 hours; depends cache ~5–10 GB per ABI |

Flutter/Android SDK are only needed to **package the APK** after native libs are built.

---

## One command (recommended ABIs)

From the wallet repo root:

```bash
./wallet.sh build-android
```

This builds **arm64-v8a**, **armeabi-v7a**, and **x86_64** (covers phones + emulators).

Single ABI (faster test):

```bash
./wallet.sh build-android arm64-v8a
```

---

## Build APK

```bash
flutter pub get
flutter build apk --release
```

Check the library is inside the APK:

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep libzentra_wallet_ffi
```

You should see entries under `lib/arm64-v8a/`, `lib/armeabi-v7a/`, etc.

---

## Commit for CI / releases

After a successful build, commit the `.so` files (large binaries):

```bash
git add packages/zentra_wallet_core/android/src/main/jniLibs/
git commit -m "Add Android libzentra_wallet_ffi for release ABIs"
```

`.gitignore` excludes these until you add them explicitly. Linux CI does **not** build Android FFI yet — commit jniLibs or run `build-android` locally before tagging.

---

## ABI coverage

| ABI | Devices |
|-----|---------|
| **arm64-v8a** | Nearly all modern phones |
| **armeabi-v7a** | Older 32-bit ARM phones |
| **x86_64** | Android emulators (64-bit) |
| **x86** | Old 32-bit emulators (optional: `./wallet.sh build-android x86`) |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Depends download fails | Retry; ensure `curl`, `sha256sum`, `unzip` installed |
| `libwallet_api.a not found` | Let Zentra cmake finish; check `zentra/build/android-<abi>/release/lib/` |
| Link errors on FFI step | Rebuild depends for that HOST; do not mix Linux and Android build dirs |
| APK still shows engine unavailable | Rebuild APK after jniLibs update; verify `unzip -l` lists `libzentra_wallet_ffi.so` |

---

## See also

- [Building from source](building.md)
- [Download builds](download-builds.md)
