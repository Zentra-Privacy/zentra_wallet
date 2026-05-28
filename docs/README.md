# Zentra Wallet — Documentation

Welcome to the Zentra Wallet docs. These guides explain what the app is, how it works, how to build and run it, and how to use it safely.

**Zentra Wallet** is a self-custody mobile and desktop wallet for [Zentra](https://github.com/Zentra-Privacy/zentra). It works like **Cake Wallet** or the **Monero GUI**: your keys and signing happen on your device; only the blockchain daemon (`zentrad`) is remote.

---

## Quick links

| Guide | Who it's for |
|-------|----------------|
| [Overview](overview.md) | Everyone — what this wallet is and is not |
| [Architecture](architecture.md) | Developers — layers, data flow, components |
| [Self-custody model](self-custody-model.md) | Privacy-minded users — keys, RPC, Cake Wallet comparison |
| [Getting started](getting-started.md) | New users and developers — first run on Linux |

### Build from source (per OS)

| OS | Full guide |
|----|------------|
| [Linux](build-linux.md) | Native `.so` + desktop app |
| [Windows](build-windows.md) | MinGW DLL + Windows app |
| [Android](build-android.md) | jniLibs + APK |
| [macOS](build-macos.md) | dylib + `.app` |
| [iOS](build-ios.md) | XCFramework + iPhone/iPad app |
| [Building overview](building.md) | Index + `wallet.sh` commands |

| Other | |
|-------|---|
| [Networks and nodes](networks-and-nodes.md) | Mainnet, testnet, `zentrad`, seed nodes |
| [User guide](user-guide.md) | Create wallet, send, receive, settings |
| [Security](security.md) | Passwords, seeds, trusted daemon |
| [Project structure](project-structure.md) | Folders and responsibilities |
| [Native FFI reference](native-ffi.md) | C API and Dart bindings |
| [Troubleshooting](troubleshooting.md) | When something breaks |
| [FAQ](faq.md) | Short answers |

---

## One-minute summary

```text
You  →  Flutter app  →  wallet2 (inside app)  →  zentrad (remote daemon)
```

- **On your device:** wallet keys, seed phrase, password, signing, wallet files.
- **On the network:** blockchain sync and transaction broadcast via `zentrad`.

For build and run from the repo root:

```bash
./wallet.sh          # interactive menu
./wallet.sh full     # build native lib + run Linux app
```

See [Getting started](getting-started.md) and [build-linux.md](build-linux.md) for details.
