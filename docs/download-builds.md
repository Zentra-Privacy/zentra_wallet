# Download built apps from GitHub

CI builds **Linux**, **Windows**, **Android (APK)**, and **macOS** apps automatically.

Workflow: **[Build apps (all platforms)](../.github/workflows/build-artifacts.yml)**

---

## When builds run

| Trigger | What happens |
|---------|----------------|
| Push to `main` | All four platforms build |
| Tag `v*` (e.g. `v1.0.0`) | Builds + files attached to a **GitHub Release** |
| **Run workflow** (manual) | Same builds on demand |

---

## How to download (Actions artifacts)

Use this for any completed workflow run (including pushes to `main`).

1. Open the repo on GitHub:  
   **https://github.com/Zentra-Privacy/zentra_wallet**

2. Click the **Actions** tab.

3. In the left sidebar, choose **Build apps (all platforms)**.

4. Click the **latest green** run (✓).

5. Scroll to the bottom → section **Artifacts**.

6. Click an artifact name — GitHub downloads a **`.zip`** wrapper. Unzip it, then use the file inside:

| Artifact name (click to download) | Platform | File inside the wrapper zip |
|-----------------------------------|----------|-----------------------------|
| `zentra-wallet-linux-x64` | Linux | `zentra-wallet-linux-x64.tar.gz` |
| `zentra-wallet-windows-x64` | Windows | `zentra-wallet-windows-x64.zip` |
| `zentra-wallet-android-apk` | Android | `app-release.apk` |
| `zentra-wallet-macos` | macOS | `zentra-wallet-macos.zip` |

Artifacts are kept for **90 days** (GitHub default), then removed.

### Run builds manually

1. **Actions** → **Build apps (all platforms)** → **Run workflow** (right side).
2. Branch: `main` → **Run workflow**.
3. Wait ~15–45 minutes (all jobs).
4. Download from **Artifacts** as above.

---

## How to download (Releases — version tags)

When you push a tag like `v1.0.0`, the same files are attached to a **Release** (easier for end users).

1. Repo → **Releases** (right sidebar on GitHub).
2. Open the release for your tag (e.g. `v1.0.0`).
3. Under **Assets**, download:
   - `zentra-wallet-linux-x64.tar.gz`
   - `zentra-wallet-windows-x64.zip`
   - `zentra-wallet-android.apk`
   - `zentra-wallet-macos.zip`

Create a release tag locally:

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## Install on your machine

### Linux

```bash
tar -xzf zentra-wallet-linux-x64.tar.gz -C ~/zentra-wallet
cd ~/zentra-wallet
./zentra_wallet
```

Requires a recent glibc (same as Ubuntu 22.04+ runners). Install GUI deps if needed:

```bash
sudo apt install libgtk-3-0 libsecret-1-0
```

### Windows

1. Unzip `zentra-wallet-windows-x64.zip`.
2. Open the folder → run `zentra_wallet.exe`.
3. If SmartScreen warns, choose “More info” → “Run anyway” (unsigned debug-style build).

### Android

1. From **Artifacts**, unzip `zentra-wallet-android-apk.zip` → use `app-release.apk`.  
   From **Releases**, use `zentra-wallet-android.apk` directly.
2. Copy the APK to the phone.
3. Enable “Install unknown apps” for your file manager.
4. Open the APK and install.

### macOS

1. Unzip `zentra-wallet-macos.zip`.
2. Open `zentra_wallet.app`.
3. If Gatekeeper blocks: **System Settings → Privacy & Security → Open Anyway**.

---

## Which build has a full wallet?

| Platform | App installs | Full wallet (`wallet2`) |
|----------|--------------|-------------------------|
| **Linux** | ✓ | ✓ (includes `libzentra_wallet_ffi.so`) |
| Windows | ✓ | ✗ UI only until Windows FFI is added |
| Android | ✓ | ✗ UI only until Android FFI is added |
| macOS | ✓ | ✗ UI only until macOS FFI is added |

On Windows / Android / macOS you may see **“Wallet engine unavailable”** until native `libzentra_wallet_ffi` is built for that platform.

### Tag `v*` and the native library

Pushing `v1.0.0` starts **two** workflows:

| Workflow | Output |
|----------|--------|
| **Build apps (all platforms)** | Installable apps (Linux uses `.so` **already in the repo**) |
| **Build native (Linux)** | Fresh `libzentra_wallet_ffi.so` (artifact only — not auto-merged into the release APK/apps) |

For a release with an updated Linux engine: run **Build native** first, copy the `.so` into the repo (or commit it), then tag and run **Build apps**.

---

## Troubleshooting downloads

| Problem | Fix |
|---------|-----|
| No **Artifacts** section | Workflow still running or failed — open the run and check red jobs |
| Artifact expired | Re-run **Build apps (all platforms)** |
| Linux app won’t start | Install `libgtk-3-0` and `libsecret-1-0` |
| Android won’t install | Allow installs from unknown sources |

---

## See also

- [Getting started](getting-started.md) — build from source locally
- [Building](building.md) — native FFI details
