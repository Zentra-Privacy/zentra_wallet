# FAQ

Frequently asked questions about Zentra Wallet.

---

## Is this like Cake Wallet?

**Yes, for custody.** Keys and signing are on your device via embedded wallet2. You only connect to a remote **daemon** (`zentrad`), not a wallet-RPC server.

**No, for coins.** Cake supports multiple assets; this app supports **Zentra (ZTRA)** only.

---

## Do I need `zentra-wallet-rpc`?

**No.** The README and code explicitly exclude wallet-RPC. Port 8082 is not used by this app.

---

## Do I need my own node?

**Mainnet:** No — public seed nodes are built in.  
**Recommended for privacy:** Yes — run `zentrad` and point the app to it.  
**Testnet/stagenet:** Yes — usually local `127.0.0.1`.

---

## Where are my keys?

In encrypted **wallet files** under the app data directory (`zentra_wallets/`), plus your **seed phrase** which you should back up offline.

---

## Can the seed node steal my coins?

Not your private keys through this app’s design — wallet2 does not send the seed to the daemon. Remote nodes have other risks (privacy, censorship, dishonest tips) discussed in [Security](security.md).

---

## What word count is the seed?

**12, 13, 24, or 25** English words. **25** is common in Monero-family wallets.

---

## What is restore height?

The block height where wallet2 starts scanning the blockchain. Correct height speeds up restore; wrong height can hide balance until scan reaches your transactions.

---

## Why is Swap disabled?

Swap is not implemented in this version — no integrated exchange or swap API.

---

## Can I use this on iPhone or Windows today?

The Flutter project includes those platforms, but the **full native wallet library** is only set up for **Linux** (and Android when the `.so` is packaged). Other platforms need additional native build work.

---

## Does the web version work?

**No** — browsers cannot load the wallet2 native library in this architecture.

---

## How do amounts work?

Internally amounts are **atomic** integers. The UI shows human **ZTRA** via `ZentraCore` conversion helpers.

---

## Is the wallet password the same as the seed?

**No.**

- **Password** — encrypts wallet files on disk
- **Seed** — recovers full wallet access anywhere

If you forget the password but have the seed, restore a new wallet file from seed.

---

## How do I reset everything for testing?

```bash
./wallet.sh clean-data --yes
```

This deletes local app data — **not** for production wallets with real funds unless you have a seed backup.

---

## Where is the documentation index?

[docs/README.md](README.md)

---

## Where is the Zentra blockchain project?

https://github.com/Foisalislambd/zentra
