# CI/CD pipeline (production)

Two-phase release on every push to `main` and on version tags.

**Zentra core (pinned):** [Zentra-Privacy/zentra](https://github.com/Zentra-Privacy/zentra.git) tag **[v0.1.0](https://github.com/Zentra-Privacy/zentra/releases/tag/v0.1.0)**

Workflow file: [`.github/workflows/build-artifacts.yml`](../.github/workflows/build-artifacts.yml) (name: **Release pipeline**)

---

## Phase 1 — Native wallet engine

Builds `libzentra_wallet_ffi` from Zentra `wallet_api` + FFI wrapper.

| Job | Runner | Outputs |
|-----|--------|---------|
| `engine-ubuntu` | ubuntu-22.04 | Linux `.so`, Android `arm64-v8a` + `armeabi-v7a`, Windows `.dll` |
| `engine-macos` | macos-latest | macOS `.dylib` + iOS `zentra_wallet_ffi.xcframework` |
| `package-engine` | ubuntu-latest | Merged artifact **`native-engine-bundle`** |

Scripts:

- `scripts/ci-clone-zentra.sh` — clone/checkout **v0.1.0**
- `scripts/ci-build-native-engine-ubuntu.sh`
- `scripts/ci-build-native-engine-macos.sh`
- `scripts/ci-package-native-engine.sh`
- `scripts/ci-verify-native-engine.sh`

First run can take **several hours** (Zentra `contrib/depends`). Cache speeds up later runs.

### Skip engine rebuild (manual)

**Actions → Release pipeline → Run workflow** → enable **skip_engine_rebuild** to use native libraries already committed under `packages/zentra_wallet_core/` (fast, for UI-only changes).

Requires **all five** engine files in the repo (not only Linux):

- `packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so`
- `packages/zentra_wallet_core/windows/libzentra_wallet_ffi.dll`
- `packages/zentra_wallet_core/macos/lib/libzentra_wallet_ffi.dylib`
- `packages/zentra_wallet_core/android/src/main/jniLibs/arm64-v8a/libzentra_wallet_ffi.so`
- `packages/zentra_wallet_core/android/src/main/jniLibs/armeabi-v7a/libzentra_wallet_ffi.so`
- `packages/zentra_wallet_core/ios/lib/zentra_wallet_ffi.xcframework`

If any are missing, the job fails with a clear error. Default runs rebuild everything from Zentra **v0.1.0**.

---

## Phase 2 — Flutter apps

Each platform job downloads **`native-engine-bundle`**, runs `ci-apply-native-libs.sh`, then `flutter build`.

| Job | Artifact |
|-----|----------|
| `build-linux` | `zentra-wallet-linux-x64.tar.gz` |
| `build-windows` | `zentra-wallet-windows-x64.zip` |
| `build-android` | `app-release.apk` (arm64 + armeabi-v7a) |
| `build-macos` | `zentra-wallet-macos.zip` |
| `build-ios` | `zentra-wallet-ios.zip` (unsigned `.app`) |

---

## Phase 3 — GitHub Release

| Trigger | Result |
|---------|--------|
| Push to `main` | **Draft** release (`draft-<run>`) |
| Tag `v*` | **Published** release |

---

## PR / fast CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — analyze, test, Linux debug build using **committed** `libzentra_wallet_ffi.so` (no Zentra rebuild on PRs).

---

## Local parity

```bash
export ZENTRA_REF=v0.1.0
git clone -b v0.1.0 https://github.com/Zentra-Privacy/zentra.git ../zentra

sudo ./scripts/ci-install-linux-deps.sh all
./wallet.sh build-all-native   # same engines as Phase 1
```

---

## Platform coverage

| OS | Phase 1 engine | Phase 2 app | Full wallet |
|----|----------------|-------------|-------------|
| Linux | ✓ host build | ✓ | ✓ |
| Windows | ✓ MinGW | ✓ | ✓ |
| Android | ✓ arm64 + armeabi-v7a | ✓ | ✓ |
| macOS | ✓ on Mac runner | ✓ | ✓ |
| iOS | ✓ | ✓ | XCFramework + unsigned `.app` zip |

---

## See also

- [Download builds](download-builds.md)
- [Build Android (manual)](build-android.md)
- [Build iOS (manual)](build-ios.md)
- [First release guide](first-release-guide.md)
