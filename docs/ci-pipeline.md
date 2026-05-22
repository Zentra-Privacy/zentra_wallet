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
| `engine-ubuntu` | ubuntu-22.04 | Linux `.so`, Android ABIs, Windows `.dll` |
| `package-engine` | ubuntu-latest | Artifact **`native-engine-bundle`** |

Scripts:

- `scripts/ci-clone-zentra.sh`
- `scripts/ci-build-native-engine-ubuntu.sh`
- `scripts/ci-package-native-engine.sh`
- `scripts/ci-verify-native-engine.sh` (Linux + Windows + Android only)

First run can take **2–6+ hours** (Zentra `contrib/depends`). GitHub cache speeds up later runs.

Every run builds the engine from **Zentra v0.1.0** (no “skip rebuild” shortcut).

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
./wallet.sh build              # Linux
./wallet.sh build-android      # Android
./wallet.sh build-windows      # Windows DLL
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
