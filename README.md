# Zentra Wallet

[![CI](https://github.com/Zentra-Privacy/zentra_wallet/actions/workflows/ci.yml/badge.svg)](https://github.com/Zentra-Privacy/zentra_wallet/actions/workflows/ci.yml)

Self-custody mobile/desktop wallet for [Zentra](https://github.com/Zentra-Privacy/zentra) — same model as **Cake Wallet** / Monero GUI: **wallet2 runs inside the app**, only the public **daemon** (`zentrad`) is remote.

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

---

## How to build and run (Linux)

Follow these steps on **Ubuntu 22.04** (or similar Debian/Ubuntu). That is the supported dev platform.

### 1. Prerequisites

| Tool | Install |
|------|---------|
| **Flutter** 3.12+ | [flutter.dev/docs/get-started/install/linux](https://docs.flutter.dev/get-started/install/linux) — enable Linux desktop: `flutter config --enable-linux-desktop` |
| **Build tools** | See step 2 below |
| **Zentra source** | Clone in step 3 — required to **rebuild** the native wallet library |

Check Flutter:

```bash
flutter doctor
flutter --version   # should be 3.12+
```

### 2. Install system packages

From the wallet repo root:

```bash
git clone https://github.com/Zentra-Privacy/zentra_wallet.git
cd zentra_wallet
sudo ./scripts/ci-install-linux-deps.sh all
```

This installs packages for **Flutter Linux** and **native FFI** (Boost, OpenSSL, Protobuf, etc.). For Flutter-only (`.so` already in repo):

```bash
sudo ./scripts/ci-install-linux-deps.sh flutter
```

### 3. Clone Zentra (for native build)

The wallet links against Zentra’s `wallet_api`. Put the Zentra repo next to this one **or** set `ZENTRA_ROOT`:

```bash
# Option A — sibling folder (auto-detected)
git clone -b zentra-main --recurse-submodules https://github.com/Zentra-Privacy/zentra.git ../zentra

# Option B — inside this repo
git clone -b zentra-main --recurse-submodules https://github.com/Zentra-Privacy/zentra.git third_party/zentra

# Option C — anywhere
export ZENTRA_ROOT=/path/to/zentra
```

The folder must contain `src/wallet/api/wallet2_api.h`.

### 4. Build the native wallet engine

```bash
cd zentra_wallet
./wallet.sh status    # Zentra path, .so, Flutter
./wallet.sh build     # → packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so
```

First build can take a long time (Zentra `wallet_api` + FFI). Later runs are incremental.

### 5. Run the app

```bash
./wallet.sh run
```

Or build + run in one step:

```bash
./wallet.sh full
```

The Linux desktop window should open. On **mainnet** you can sync via built-in seed nodes without running your own `zentrad`.

### 6. Interactive menu (optional)

```bash
./wallet.sh
```

Menu: build native lib, run app, status, clean test data.

### Quick reference

| Goal | Command |
|------|---------|
| Check setup | `./wallet.sh status` |
| Build native `.so` only | `./wallet.sh build` |
| Run app | `./wallet.sh run` |
| Build + run | `./wallet.sh full` |
| List Flutter devices | `./wallet.sh devices` |
| Reset local test wallets | `./wallet.sh clean-data` |
| Help | `./wallet.sh help` |

### Run without rebuilding native (CI / quick UI)

The repo may already include `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`. Then:

```bash
flutter pub get
flutter run -d linux
```

If you see **“Wallet engine unavailable”**, run `./wallet.sh build`.

### Ubuntu 22 VM (release-like builds)

Build the `.so` on the same OS/glibc you ship on:

```bash
./wallet.sh build
./wallet.sh run
```

---

## CI/CD (GitHub Actions)

| Workflow | When | What it does |
|----------|------|----------------|
| [**CI**](.github/workflows/ci.yml) | Every push / PR to `main` | Analyze, test, Linux debug build |
| [**Build apps**](.github/workflows/build-artifacts.yml) | `main`, tags `v*`, or **Run workflow** | **Linux, Windows, Android APK, macOS** — downloadable artifacts |
| [**Build native**](.github/workflows/build-native-linux.yml) | Tags `v*`, weekly, or **Run workflow** | Rebuild `libzentra_wallet_ffi.so` from Zentra source |

### Download built apps (Linux / Windows / APK / macOS)

**Full guide:** **[docs/download-builds.md](docs/download-builds.md)**

Quick steps:

1. GitHub → **Actions** → **Build apps (all platforms)** → latest green run.
2. Scroll down → **Artifacts** → download (e.g. `zentra-wallet-linux-x64`, `zentra-wallet-android-apk`).
3. For version releases: push tag `v1.0.0` → **Releases** → download assets.

| Artifact | Platform |
|----------|----------|
| `zentra-wallet-linux-x64` | Linux `.tar.gz` — **full wallet** |
| `zentra-wallet-windows-x64` | Windows `.zip` |
| `zentra-wallet-android-apk` | Android `.apk` |
| `zentra-wallet-macos` | macOS `.zip` |

> **Note:** Only the **Linux** build includes the full native wallet engine today. Windows / Android / macOS packages install the UI but show “Wallet engine unavailable” until FFI is built for those platforms.

Local parity with CI:

```bash
flutter analyze
flutter test
flutter build linux --debug
```

---

## Networks

| Network | Prefix | Daemon RPC |
|---------|--------|------------|
| Mainnet | Z | 19081 |
| Testnet | T | 29081 (local `zentrad`) |
| Stagenet | S | 39081 |

---

## Documentation

Full guides (architecture, security, build, user guide, FAQ):

**[docs/README.md](docs/README.md)** · [Getting started](docs/getting-started.md) · [Building](docs/building.md)

---

## Project layout

- `lib/` — Flutter app (no wallet-RPC client)
- `native/zentra_wallet_ffi/` — C API over `wallet2`
- `docs/` — guides in English
- `wallet.sh` — build and run (single entry point)
- `.github/workflows/` — CI/CD
