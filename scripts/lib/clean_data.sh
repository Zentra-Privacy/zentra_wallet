#!/usr/bin/env bash
# Clean local wallet test data. Usage: clean_wallet_data [--yes] [--force]
clean_wallet_data() {
  local ROOT="${WALLET_ROOT:?}"
  local LINUX_APP_ID="${ZENTRA_APP_ID:-com.example.zentra_wallet}"
  local APPLE_APP_ID="${ZENTRA_APPLE_APP_ID:-com.example.zentraWallet}"
  local DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$LINUX_APP_ID"
  # path_provider (2.0.12+): .../Application Support/<bundle-id>/zentra_wallets
  local MAC_WALLETS="$HOME/Library/Application Support/$APPLE_APP_ID/zentra_wallets"
  local MAC_CONTAINER_WALLETS="$HOME/Library/Containers/$APPLE_APP_ID/Data/Library/Application Support/$APPLE_APP_ID/zentra_wallets"
  local DRY_RUN=1 FORCE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) DRY_RUN=0; shift ;;
      --force|-f) FORCE=1; shift ;;
      *) echo "Unknown: $1"; return 1 ;;
    esac
  done

  local -a _targets=()
  for p in "$DATA_DIR" "$MAC_WALLETS" "$MAC_CONTAINER_WALLETS"; do
    [[ -e "$p" ]] && _targets+=("$p")
  done

  if [[ ${#_targets[@]} -eq 0 ]]; then
    echo "No wallet data found (Linux: $DATA_DIR; macOS: $MAC_WALLETS or $MAC_CONTAINER_WALLETS)"
    return 0
  fi

  echo "Paths:"
  printf '  %s\n' "${_targets[@]}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry-run. Use: ./wallet.sh clean-data --yes"
    return 0
  fi

  if [[ "$FORCE" -ne 1 ]]; then
    read -r -p "Type 'yes' to delete local wallet data: " c
    [[ "$c" == "yes" ]] || { echo "Aborted."; return 1; }
  fi

  rm -rf "${_targets[@]}"
  command -v secret-tool >/dev/null 2>&1 && secret-tool clear-by-attribute "xdg:schema" "$LINUX_APP_ID" 2>/dev/null || true
  echo "==> Local wallet data removed."
}
