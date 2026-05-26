# Native FFI reference

C API exposed by `libzentra_wallet_ffi.so` and used from Dart via `ZentraNativeWallet`.

Header: `native/zentra_wallet_ffi/include/zentra_wallet_ffi.h`

---

## Lifecycle

| C function | Dart method | Description |
|------------|-------------|-------------|
| `zentra_wm_init(wallet_dir)` | `init()` | Set global wallet directory |
| `zentra_wm_shutdown()` | `shutdown()` | Global cleanup |
| `zentra_wm_set_daemon(address, trusted)` | `setDaemon()` | Point wallet2 at `host:port` |

---

## Wallet handles

Opaque `ZentraWalletHandle` (`Pointer<Void>` in Dart).

| C function | Description |
|------------|-------------|
| `zentra_wm_create_wallet(path, password, nettype, restore_height)` | New wallet |
| `zentra_wm_open_wallet(path, password, nettype)` | Open existing file |
| `zentra_wm_restore_wallet(path, password, mnemonic, nettype, restore_height)` | Restore from seed |
| `zentra_wm_close_wallet(wallet)` | Close handle |

**`nettype`:** `0` = mainnet, `1` = testnet, `2` = stagenet

**`restore_height`:** `0` = from genesis; `>0` = start scan at block

---

## Sync and balance

| C function | Description |
|------------|-------------|
| `zentra_wm_refresh(wallet)` | Blocking refresh |
| `zentra_wm_start_background_refresh(wallet)` | Background sync thread |
| `zentra_wm_pause_background_refresh(wallet)` | Pause background sync (before close) |
| `zentra_wm_balance(wallet)` | Atomic units |
| `zentra_wm_unlocked_balance(wallet)` | Spendable atomic |
| `zentra_wm_wallet_height(wallet)` | Wallet scan height |
| `zentra_wm_daemon_height(wallet)` | Daemon top height |

---

## Addresses and seed

| C function | Returns | Notes |
|------------|---------|-------|
| `zentra_wm_address(wallet)` | Primary address string | Free with `zentra_wm_free_string` |
| `zentra_wm_seed(wallet)` | Mnemonic | Sensitive — only for backup UI |
| `zentra_wm_address_valid(address, nettype)` | `int` boolean | Prefix / format check |

---

## Transfers

| C function | Description |
|------------|-------------|
| `zentra_wm_transfers_json(wallet)` | JSON array of history rows |

Dart parses JSON into `WalletTransfer` (`txid`, `amount`, `incoming`, `timestamp`, `height`, `confirmations`, `pending`, `failed`).

---

## Send and fees

| C function | Description |
|------------|-------------|
| `zentra_wm_estimate_fee(wallet, address, amount_atomic, priority)` | Fee in atomic units |
| `zentra_wm_send(wallet, address, amount_atomic, priority)` | Sign + commit; returns txid hex |

**`priority`:** `0` = default, `1` = low, `2` = medium, `3` = high (Monero pending tx priority)

Amounts are **atomic** (smallest units). Display conversion uses `ZentraCore.atomicToDisplay` / `displayToAtomic`.

---

## Persistence and restore height

| C function | Description |
|------------|-------------|
| `zentra_wm_store(wallet)` | Save wallet state to disk |
| `zentra_wm_get_restore_height(wallet)` | Current refresh-from height |
| `zentra_wm_set_restore_height(wallet, height)` | Update scan start + persist |

---

## Errors

| C function | Description |
|------------|-------------|
| `zentra_wm_last_error()` | Last error message (heap string) |
| `zentra_wm_free_string(ptr)` | Free strings returned by API |

Dart throws `WalletException` or `NativeWalletUnavailable` with these messages.

---

## Light `zentra_core` API (separate library)

Built as `zentra_wallet_core` plugin — not the full wallet:

- `zentra_daemon_rpc_port(network)`
- `zentra_address_prefix_char(network)`
- `zentra_atomic_to_display` / `zentra_display_to_atomic`
- Basic address validation helpers

---

## Loading the library (Linux)

Search order in `zentra_wallet_ffi_bindings.dart`:

1. `ZENTRA_WALLET_FFI_PATH` environment variable
2. Next to executable: `lib/libzentra_wallet_ffi.so`
3. Plugin path: `../packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`
4. Bare name `libzentra_wallet_ffi.so`

Android: `libzentra_wallet_ffi.so` in APK jniLibs.

## Loading the library (macOS)

Search order in `zentra_wallet_ffi_bindings.dart`:

1. `ZENTRA_WALLET_FFI_PATH` environment variable
2. `Runner.app/Contents/Frameworks/libzentra_wallet_ffi.dylib` (CocoaPods vendored)
3. Bare name `libzentra_wallet_ffi.dylib`
4. Dev/repo path: `packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib`

Build the dylib first: `./wallet.sh build-macos`, then `cd macos && pod install`.

Ring DB (`.shared-ringdb`) is stored under the app wallet directory on macOS (see `zentra_wallet_ffi.cpp`, `TARGET_OS_OSX` HOME redirect).

---

## Adding a new FFI function

1. Implement in `zentra_wallet_ffi.cpp` using `Monero::Wallet`
2. Declare in `zentra_wallet_ffi.h`
3. Add typedef + lookup in `zentra_wallet_ffi_bindings.dart`
4. Wrap in `EmbeddedWalletService` / `WalletProvider`
5. Rebuild: `./wallet.sh build`

---

## See also

- [Architecture](architecture.md)
- [Building from source](building.md)
