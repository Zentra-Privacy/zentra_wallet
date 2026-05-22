# Self-custody model

This page answers: *“Is Zentra Wallet like Cake Wallet? Who holds my keys? What RPC does it use?”*

---

## Short answer

**Yes — for keys and signing, it is the same class of wallet as Cake Wallet or the Monero GUI.**

- Your **private keys** and **seed** live in **wallet files on your device**, protected by your wallet password.
- **Signing** happens inside **wallet2**, bundled in the app as `libzentra_wallet_ffi.so`.
- The app does **not** use **wallet-RPC** or third-party **hosted wallet APIs**.

**But** — like Cake Wallet — you still need a **daemon** (`zentrad`) on the network for blockchain data. That is **not** the same as giving someone your keys.

---

## What runs where

| Task | Where it runs | Who you trust |
|------|---------------|---------------|
| Generate seed / keys | Your device (wallet2) | Only yourself |
| Encrypt wallet file | Your device (wallet2) | Only yourself |
| Sign transaction | Your device (wallet2) | Only yourself |
| Store wallet password for reopen | OS secure storage | Your device OS |
| Download blocks / scan chain | wallet2 → **your chosen daemon** | Daemon operator (see below) |
| Broadcast signed tx | wallet2 → daemon | Daemon operator |

The daemon **never** receives your seed or private spend key in a wallet-RPC-style API. It sees blockchain data and relayed transactions — the standard Monero-family threat model.

---

## Wallet-RPC vs daemon-RPC

People often confuse two different “RPC” layers:

### Wallet-RPC (`zentra-wallet-rpc`) — **NOT used**

- A separate program that holds an open wallet and exposes JSON-RPC (often port 8082).
- Used for exchanges, payment gateways, or remote control.
- **Zentra Wallet never talks to this.**

### Daemon-RPC (`zentrad`) — **used**

- A full or pruned node exposing blockchain RPC (port **19081** on mainnet).
- wallet2 inside the app connects here to sync and send.
- **This is the only remote network service the app needs.**

So when we say *“no wallet RPC”*, we mean **no wallet server**. Daemon RPC for chain sync is **required** unless you run the daemon on the same machine (localhost).

---

## Trusted vs untrusted daemon

In `EmbeddedWalletService`, when you connect to:

- **`127.0.0.1` / `localhost`** → daemon is marked **trusted**
- **Any public IP** (e.g. mainnet seed nodes) → **untrusted**

This matches Monero wallet2 behavior: an untrusted remote node could theoretically lie about chain state (privacy and security nuance). For best practice:

- Run your own `zentrad` on a VPS or home server and point the app to it, **or**
- Accept the tradeoff of public seeds for convenience (similar to using remote nodes in Monero GUI).

---

## Comparison to Cake Wallet

| Aspect | Cake Wallet (Monero) | Zentra Wallet |
|--------|----------------------|---------------|
| Embedded wallet2 | Yes | Yes |
| Keys on device | Yes | Yes |
| External wallet-RPC | No | No |
| Remote daemon for sync | Yes | Yes (`zentrad`) |
| Full node inside app | No | No |
| Multi-coin | Several assets | **Zentra only** |

Zentra Wallet is **not** “more centralized” than Cake for Monero — it follows the same embedded-wallet pattern.

---

## What “fully self-dependent” does and does not mean

### Does mean

- You can use the wallet **without** running `zentra-wallet-rpc`
- You can use it **without** a company holding your keys
- Send/receive/backup work with only: **app + daemon**

### Does not mean

- The app ships a **full blockchain** (no standalone offline chain sync forever)
- Works **without any network** after first setup (you need daemon reachability to sync and send)
- Supports **every OS** out of the box without building the native `.so`

---

## Third-party services

The Flutter app **does not** include:

- HTTP clients for wallet backends
- MyMonero-style light wallet servers
- Block explorer APIs for signing (history comes from wallet2 after scan)

**Swap** is disabled in the UI — no DEX or swap partner integration.

---

## Your responsibilities as a user

1. **Back up your seed phrase** offline — anyone with the seed owns the funds.
2. **Use a strong wallet password** — protects wallet files on disk.
3. **Choose daemon wisely** — localhost or your VPS is stronger than random public nodes for privacy purists.
4. **Match network** — a mainnet wallet file must not be opened on testnet (the app blocks mismatches).

---

## See also

- [Security](security.md)
- [Networks and nodes](networks-and-nodes.md)
- [FAQ](faq.md)
