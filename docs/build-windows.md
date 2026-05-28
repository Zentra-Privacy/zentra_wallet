# Build guide — Windows

Build the **Windows x64** desktop app with the full **wallet2** engine.

**Important:** The **native DLL** is cross-compiled on **Linux** (MinGW + Zentra `contrib/depends`). The **Flutter Windows app** must be built on a **Windows PC**.

**Output:**

- `packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll`
- `build/windows/x64/runner/Release/` (Flutter app)

**Zentra pin:** [v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)

---

## Overview

```text
Linux host                          Windows PC
──────────                          ──────────
Zentra depends (x86_64-w64-mingw32)
  → libzentra_wallet_ffi.dll    →   flutter build windows
  → copy to packages/.../windows/
```

---

## Part A — Build native DLL (Linux host)

Use **Ubuntu 22.04** (VM or bare metal).

### A1. Install dependencies

```bash
sudo apt update
sudo ./scripts/ci-install-linux-deps.sh all
```

Also install MinGW cross toolchain:

```bash
sudo apt install -y g++-mingw-w64-x86-64 gcc-mingw-w64-x86-64 mingw-w64
sudo ./scripts/ci-configure-mingw-posix.sh   # required: posix threading for protobuf
```

### A2. Clone repos

```bash
git clone https://github.com/Zentra-Privacy/zentra_wallet.git
cd zentra_wallet

git clone -b v0.1.0 --recurse-submodules \
  https://github.com/Zentra-Privacy/zentra.git third_party/zentra
```

### A3. Build DLL

```bash
./wallet.sh build-windows
```

First run: **1–3 hours** (Zentra `contrib/depends` for `x86_64-w64-mingw32`).

Verify:

```bash
ls -lh packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll
```

### A4. Copy DLL to Windows machine

Copy the whole `zentra_wallet` repo (or at minimum):

- `packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll`
- Full git tree for Flutter build

---

## Part B — Build Flutter app (Windows)

### B1. Prerequisites on Windows

| Tool | Notes |
|------|--------|
| [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) | Stable channel |
| **Visual Studio 2022** | “Desktop development with C++” workload |
| **Git** | For Flutter and repo |

```powershell
flutter doctor
flutter config --enable-windows-desktop
```

### B2. Get the project

```powershell
git clone https://github.com/Zentra-Privacy/zentra_wallet.git
cd zentra_wallet
```

Ensure `packages\zentra_wallet_core\windows\libzentra_wallet_ffi.dll` exists (from Part A).

### B3. Build release app

```powershell
flutter pub get
flutter build windows --release
```

**Output folder:**

```text
build\windows\x64\runner\Release\
```

Zip for distribution:

```powershell
Compress-Archive -Path build\windows\x64\runner\Release\* `
  -DestinationPath zentra-wallet-windows-x64.zip
```

### B4. Run

```powershell
.\build\windows\x64\runner\Release\zentra_wallet.exe
```

Or:

```powershell
flutter run -d windows
```

---

## Verify

| Check | Expected |
|-------|----------|
| DLL present | `packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll` |
| EXE runs | App opens without “Wallet engine unavailable” |
| Create wallet | Onboarding completes, sync starts |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `build-windows` fails on depends | Retry on Ubuntu 22.04; ensure `libtinfo5`, `python3`, disk space |
| Flutter: Visual Studio missing | Install VS 2022 with C++ desktop tools (`flutter doctor`) |
| Engine unavailable on Windows | See below |
| Wrong architecture | DLL must be **x64** MinGW build, matching Flutter Windows x64 |

### “Wallet engine unavailable” on Windows

Same message as Android: `libzentra_wallet_ffi.dll` is missing or failed to load.

1. **Release folder** — must include `libzentra_wallet_ffi.dll` next to `zentra_wallet.exe`.
2. **Build order** — run `./wallet.sh build-windows` on Linux **before** `flutter build windows` on Windows.
3. **MinGW runtimes** — copy beside the exe if needed: `libstdc++-6.dll`, `libgcc_s_seh-1.dll`, `libwinpthread-1.dll` (from the same MinGW toolchain that built the DLL).
4. After updating DLLs: `flutter clean && flutter build windows --release`.

---

## All-in-one on Linux (DLL only)

If you only need the DLL and will build the UI on Windows later:

```bash
export ZENTRA_ROOT="$PWD/third_party/zentra"
./wallet.sh build-windows
```

---

## See also

- [build-linux.md](build-linux.md) — same host used for MinGW cross-compile
- [building.md](building.md)
