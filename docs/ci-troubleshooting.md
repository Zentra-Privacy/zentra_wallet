# CI troubleshooting (Release pipeline)

Common **Phase 1 · engine-ubuntu** failures and fixes.

---

## Before a long rebuild

1. Push **all** fixes in `scripts/`, `native/zentra_wallet_ffi/`, and `.github/workflows/build-artifacts.yml`.
2. In GitHub Actions, **cancel** old runs and start a **new** workflow (old runs use old scripts).
3. First green run after cache key change may take **hours**; later runs use cache.

---

## Error → cause → fix

| Symptom | Cause | Fix |
|---------|--------|-----|
| `x86_64-w64-mingw32-gcc` / `cannot create executables` (libiconv) | MinGW not installed on runner | `ci-install-linux-deps.sh all` includes `g++-mingw-w64-x86-64` |
| `condition_variable_any` (zeromq 4.3.4, MinGW) | STL11 CV broken on MinGW cross-compile | `ci-patch` → **zeromq 4.3.1** + `-O1` |
| `mutex_t has no member named get_mutex` (zeromq) | `--with-cv-impl=pthread` wrong for MinGW | Same patch: **4.3.1**, no pthread override |
| `std::mutex` / `once_flag` (protobuf 3.6.1, MinGW) | Ubuntu MinGW defaults to **win32** threading | `ci-configure-mingw-posix.sh` → **gcc/g++-posix** |
| `ZENTRA_BUILD_DIR` newline / wrong path | Was capturing cmake stdout in `$(...)` | Fixed: explicit `zbuild=` paths |
| Missing `libwallet-crypto.a` | Android uses internal crypto | Optional in FFI CMake |
| `cannot find -lboost_*` | Depends libs need full `.a` paths | `ZentraDepends.cmake` |
| `libtinfo.so.5` / NDK | Android depends need libtinfo5 | `apt install libtinfo5` (in CI deps) |
| Failure after **hours** on Android, then Windows | Build order was Linux → Android → Windows | **Windows now runs before Android** |
| Weird errors after many CI attempts | Stale GitHub cache (`restore-keys` old prefix) | Cache key includes `PATCHSET_VERSION`; no broad `restore-keys` |

---

## Build order (Phase 1)

```text
preflight → patch → Linux → Windows (MinGW) → Android arm64 → Android armv7 → verify
```

Windows runs **before** Android so MinGW/zeromq issues fail in ~30–90 min, not after 3+ hours.

---

## Local = CI

```bash
sudo ./scripts/ci-install-linux-deps.sh all   # sets MinGW gcc/g++ to posix
./scripts/ci-clone-zentra.sh third_party/zentra
./scripts/ci-patch-zentra-depends.sh third_party/zentra
./scripts/ci-preflight-engine.sh third_party/zentra
./scripts/ci-build-native-engine-ubuntu.sh
```

Or: `./wallet.sh build-windows` (auto-applies patch if needed).

---

## Still failing?

Copy the **last 50 lines** of the failed step log (package name + compiler error). Open an issue with workflow run URL.
