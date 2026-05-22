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
