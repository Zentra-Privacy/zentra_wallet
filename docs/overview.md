# Overview

## What is Zentra Wallet?

Zentra Wallet is an official-style **self-custody** application for the Zentra cryptocurrency. Zentra is a privacy-focused coin in the Monero family (same wallet technology: **wallet2**).

You use the app to:

- Create a new wallet or restore from a seed phrase
- Receive and send **ZTRA**
- View balance and transaction history
- Back up your seed phrase
- Choose which network (mainnet, testnet, stagenet) and which **daemon node** to sync against

The app is built with **Flutter** for the user interface and a **native wallet engine** (C++ / FFI) for all cryptographic and wallet operations.

---

## What makes it different from a “hosted wallet”?

Many wallets keep your keys on a server or talk to a **wallet-RPC** service. Zentra Wallet does **not** do that.

| Approach | Zentra Wallet |
|----------|----------------|
| Keys stored on company server | No — keys stay on your device |
| App calls `wallet-rpc` on VPS | No — wallet2 runs inside the app |
| App uses MyMonero / light-wallet API | No — no third-party wallet HTTP API |
| App syncs via remote **daemon** only | Yes — same as Monero GUI / Cake Wallet |

Your **seed** and **wallet password** never leave your phone or computer except when **you** choose to back them up or copy them.

---

## What you need to run it

1. **The app** — built or installed for Linux or Android (other platforms need extra native build work).
2. **The native wallet library** — `libzentra_wallet_ffi.so`, built from this repo plus the [Zentra](https://github.com/Foisalislambd/zentra) source tree.
3. **A reachable `zentrad` daemon** — for mainnet, the app can use built-in public seed nodes; for testnet/stagenet you typically run your own node locally.

You do **not** need:

- `zentra-wallet-rpc`
- Port `8082` or any wallet JSON-RPC server
- A separate “wallet backend” on a VPS (only the **daemon**, not wallet-RPC)

---

## Supported platforms (today)

| Platform | Wallet engine | Notes |
|----------|---------------|--------|
| **Linux** | Yes | Primary dev target; `./wallet.sh run` |
| **Android** | Yes (when `.so` is bundled) | Loads `libzentra_wallet_ffi.so` from the APK |
| iOS / macOS / Windows | Partial | Flutter UI exists; full FFI build not wired in plugin CMake by default |
| Web | No | No native wallet2 in the browser |

If the native library is missing, the app shows **“Wallet engine unavailable”** and onboarding cannot create a real wallet.

---

## Coin and networks

Zentra Wallet supports **one coin family** — Zentra (ticker **ZTRA**), on three networks:

| Network | Address starts with | Default daemon port |
|---------|---------------------|---------------------|
| Mainnet | `Z` | 19081 |
| Testnet | `T` | 29081 |
| Stagenet | `S` | 39081 |

This is **not** a multi-chain wallet (no Bitcoin, Ethereum, etc. in one app).

---

## Features in the UI

- **Dashboard** — balance, sync status, quick send/receive
- **Assets** — placeholder asset view (ZTRA-focused)
- **Transactions** — incoming/outgoing history from wallet2
- **Settings** — network, node, restore height, backup, switch wallet
- **Send / Receive** — standard flows with address validation and fee estimate
- **Swap** — shown as disabled (not implemented)

---

## Related projects

| Project | Role |
|---------|------|
| [Zentra](https://github.com/Foisalislambd/zentra) | Full node (`zentrad`), CLI wallet, consensus, `wallet_api` |
| **This repo** | Flutter UI + FFI wrapper around `wallet2` |

---

## Next steps

- New user? → [User guide](user-guide.md)
- Developer? → [Getting started](getting-started.md) → [Building from source](building.md)
- How keys and RPC work? → [Self-custody model](self-custody-model.md)
- Problems? → [Troubleshooting](troubleshooting.md)
