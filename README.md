# Zentra Wallet

Flutter + C++ wallet for the [Zentra](https://github.com/Foisalislambd/zentra) privacy blockchain (Monero fork).

## Architecture

| Layer | Role |
|-------|------|
| **Flutter** (`lib/`) | UI, settings, JSON-RPC client to `zentra-wallet-rpc` |
| **C++** (`packages/zentra_wallet_core/`) | FFI: ZTR amount conversion, address prefix validation, network ports |
| **zentra-wallet-rpc** (external) | Real wallet: keys, sync, sign, broadcast |

The app does **not** embed full `wallet2` yet; it talks to a running `zentra-wallet-rpc` process (same API as Monero wallet RPC).

## Prerequisites

1. Built Zentra binaries from `../zentra`:
   ```bash
   cd ../zentra && scripts/build.sh
   ```
2. Running daemon on your network:
   ```bash
   ./build/release/bin/zentrad --testnet --data-dir ~/.zentra
   ```
3. Running wallet RPC (example testnet):
   ```bash
   ./build/release/bin/zentra-wallet-rpc --testnet \
     --daemon-address 127.0.0.1:29081 \
     --trusted-daemon \
     --rpc-bind-port 8082 \
     --disable-rpc-login
   ```

## Run the app

```bash
flutter pub get
flutter run -d linux   # or android, windows, etc.
```

On first launch: pick network → configure RPC (Settings) → create or restore wallet via RPC.

## Networks

| Network | Address prefix | Daemon RPC | Default wallet RPC |
|---------|----------------|------------|-------------------|
| Mainnet | Z | 19081 | 8082 |
| Testnet | T | 29081 | 8082 |
| Stagenet | S | 39081 | 8082 |

### Mainnet public nodes (VPS)

| Node | IP | Daemon RPC | P2P |
|------|-----|------------|-----|
| seed.zentraprivacy.org | `185.182.185.127` | `:19081` | `:19080` |
| seed1.zentraprivacy.org | `213.136.78.112` | `:19081` | `:19080` |

The app presets these for mainnet (Settings → RPC). **Daemon RPC** on `:19081` is public on the seeds. **Wallet-RPC** must run on the VPS (e.g. `--rpc-bind-ip 0.0.0.0 --rpc-bind-port 8082`) or locally with `--daemon-address <seed-ip>:19081`.

Constants match `zentra/src/cryptonote_config.h`.

## Project layout

```
lib/                    # Flutter app
packages/zentra_wallet_core/   # C++ FFI plugin
```

## Security

- Use RPC login in production (`--rpc-login`); store credentials only on device via Settings.
- Back up wallet `.keys` and seed from `zentra-wallet-cli` / RPC server.
- Testnet coins have no mainnet value.

## Related

- Zentra repo: `/home/foisal/Desktop/cursor/zentra`
- Wallet guide: `zentra/docs/WALLET_GUIDE.md`
