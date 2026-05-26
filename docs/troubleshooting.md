# Troubleshooting

Common problems and how to fix them.

---

## “Wallet engine unavailable”

**Symptom:** Onboarding or splash shows native wallet missing.

**Causes:**

- `libzentra_wallet_ffi.so` not built or not beside the app
- Running on unsupported OS (e.g. Windows without building FFI)
- Wrong architecture `.so`

**Fix:**

```bash
./wallet.sh status
./wallet.sh build
./wallet.sh run
```

Confirm file exists:

`packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`

For manual runs set:

```bash
export ZENTRA_WALLET_FFI_PATH=/full/path/to/libzentra_wallet_ffi.so
```

---

## macOS — Keychain / `PlatformException` code -34018

**Symptoms:**

- `A required entitlement isn't present` / `Unexpected security result code, Code: -34018`
- Wallet auto-open fails; logs may show `invalid password` (password was never read from Keychain)

**macOS dev:** wallet password is stored in **SharedPreferences** (not Keychain) because ad-hoc signing cannot use Keychain reliably (`Keychain Not Found`, `-34018`, `-60008`). Wallet `.keys` files remain encrypted with your password.

**Other platforms:** `MacOsOptions(useDataProtectionKeyChain: false)` avoids `-34018` when Keychain is used.

**Debug (`flutter run -d macos`):** `DebugProfile.entitlements` disables App Sandbox so Keychain works with ad-hoc signing (no Apple team required).

**Release (`flutter build macos --release`):** needs a development team and `keychain-access-groups` in `Release.entitlements`:

```bash
cp macos/Runner/Configs/Signing.xcconfig.example macos/Runner/Configs/Signing.xcconfig
# Edit Signing.xcconfig — set DEVELOPMENT_TEAM to your 10-character Team ID from Xcode
flutter build macos --release
```

Do **not** run `pod install` before `flutter pub get` (Flutter must generate `macos/Flutter/ephemeral/` first).

---

## macOS — “entitlements that require signing with a development certificate”

**Symptoms:** Xcode error when building after adding Keychain entitlements.

**Fix:** For day-to-day dev use `flutter run -d macos` (Debug entitlements, no sandbox). For release, copy `Signing.xcconfig.example` → `Signing.xcconfig`, set `DEVELOPMENT_TEAM`, and sign in Xcode (Signing & Capabilities → Team).

---

## macOS — wallet engine, ringdb, or “invalid password”

**Symptoms:**

- “Wallet engine unavailable” after `flutter run -d macos`
- Log: `Failed to initialize ringdb` / `Operation not permitted`
- `invalid password` right after open (often ringdb failed first — not a wrong password)

**Cause:** macOS App Sandbox blocks LMDB’s default locking (System V semaphores). The wallet build applies `MDB_NOLOCK` in Zentra `ringdb.cpp` (safe because the FFI uses one mutex for all wallet calls).

**Fix:**

```bash
./wallet.sh build-macos          # patches Zentra ringdb + rebuilds libzentra_wallet_ffi.dylib
cd macos && pod install && cd ..
flutter run -d macos
```

---

## iOS — wallet engine, ringdb, or “invalid password”

**Symptoms:** Same as macOS (`Failed to initialize ringdb`, “Wallet engine unavailable”, false “invalid password” after open).

**Cause:** iOS app sandbox blocks LMDB default locking; `./wallet.sh build-ios` applies the same `ringdb` patch as macOS (`scripts/patches/zentra/ringdb-macos-sandbox.patch`).

**Fix:**

```bash
./wallet.sh build-ios
cd ios && pod install && cd ..
flutter run -d <your-ios-device-or-simulator>
```

**Check dylib arch matches the app** (Apple Silicon vs Intel):

```bash
file packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib
# expect: arm64 on M-series Mac
```

**Portable dylib for distribution** (no Homebrew on target Mac):

```bash
ZENTRA_MACOS_USE_DEPENDS=1 ./wallet.sh build-macos
```

**Manual load override:**

```bash
export ZENTRA_WALLET_FFI_PATH=/full/path/to/libzentra_wallet_ffi.dylib
```

**Dart VM / hot reload warning in debug:** ensure `macos/Runner/DebugProfile.entitlements` includes `com.apple.security.network.server` (Flutter DevTools).

---

## “Zentra source not found” on build

**Symptom:** `./wallet.sh build` fails immediately.

**Fix:**

- Clone [Zentra](https://github.com/Zentra-Privacy/zentra) to `../zentra` or `third_party/zentra`
- Or `export ZENTRA_ROOT=/path/to/zentra`
- Verify `src/wallet/api/wallet2_api.h` exists

---

## `libwallet_api.a not found`

**Symptom:** Native build stops after Zentra compile.

**Fix:**

```bash
cmake --build /path/to/zentra/build/release --target wallet_api
```

Then rerun `./wallet.sh build`.

---

## Sync timed out (splash)

**Symptom:** “Sync timed out. Check node in Settings.”

**Causes:**

- Daemon down or wrong port
- Firewall blocking RPC
- Very slow first scan on mainnet from height 0

**Fix:**

1. Settings → **Network node** — verify `host:port`
2. Mainnet: try other seed or your own `zentrad`
3. Testnet: start local `zentrad` on correct port
4. For restore, set a sensible **restore height** to reduce scan time

---

## Wallet behind daemon / cannot send

**Symptom:** Send disabled; “Wait for sync to finish”.

**Fix:**

- Pull to refresh on dashboard
- Wait until wallet height ≈ daemon height
- Check daemon is synced (`zentrad` logs)

---

## Wrong password / cannot open wallet

**Symptom:** Connection error after splash.

**Fix:**

- Settings → switch wallet → open with correct password
- If password forgotten but you have **seed** → restore new filename from seed

---

## Network mismatch error

**Symptom:** “Wallet X is for Mainnet. Switch network in Settings…”

**Fix:**

- Settings → set network to match how wallet was created
- Or create a new wallet on the intended network

---

## Invalid address on send

**Symptom:** “Invalid address for Mainnet” (etc.).

**Fix:**

- Address must match network prefix (**Z** / **T** / **S**)
- No extra spaces; full address string
- Recipient must use same network

---

## CMake / linker errors building FFI

**Symptom:** Missing Boost, OpenSSL, or Zentra static `.a` files.

**Fix:**

- Install Zentra’s documented dependencies
- Full Zentra release build in `build/release`
- Do not mix CMake build dirs from different Zentra paths (script deletes stale cache)

---

## Flutter not found

**Symptom:** `./wallet.sh status` warns Flutter missing.

**Fix:**

- Install Flutter SDK and add to `PATH`
- Run `flutter doctor`

---

## Clean slate for testing

```bash
./wallet.sh clean-data --yes
```

Removes `~/.local/share/com.example.zentra_wallet/` (Linux). **Deletes local wallets** — only for dev/test.

---

## GitHub Actions / CI

| Symptom | Fix |
|---------|-----|
| **CI** fails: `libzentra_wallet_ffi.so missing` | Run `./wallet.sh build`, commit `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`, push |
| **Release pipeline** failed on Linux only | Same `.so` fix; PR CI only needs the committed Linux library |
| No **draft release** after push to `main` | Open the workflow run — if any platform job is red, draft is skipped; fix or download partial **Artifacts** |
| Tag `v1.0.0` but no **Release** assets | Tag build failed — fix CI, then re-run **Release pipeline** on the tag or push the tag again |
| PR has no Windows/APK/macOS artifacts | Expected — **Release pipeline** does not run on pull requests; merge to `main` or use **Run workflow** |

---

## Still stuck?

1. `./wallet.sh status` — capture output
2. Run app from terminal to see `debugPrint` errors
3. Check Zentra daemon logs separately
4. Open an issue with OS, Flutter version, network, and redacted logs (no seed/password)

---

## See also

- [Building from source](building.md)
- [Networks and nodes](networks-and-nodes.md)
- [FAQ](faq.md)
