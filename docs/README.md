# Zentra Wallet — Documentation

Welcome to the Zentra Wallet docs. These guides explain what the app is, how it works, how to build and run it, and how to use it safely.

**Zentra Wallet** is a self-custody mobile and desktop wallet for [Zentra](https://github.com/Foisalislambd/zentra). It works like **Cake Wallet** or the **Monero GUI**: your keys and signing happen on your device; only the blockchain daemon (`zentrad`) is remote.

---

## Quick links

| Guide | Who it's for |
|-------|----------------|
| [Overview](overview.md) | Everyone — what this wallet is and is not |
| [Architecture](architecture.md) | Developers — layers, data flow, components |
| [Self-custody model](self-custody-model.md) | Privacy-minded users — keys, RPC, Cake Wallet comparison |
| [Getting started](getting-started.md) | New users and developers — first run |
| [Building from source](building.md) | Developers — native lib, Zentra dependency, platforms |
| [Networks and nodes](networks-and-nodes.md) | Users and ops — mainnet, testnet, `zentrad`, seed nodes |
| [User guide](user-guide.md) | End users — create wallet, send, receive, settings |
| [Security](security.md) | Everyone — passwords, seeds, trusted daemon |
| [Project structure](project-structure.md) | Contributors — folders and responsibilities |
| [Native FFI reference](native-ffi.md) | Native developers — C API and Dart bindings |
| [Troubleshooting](troubleshooting.md) | When something breaks |
| [FAQ](faq.md) | Short answers to common questions |

---

## One-minute summary

```
You  →  Flutter app  →  wallet2 (inside app)  →  zentrad (remote daemon)
```

- **On your device:** wallet keys, seed phrase, password, signing, wallet files.
- **On the network:** blockchain sync and transaction broadcast via `zentrad`.
- **Not used:** `zentra-wallet-rpc`, hosted wallet APIs, or Flutter HTTP calls to a wallet server.

For build and run from the repo root:

```bash
./wallet.sh          # interactive menu
./wallet.sh full     # build native lib + run Linux app
```

See [Getting started](getting-started.md) and [Building from source](building.md) for details.
