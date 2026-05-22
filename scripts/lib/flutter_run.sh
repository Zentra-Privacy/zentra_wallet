#!/usr/bin/env bash
# Flutter build/run. Usage: flutter_wallet_run [args...]  (-d linux, -l, -r, -b, etc.)
flutter_wallet_run() {
  local ROOT="${WALLET_ROOT:?}"
  cd "$ROOT"

  local MODE="debug" DEVICE="" BUILD_ONLY=0 LIST_DEVICES=0 SKIP_PUB=0
  local -a RUN_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--device) DEVICE="${2:?}"; shift 2 ;;
      -l|--list) LIST_DEVICES=1; shift ;;
      -r|--release) MODE="release"; shift ;;
      -b|--build-only) BUILD_ONLY=1; shift ;;
      --skip-pub) SKIP_PUB=1; shift ;;
      -h|--help)
        cat <<'EOF'
Flutter run options: -d DEVICE, -l list, -r release, -b build-only, --skip-pub
EOF
        return 0
        ;;
      *) RUN_ARGS+=("$1"); shift ;;
    esac
  done

  if ! command -v flutter >/dev/null 2>&1; then
    echo "Error: flutter not in PATH."
    return 1
  fi

  if [[ "$LIST_DEVICES" -eq 1 ]]; then
    flutter devices
    flutter emulators 2>/dev/null || true
    return 0
  fi

  [[ "$SKIP_PUB" -eq 0 ]] && flutter pub get

  local SO="$ROOT/packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so"
  if [[ ("$DEVICE" == "linux" || -z "$DEVICE") && ! -f "$SO" ]]; then
    echo "==> Native .so missing; run: ./wallet.sh build-docker"
  fi

  if [[ -z "$DEVICE" ]]; then
    DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
try:
    for d in json.load(sys.stdin):
        if not d.get('ephemeral'):
            print(d['id']); break
except Exception:
    pass
" 2>/dev/null || true)"
    [[ -z "$DEVICE" ]] && { echo "Error: no device. Use -d linux"; return 1; }
    echo "==> Auto-selected device: $DEVICE"
  fi

  local FLUTTER_BUILD=(flutter build) FLUTTER_RUN=(flutter run -d "$DEVICE" --no-pub)
  [[ "$MODE" == "release" ]] && FLUTTER_BUILD+=(--release) && FLUTTER_RUN+=(--release)

  if [[ "$BUILD_ONLY" -eq 1 ]]; then
    case "$DEVICE" in
      linux) "${FLUTTER_BUILD[@]}" linux ;;
      chrome|web) "${FLUTTER_BUILD[@]}" web ;;
      android|emulator-*) "${FLUTTER_BUILD[@]}" apk ;;
      ios) "${FLUTTER_BUILD[@]}" ios --no-codesign ;;
      macos) "${FLUTTER_BUILD[@]}" macos ;;
      windows) "${FLUTTER_BUILD[@]}" windows ;;
    esac
    return 0
  fi

  echo "==> Launching on $DEVICE (Ctrl+C to stop)"
  exec "${FLUTTER_RUN[@]}" "${RUN_ARGS[@]}"
}
