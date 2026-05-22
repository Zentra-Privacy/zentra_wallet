# Architecture

This page describes how Zentra Wallet is put together — from the screen you tap to the blockchain node on the internet.

---

## High-level diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter UI (lib/)                                          │
│  Screens · Provider · Settings · QR · Secure storage        │
└────────────────────────────┬────────────────────────────────┘
                             │ Dart FFI (dart:ffi)
┌────────────────────────────▼────────────────────────────────┐
│  libzentra_wallet_ffi.so                                      │
│  C API → Monero::Wallet / wallet2                             │
│  create · open · restore · refresh · sign · store · history   │
└────────────────────────────┬────────────────────────────────┘
                             │ wallet2 internal daemon RPC
┌────────────────────────────▼────────────────────────────────┐
│  zentrad (remote or localhost)                                │
│  Blockchain sync · block height · relay signed transactions   │
└─────────────────────────────────────────────────────────────┘
```

**Important:** The bottom box is **`zentrad` (daemon RPC)**, not **`zentra-wallet-rpc` (wallet RPC)**. The wallet process lives inside the app.

---

## Layer responsibilities

### 1. Flutter UI (`lib/`)

- Material dark theme, navigation, forms
- **`WalletProvider`** — app state: connection, balance, transfers, network
- **`SettingsStore`** — network choice, daemon address, wallet filename; password in **Flutter Secure Storage**
- **`EmbeddedWalletService`** — thin Dart wrapper over native calls
- No `http` / `dio` package — **no HTTP wallet client**

Entry: `lib/main.dart` → `lib/app.dart` → `SplashScreen` → onboarding or `HomeScreen`.

### 2. `zentra_wallet_core` package

Two roles in one package name:

| Piece | Path | Purpose |
|-------|------|---------|
| **Light plugin** | `packages/zentra_wallet_core/src/zentra_core.cpp` | Atomic/display amounts, address prefix check, daemon port constants |
| **Full engine** | `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so` | Copied here after native build; loaded by Dart FFI |

On Linux, `ZentraNativeWallet` opens the `.so` from several candidate paths (next to the binary, plugin folder, or `ZENTRA_WALLET_FFI_PATH` env var).

### 3. Native FFI (`native/zentra_wallet_ffi/`)

- **`zentra_wallet_ffi.h`** — stable C API
- **`zentra_wallet_ffi.cpp`** — calls Zentra’s `wallet_api` / wallet2
- **CMake** — links many static libraries from a **pre-built Zentra tree** (`libwallet_api.a`, `libwallet.a`, `libcryptonote_core.a`, …)

Built output is installed to:

`packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`

### 4. Remote daemon (`zentrad`)

- Provides chain height and blocks for wallet2 to scan
- Relays transactions after local signing
- Configured as `host:port` (e.g. `185.182.185.127:19081`)

---

## Typical flows

### App startup

1. `WalletProvider.initialize()` loads network, node, wallet filename from disk
2. `SplashScreen` checks onboarding flag
3. If onboarded and native lib exists → `connect()` opens wallet file, `refresh()` syncs
4. Navigate to `HomeScreen` or `OnboardingScreen`

### Create wallet

1. User picks network and wallet filename + password (onboarding)
2. `EmbeddedWalletService.createWallet()` → FFI `zentra_wm_create_wallet`
3. Background refresh starts inside wallet2
4. Password saved to secure storage; wallet files written under `…/zentra_wallets/`

### Send ZTR

1. UI validates address (wallet2) and amount
2. `estimateFee()` → `zentra_wm_estimate_fee`
3. `send()` → `createTransaction` + `commit` in native code
4. wallet2 talks to daemon to broadcast; txid returned to Flutter

### Restore from seed

1. Dart `SeedUtils` checks word count (12/13/24/25)
2. FFI `zentra_wm_restore_wallet` with optional **restore height** (faster sync)
3. Same refresh and storage as create

---

## Data on disk

| Data | Location | Protection |
|------|----------|------------|
| Wallet files (keys, cache) | App support dir → `zentra_wallets/` | Encrypted by wallet password (wallet2) |
| Wallet password (app unlock) | Flutter Secure Storage | OS keychain / encrypted prefs |
| Network, daemon, filename | SharedPreferences | Not secret; no seed |
| Seed phrase | Only in memory when shown on backup screen | User must copy safely |

---

## What is explicitly out of scope

- **Wallet-RPC server** — no process listening on 8082 for the Flutter app
- **Cloud signing** — transactions are built and signed locally
- **In-app full node** — no embedded LMDB chain; daemon is external
- **Multi-coin** — single Zentra family only

---

## Comparison to Monero stack naming

| Monero | Zentra |
|--------|--------|
| `monerod` | `zentrad` |
| `monero-wallet-cli` / GUI wallet2 | Embedded via FFI |
| `monero-wallet-rpc` | **Not used** by this app |

---

## See also

- [Self-custody model](self-custody-model.md) — trust boundaries
- [Native FFI reference](native-ffi.md) — function list
- [Project structure](project-structure.md) — file tree
