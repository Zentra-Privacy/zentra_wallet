#!/usr/bin/env bash
# Build and run Zentra Wallet on a Flutter device (Linux, Android, Chrome, etc.)
#
# Usage:
#   ./scripts/build_and_run.sh              # auto-pick first device
#   ./scripts/build_and_run.sh -d linux     # desktop Linux
#   ./scripts/build_and_run.sh -d chrome    # web (Chrome)
#   ./scripts/build_and_run.sh -l           # list devices
#   ./scripts/build_and_run.sh -d android --release
#   ./scripts/build_and_run.sh -b -d linux -r   # build bundle only (no run)
#
# Before using the wallet:
#   - ./scripts/build_native_wallet.sh  (embedded wallet2; required on Linux)
#   - mainnet: VPS zentrad on :19081 (seeds) — no wallet-rpc
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="debug"
DEVICE=""
BUILD_ONLY=0
LIST_DEVICES=0
SKIP_PUB=0
RUN_ARGS=()

usage() {
  cat <<'EOF'
Zentra Wallet — build & run

Options:
  -d, --device ID     Flutter device id (linux, chrome, android, emulator-5554, …)
  -l, --list          List connected devices and exit
  -r, --release       Release build (slower; optimized)
  -b, --build-only    Build bundle/APK only, do not launch
  --skip-pub          Skip flutter pub get
  -h, --help          This help

Examples:
  ./scripts/build_and_run.sh
  ./scripts/build_and_run.sh -d linux
  ./scripts/build_and_run.sh -d chrome
  ./scripts/build_and_run.sh -d android -r
  ./scripts/build_and_run.sh -b -d linux -r
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      DEVICE="${2:?missing device id}"
      shift 2
      ;;
    -l|--list)
      LIST_DEVICES=1
      shift
      ;;
    -r|--release)
      MODE="release"
      shift
      ;;
    -b|--build-only)
      BUILD_ONLY=1
      shift
      ;;
    --skip-pub)
      SKIP_PUB=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      RUN_ARGS+=("$1")
      shift
      ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter not in PATH. Install Flutter SDK first."
  exit 1
fi

echo "==> Project: $ROOT"
flutter --version | head -1

if [[ "$LIST_DEVICES" -eq 1 ]]; then
  echo "==> Connected devices:"
  flutter devices
  echo ""
  echo "==> Emulators (if any):"
  flutter emulators 2>/dev/null || true
  exit 0
fi

if [[ "$SKIP_PUB" -eq 0 ]]; then
  echo "==> flutter pub get"
  flutter pub get
fi

# Linux desktop needs embedded wallet2 .so
if [[ "$DEVICE" == "linux" || -z "$DEVICE" ]]; then
  _so="${ROOT}/packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so"
  if [[ ! -f "$_so" ]] && [[ -x "${ROOT}/scripts/build_native_wallet.sh" ]]; then
    echo "==> Native wallet library missing; running build_native_wallet.sh"
    "${ROOT}/scripts/build_native_wallet.sh" || echo "Warning: native wallet build failed; app will show onboarding error."
  fi
fi

# Resolve device
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for d in data:
        if d.get('ephemeral'): continue
        print(d['id'])
        break
except Exception:
    pass
" 2>/dev/null || true)"
  if [[ -z "$DEVICE" ]]; then
    echo "Error: no device found. Plug in a phone (USB debugging) or use -d linux / -d chrome"
    echo "Run: ./scripts/build_and_run.sh -l"
    exit 1
  fi
  echo "==> Auto-selected device: $DEVICE"
fi

# Verify device exists (machine JSON only — avoids broken pipe from flutter devices | grep)
_device_ok="$(flutter devices --machine 2>/dev/null | DEVICE_ID="$DEVICE" python3 -c "
import json, os, sys
target = os.environ.get('DEVICE_ID', '')
try:
    data = json.load(sys.stdin)
    ok = any(d.get('id') == target for d in data)
    print('yes' if ok else 'no')
except Exception:
    print('no')
" 2>/dev/null || echo "no")"
if [[ "$_device_ok" != "yes" ]]; then
  echo "Error: device '$DEVICE' not found. Available:"
  flutter devices
  exit 1
fi

FLUTTER_BUILD=(flutter build)
FLUTTER_RUN=(flutter run -d "$DEVICE" --no-pub)

if [[ "$MODE" == "release" ]]; then
  FLUTTER_BUILD+=(--release)
  FLUTTER_RUN+=(--release)
fi

echo "==> Build mode: $MODE | device: $DEVICE"

_build_target() {
  case "$DEVICE" in
    linux)
      echo "==> Building Linux ($MODE)..."
      "${FLUTTER_BUILD[@]}" linux
      ;;
    chrome|web)
      DEVICE="chrome"
      FLUTTER_RUN=(flutter run -d chrome --no-pub)
      if [[ "$MODE" == "release" ]]; then
        FLUTTER_RUN+=(--release)
      fi
      echo "==> Building Web ($MODE)..."
      "${FLUTTER_BUILD[@]}" web
      ;;
    android)
      echo "==> Building APK ($MODE)..."
      "${FLUTTER_BUILD[@]}" apk
      ;;
    ios)
      echo "==> Building iOS ($MODE)..."
      "${FLUTTER_BUILD[@]}" ios --no-codesign
      ;;
    macos)
      echo "==> Building macOS ($MODE)..."
      "${FLUTTER_BUILD[@]}" macos
      ;;
    windows)
      echo "==> Building Windows ($MODE)..."
      "${FLUTTER_BUILD[@]}" windows
      ;;
    emulator-*)
      echo "==> Building APK for emulator ($MODE)..."
      "${FLUTTER_BUILD[@]}" apk
      ;;
    *)
      echo "==> Unknown device type '$DEVICE'; flutter run will compile."
      ;;
  esac
}

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  _build_target
  echo "==> Build finished (build-only). Artifacts under build/"
  exit 0
fi

# Run path: flutter run compiles once — skip redundant "flutter build" pre-step.
echo "==> Launching app on $DEVICE (single compile via flutter run)..."
echo "    (Ctrl+C to stop)"
exec "${FLUTTER_RUN[@]}" "${RUN_ARGS[@]}"
