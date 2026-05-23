# CI/CD pipeline (production)

Automated **Linux + Windows + Android** releases on every push to `main` and on version tags.

**macOS / iOS** are **not** built in CI — use a Mac locally ([build-macos.md](build-macos.md), [build-ios.md](build-ios.md)).

**Zentra core (pinned):** [Zentra-Privacy/zentra](https://github.com/Zentra-Privacy/zentra.git) tag **[v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)**

Workflow: [`.github/workflows/build-artifacts.yml`](../.github/workflows/build-artifacts.yml) (**Release pipeline**)

---

## Phase 1 — Native wallet engine (Ubuntu only)

One job builds all three native targets:

| Job | Runner | Outputs |
|-----|--------|---------|
| `engine-ubuntu` | ubuntu-22.04 | Linux `.so`, Android ABIs, Windows `.dll` (needs MinGW + `libtinfo5` via `ci-install-linux-deps.sh all`) |
| `package-engine` | ubuntu-latest | Artifact **`native-engine-bundle`** |

Scripts:

- `scripts/ci-clone-zentra.sh` — Zentra v0.1.0
- `scripts/ci-patch-zentra-depends.sh` — MinGW zeromq fix (required)
- `scripts/ci-preflight-engine.sh` — fail fast (MinGW, libtinfo5, patches)
- `scripts/ci-build-native-engine-ubuntu.sh` — **Linux → Windows → Android** order
- `scripts/ci-package-native-engine.sh` / `ci-verify-native-engine.sh`

First run can take **2–6+ hours** (Zentra `contrib/depends`). Cache key includes `scripts/patches/zentra-depends/PATCHSET_VERSION` (bump when patches change).

See [ci-troubleshooting.md](ci-troubleshooting.md) for common errors.

Every run builds the engine from **Zentra v0.1.0** (no “skip rebuild” shortcut).

**FFI linking (Android / Windows cross-build):** `native/zentra_wallet_ffi/cmake/ZentraDepends.cmake` resolves static `.a` files directly from `contrib/depends/<triplet>/lib` (tagged Boost names, no `-lboost_*`). Optional Zentra libs: `libwallet-crypto.a`, `libdevice_trezor.a` (Android uses `USE_DEVICE_TREZOR=OFF`). Phase 1 verifies bundle size and ELF architecture before upload.

**Windows depends (MinGW):** Ubuntu needs `g++-mingw-w64-x86-64` (in `ci-install-linux-deps.sh all`). Zentra v0.1.0 zeromq 4.3.4 needs `scripts/ci-patch-zentra-depends.sh` (`--with-cv-impl=pthread` for MinGW — fixes `condition_variable_any` compile errors).

---

## Phase 2 — Flutter apps

| Job | Runner | Artifact |
|-----|--------|----------|
| `build-linux` | ubuntu-22.04 | `zentra-wallet-linux-x64.tar.gz` |
| `build-windows` | windows-latest | `zentra-wallet-windows-x64.zip` |
| `build-android` | ubuntu-latest | `app-release.apk` |

All three download the same **`native-engine-bundle`** and run `ci-apply-native-libs.sh`.

---

## Phase 3 — GitHub Release

Draft release is created only when **all three** app jobs succeed (iOS/macOS not required).

| Trigger | Result |
|---------|--------|
| Push to `main` | **Draft** release (`draft-<run>`) |
| Tag `v*` | **Published** release |

---

## PR / fast CI (pull requests only)

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on **pull requests** only (not on push to `main`):

- `flutter analyze` + `flutter test`
- Linux **debug** build using committed `libzentra_wallet_ffi.so`

Push to `main` uses **Release pipeline** only — no duplicate Linux CI build.

---

## Local parity (same as CI Phase 1)

```bash
export ZENTRA_REF=v0.1.0
git clone -b v0.1.0 --recurse-submodules https://github.com/Zentra-Privacy/zentra.git third_party/zentra

sudo ./scripts/ci-install-linux-deps.sh all
./scripts/ci-clone-zentra.sh third_party/zentra
./scripts/ci-patch-zentra-depends.sh third_party/zentra
./scripts/ci-build-native-engine-ubuntu.sh   # same as CI Phase 1
```

---

## Platform coverage

| OS | CI Release pipeline | Manual on Mac |
|----|---------------------|---------------|
| Linux | ✓ | — |
| Windows | ✓ | — |
| Android | ✓ | — |
| macOS | — | [build-macos.md](build-macos.md) |
| iOS | — | [build-ios.md](build-ios.md) |

---

## See also

- [Download builds](download-builds.md)
- [Build Linux](build-linux.md) · [Windows](build-windows.md) · [Android](build-android.md)
- [Building overview](building.md)
