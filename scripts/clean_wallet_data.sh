#!/usr/bin/env bash
# Reset Zentra Wallet local data (testing only).
#
# Removes:
#   - Embedded wallet files (zentra_wallets/)
#   - SharedPreferences (onboarding, node, network, restore height)
#   - Linux: GNOME Keyring / libsecret entry for wallet password (if present)
#
# Does NOT remove: Flutter build artifacts, native .so, or source code.
#
# Usage:
#   ./scripts/clean_wallet_data.sh              # dry-run (show only, no delete)
#   ./scripts/clean_wallet_data.sh --yes        # delete after confirmation prompt
#   ./scripts/clean_wallet_data.sh --yes -f     # delete without prompt (CI/automation)
#
# IMPORTANT: Close the wallet app before running. Mainnet wallets will be gone
# from this device unless you have your seed phrase backup.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="${ZENTRA_APP_ID:-com.example.zentra_wallet}"

# Linux (path_provider applicationSupportDirectory)
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APP_ID"
WALLETS_DIR="$DATA_DIR/zentra_wallets"
PREFS_FILE="$DATA_DIR/shared_preferences.json"

DRY_RUN=1
FORCE=0

usage() {
  cat <<EOF
Zentra Wallet — clean local user data (testing)

Options:
  --yes, -y     Actually delete files (default is dry-run only)
  --force, -f   Skip confirmation prompt (use with --yes)
  -h, --help    This help

Environment:
  ZENTRA_APP_ID   App data folder name (default: com.example.zentra_wallet)
  XDG_DATA_HOME   Linux data root (default: ~/.local/share)

Examples:
  ./scripts/clean_wallet_data.sh
  ./scripts/clean_wallet_data.sh --yes
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) DRY_RUN=0; shift ;;
    --force|-f) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

echo "==> Zentra Wallet data cleaner"
echo "    Project: $ROOT"
echo "    App ID:  $APP_ID"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> DRY-RUN mode (nothing will be deleted). Use --yes to remove data."
  echo ""
fi

_targets=()
_add_target() {
  local path="$1"
  local desc="$2"
  if [[ -e "$path" ]]; then
    _targets+=("$path|$desc")
  fi
}

_add_target "$DATA_DIR" "App data directory"
_add_target "$WALLETS_DIR" "Wallet files (keys, cache)"
_add_target "$PREFS_FILE" "Settings (network, node, onboarded flag)"

if [[ ${#_targets[@]} -eq 0 ]]; then
  echo "No Zentra Wallet data found under:"
  echo "  $DATA_DIR"
  echo ""
  echo "Nothing to clean (already empty or app never run on this machine)."
  exit 0
fi

echo "Paths to clean:"
for entry in "${_targets[@]}"; do
  path="${entry%%|*}"
  desc="${entry#*|}"
  if [[ -d "$path" ]]; then
    size="$(du -sh "$path" 2>/dev/null | cut -f1 || echo '?')"
    echo "  [dir]  $path  ($desc, ~$size)"
    if [[ -d "$WALLETS_DIR" && "$path" == "$WALLETS_DIR" ]]; then
      ls -la "$WALLETS_DIR" 2>/dev/null | sed 's/^/         /' || true
    fi
  else
    echo "  [file] $path  ($desc)"
  fi
done
echo ""

# Optional: flutter_secure_storage on Linux (libsecret)
if command -v secret-tool >/dev/null 2>&1; then
  echo "Note: Wallet password may also live in GNOME Keyring (libsecret)."
  echo "      After --yes, this script tries: secret-tool clear-by-attribute xdg:schema=$APP_ID"
  echo ""
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry-run complete. Re-run with:  ./scripts/clean_wallet_data.sh --yes"
  exit 0
fi

if [[ "$FORCE" -ne 1 ]]; then
  echo "WARNING: This permanently deletes local wallet data on this device."
  echo "         You need your 25-word seed to recover funds on mainnet."
  read -r -p "Type 'yes' to continue: " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Close running app if possible (optional hint)
if pgrep -f "zentra_wallet" >/dev/null 2>&1; then
  echo "Warning: zentra_wallet process still running. Close the app first for a clean reset."
fi

echo "==> Deleting..."
for entry in "${_targets[@]}"; do
  path="${entry%%|*}"
  # Skip deleting parent DATA_DIR twice — delete whole tree once at end
done

# Remove wallet dir and prefs first, then whole app dir if it exists
rm -rf "$WALLETS_DIR"
rm -f "$PREFS_FILE"

# Remove leftover app data dir if empty or only flutter assets remain
if [[ -d "$DATA_DIR" ]]; then
  # Keep font cache optional — remove entire app folder for full reset
  rm -rf "$DATA_DIR"
fi

if command -v secret-tool >/dev/null 2>&1; then
  secret-tool clear-by-attribute "xdg:schema" "$APP_ID" 2>/dev/null || true
  # flutter_secure_storage may use different labels; best-effort only
fi

echo "==> Done. Local Zentra Wallet data removed."
echo "    Next launch will show onboarding (create / restore wallet)."
echo "    Rebuild/run: ./scripts/build_and_run.sh -d linux"
