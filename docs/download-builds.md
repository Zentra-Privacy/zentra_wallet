# Download built apps from GitHub

CI builds **Linux**, **Windows**, **Android (APK)**, and **macOS** apps automatically.

Workflow: **[Release pipeline](../.github/workflows/build-artifacts.yml)**

---

## When builds run

| Trigger | What happens |
|---------|----------------|
| **Pull request** to `main` | [**CI**](../.github/workflows/ci.yml) only (analyze, test, Linux debug) — no release builds |
| Push to `main` (or **Run workflow**) | All platforms → **draft release** (only if every platform job succeeds) |
| Tag `v*` (e.g. `v1.0.0`) | All platforms → **published** GitHub Release (no draft) |

---

## Draft release (auto on `main` — review then publish)

Every **fully green** **Release pipeline** run on **`main`** creates a **draft** release (not public until you publish). If any platform job fails, no draft is created — use **Artifacts** on that run for whatever succeeded.

1. Repo → **Releases** → find **Draft** (e.g. `Draft build #42`, tag `draft-42`).
2. Download assets and test Linux / Windows / APK / macOS.
3. Change release notes if you want → **Edit**.
4. Happy? Click **Publish release** → users see it as a normal release.
5. Not happy? Fix code, push to `main` again → a **new** draft (`draft-43`) is created.

Draft releases use tags like `draft-42` (run number). They are **not** the same as version tags (`v1.0.0`).

### Official version (when ready)

```bash
git tag v1.0.0
git push origin v1.0.0
```

That creates a **published** release (not draft) with the `v1.0.0` tag.

---

## How to download (Actions artifacts)

Use this for any completed workflow run (including pushes to `main`).

1. Open the repo on GitHub:  
   **https://github.com/Zentra-Privacy/zentra_wallet**

2. Click the **Actions** tab.

3. In the left sidebar, choose **Release pipeline**.

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

1. **Actions** → **Release pipeline** → **Run workflow** (right side).
2. Branch: `main` → **Run workflow**.
3. Wait ~10–30 minutes (four platform jobs in parallel).
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

Built on **Ubuntu 22.04** CI runners (matches `libzentra_wallet_ffi.so`). Install GUI deps if needed:

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
| **Linux** | ✓ | ✓ |
| **Windows** | ✓ | ✓ (CI builds `libzentra_wallet_ffi.dll`) |
| **Android** | ✓ | ✓ arm64 in CI; more ABIs via `./wallet.sh build-android` |
| **macOS** | ✓ | ✓ (CI builds on `macos-latest`) |
| **iOS** | — | ✗ not in CI yet |

**Release pipeline** ([ci-pipeline.md](ci-pipeline.md)): Phase 1 builds the wallet engine from [Zentra v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0), Phase 2 builds all apps, Phase 3 creates the draft release. First run can take **several hours**; cache helps later runs.

### Native libraries

**Linux** — CI uses the committed `.so`:

```bash
./wallet.sh build
git add packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so
```

**Android** — see [building-android.md](building-android.md):

```bash
./wallet.sh build-android
git add packages/zentra_wallet_core/android/src/main/jniLibs/
```

---

## Troubleshooting downloads

| Problem | Fix |
|---------|-----|
| No **Artifacts** section | Workflow still running or failed — open the run and check red jobs |
| Artifact expired | Re-run **Release pipeline** |
| Linux app won’t start | Install `libgtk-3-0` and `libsecret-1-0` |
| Android won’t install | Allow installs from unknown sources |

---

## See also

- [Getting started](getting-started.md) — build from source locally
- [Building](building.md) — native FFI details
