# Zentra Wallet

Self-custody mobile/desktop wallet for [Zentra](https://github.com/Foisalislambd/zentra) — same model as **Cake Wallet** / Monero GUI: **wallet2 runs inside the app**, only the public **daemon** (`zentrad`) is remote.

## What you do NOT need

- **`zentra-wallet-rpc`** — not used, not required, no port `8082`
- A separate wallet-RPC process on VPS or localhost
- Flutter `http` JSON-RPC to a wallet server

## Architecture

```
┌─────────────────────────────────────┐
│  Flutter UI (lib/)                  │
└──────────────┬──────────────────────┘
               │ Dart FFI
┌──────────────▼──────────────────────┐
│  libzentra_wallet_ffi.so            │
│  Monero::Wallet / wallet2           │
│  keys · sign · history · store      │
└──────────────┬──────────────────────┘
               │ wallet2 daemon RPC
┌──────────────▼──────────────────────┐
│  Remote zentrad (VPS :19081)        │
│  blockchain sync only              │
└─────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| `packages/zentra_wallet_core` | Amounts, address checks, daemon ports |
| `native/zentra_wallet_ffi` | Full `wallet2` via Zentra `wallet_api` |
| Mainnet seeds | `185.182.185.127:19081`, `213.136.78.112:19081` |

Wallet files: app data dir `…/zentra_wallets/`.

## Build & run

### Easy menu (recommended)

```bash
./wallet.sh
```

Interactive menu: build native library, run Linux app, status, clean test data.

Non-interactive shortcuts:

```bash
./wallet.sh status
./wallet.sh build
./wallet.sh run
./wallet.sh full          # build + run
```

### All commands (`./wallet.sh help`)

| Command | Purpose |
|---------|---------|
| `build` | Native `libzentra_wallet_ffi.so` on this machine |
| `run` | Flutter Linux app |
| `clean-data` | Reset local test wallet files |
| `status` | Zentra path, native lib, Flutter |

Output: `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`  
Implementation: `scripts/wallet.sh` + `scripts/lib/`

### Ubuntu 22 VM (recommended for release-like builds)

Build and run on the VM so the `.so` links against the same glibc/Boost as production:

```bash
# On Ubuntu 22 VM: install build deps (cmake, boost, protobuf, …) + Flutter
./wallet.sh build
./wallet.sh run
```

## Networks

| Network | Prefix | Daemon RPC |
|---------|--------|------------|
| Mainnet | Z | 19081 |
| Testnet | T | 29081 (local `zentrad`) |
| Stagenet | S | 39081 |

## Project layout

- `lib/` — Flutter app (no wallet-RPC client)
- `native/zentra_wallet_ffi/` — C API over `wallet2`
- `wallet.sh` — build and run (single entry point)
