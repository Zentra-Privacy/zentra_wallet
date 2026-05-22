# Project structure

Where code lives and what each part is responsible for.

---

## Repository tree (important paths)

```text
zentra_wallet/
├── lib/                          # Flutter application
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # MaterialApp + Provider
│   ├── providers/
│   │   └── wallet_provider.dart  # Central wallet state
│   ├── services/
│   │   ├── embedded_wallet_service.dart
│   │   └── settings_store.dart
│   ├── core/
│   │   ├── network/              # Networks, public nodes, RPC parse
│   │   ├── seed_utils.dart
│   │   └── native_wallet_messages.dart
│   ├── models/                   # Balance, transfer, node settings
│   └── ui/
│       ├── screens/              # Splash, onboarding, home, send, …
│       ├── widgets/
│       └── theme/
├── packages/zentra_wallet_core/  # FFI + light native plugin
│   ├── lib/src/
│   │   ├── zentra_wallet_ffi_bindings.dart
│   │   └── zentra_core_bindings.dart
│   ├── src/zentra_core.cpp       # Small helpers
│   └── linux/libzentra_wallet_ffi.so  # Built artifact (git may track)
├── native/zentra_wallet_ffi/     # Full wallet2 FFI
│   ├── include/zentra_wallet_ffi.h
│   ├── src/zentra_wallet_ffi.cpp
│   └── CMakeLists.txt
├── scripts/
│   ├── wallet.sh                 # Menu + commands
│   └── lib/
│       ├── native_build.sh
│       ├── flutter_run.sh
│       └── clean_data.sh
├── wallet.sh                     # Root shortcut → scripts/wallet.sh
├── docs/                         # This documentation
├── android/ ios/ linux/ macos/ windows/ web/  # Flutter platforms
└── pubspec.yaml
```

---

## Flutter `lib/` breakdown

| Path | Role |
|------|------|
| `providers/wallet_provider.dart` | Connection state, create/restore/open, send, refresh, settings integration |
| `services/embedded_wallet_service.dart` | FFI lifecycle: init, daemon, wallet handle, send, fee |
| `services/settings_store.dart` | SharedPreferences + secure storage |
| `ui/screens/splash_screen.dart` | Boot, auto-connect |
| `ui/screens/onboarding_screen.dart` | First-run wizard |
| `ui/screens/home_screen.dart` | Main tabs |
| `ui/screens/send_screen.dart` | Outgoing payments |
| `ui/screens/receive_screen.dart` | Address + QR |
| `ui/screens/node_setup_screen.dart` | Daemon configuration |
| `ui/screens/wallet_backup_screen.dart` | Seed display |
| `ui/screens/settings_screen.dart` | Network and wallet options |
| `ui/screens/transactions_screen.dart` | History list |

---

## State management

- **`provider`** package — single `WalletProvider` at app root
- Screens use `context.watch<WalletProvider>()` or `read` for actions
- No Redux / Bloc — kept minimal

---

## `zentra_wallet_core` package

Exports:

- `ZentraCore` — amounts, prefixes, ports (small native lib)
- `ZentraNativeWallet` — full wallet FFI (`.so`)
- `ZentraNetwork` enum — matches C `nettype`

Dart FFI bindings live in `zentra_wallet_ffi_bindings.dart` — maps C functions from `zentra_wallet_ffi.h`.

---

## Native FFI

| File | Purpose |
|------|---------|
| `zentra_wallet_ffi.h` | Public C API |
| `zentra_wallet_ffi.cpp` | wallet2 implementation |
| `CMakeLists.txt` | Link against Zentra static libraries |

---

## Scripts

| Script | Purpose |
|--------|---------|
| `wallet.sh` | User-facing entry |
| `native_build.sh` | Zentra + FFI compile, copy `.so` |
| `flutter_run.sh` | `flutter run` wrapper |
| `clean_data.sh` | Delete local app data for testing |

---

## Tests

- `test/widget_test.dart` — minimal Flutter test scaffold
- No integration tests against live daemon in repo by default

---

## External dependency (not in this repo)

**Zentra** full source tree — required to build `libzentra_wallet_ffi.so`. Typically cloned as sibling `../zentra` or `third_party/zentra`.

---

## See also

- [Architecture](architecture.md)
- [Native FFI reference](native-ffi.md)
- [Building from source](building.md)
