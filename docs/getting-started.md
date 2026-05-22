# Getting started

This guide gets you from zero to a running Zentra Wallet on **Linux** (the primary development platform).

---

## Prerequisites

### Software

| Tool | Purpose |
|------|---------|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12+) | UI app |
| `cmake`, C++17 compiler | Native builds |
| Boost, OpenSSL, Protobuf, and other Zentra build deps | Linking `libzentra_wallet_ffi.so` |
| [Zentra source](https://github.com/Zentra-Privacy/zentra) | wallet_api / wallet2 |

### Zentra source location

The build scripts look for Zentra in this order:

1. Environment variable `ZENTRA_ROOT`
2. Sibling folder: `../zentra` (next to this repo)
3. `third_party/zentra` inside this repo

The folder must contain `src/wallet/api/wallet2_api.h`.

Example:

```bash
git clone -b zentra-main --recurse-submodules https://github.com/Zentra-Privacy/zentra.git ../zentra
# or
export ZENTRA_ROOT=/path/to/zentra
```

---

## Clone and open the wallet repo

```bash
git clone <your-zentra-wallet-repo-url> zentra_wallet
cd zentra_wallet
```

---

## Build and run (easiest path)

From the repo root:

```bash
./wallet.sh
```

Use the interactive menu:

1. **Build native library** — compiles Zentra `wallet_api` (if needed) and `libzentra_wallet_ffi.so`
2. **Run app (Linux)** — starts the Flutter Linux desktop app

Or non-interactive:

```bash
./wallet.sh status    # check Zentra path, .so, Flutter
./wallet.sh build     # build native lib only
./wallet.sh run       # run app (builds first if .so missing)
./wallet.sh full      # build + run
```

---

## First launch in the app

1. **Splash** — loads settings and tries to connect if you already onboarded
2. **Onboarding** (first time):
   - Pick **network** (mainnet / testnet / stagenet)
   - Configure **node** (mainnet: pick a seed node; testnet: usually local `zentrad`)
   - **Create** a new wallet, **restore** from seed, or **open** an existing wallet file
3. **Backup screen** — shows seed phrase; store it safely offline
4. **Home** — dashboard with balance after sync

See [User guide](user-guide.md) for each screen.

---

## Mainnet without your own node

On **mainnet**, the app defaults to public seed daemons (see [Networks and nodes](networks-and-nodes.md)). You can start using the wallet without running `zentrad` yourself — as long as those nodes are online.

For **testnet** and **stagenet**, defaults point to `127.0.0.1` — you should run `zentrad` locally on the matching port.

---

## Ubuntu 22 VM (recommended for release-like builds)

Building the `.so` on the same OS/glibc you deploy avoids linker/runtime surprises:

```bash
# On Ubuntu 22: install build deps + Flutter
./wallet.sh build
./wallet.sh run
```

---

## Clean test data

To wipe local wallet files and preferences (destructive):

```bash
./wallet.sh clean-data          # dry-run, shows paths
./wallet.sh clean-data --yes    # deletes after confirmation
```

Data lives under `~/.local/share/com.example.zentra_wallet/` on Linux (see `scripts/lib/clean_data.sh`).

---

## Environment variables (optional)

| Variable | Effect |
|----------|--------|
| `ZENTRA_ROOT` | Path to Zentra source |
| `ZENTRA_BUILD` | Zentra CMake build dir (default: `$ZENTRA_ROOT/build/release`) |
| `ZENTRA_WALLET_FFI_PATH` | Full path to `.so` when running Flutter (Linux debug) |
| `JOBS` | Parallel make jobs for native build |
| `ZENTRA_APP_ID` | App data folder name for `clean-data` |

---

## If the app says “Wallet engine unavailable”

The native library was not found or failed to load. Fix:

1. Run `./wallet.sh build` successfully
2. Confirm file exists: `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`
3. Run `./wallet.sh status`

Details: [Troubleshooting](troubleshooting.md).

---

## Next steps

- [Building from source](building.md) — deep dive into CMake and dependencies
- [User guide](user-guide.md) — everyday wallet usage
- [Security](security.md) — passwords and backups
