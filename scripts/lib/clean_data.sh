#!/usr/bin/env bash
# Clean local wallet test data. Usage: clean_wallet_data [--yes] [--force]
clean_wallet_data() {
  local ROOT="${WALLET_ROOT:?}"
  local APP_ID="${ZENTRA_APP_ID:-com.example.zentra_wallet}"
  local DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APP_ID"
  local DRY_RUN=1 FORCE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) DRY_RUN=0; shift ;;
      --force|-f) FORCE=1; shift ;;
      *) echo "Unknown: $1"; return 1 ;;
    esac
  done

  local -a _targets=()
  for p in "$DATA_DIR"; do
    [[ -e "$p" ]] && _targets+=("$p")
  done

  if [[ ${#_targets[@]} -eq 0 ]]; then
    echo "No data at $DATA_DIR"
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

  rm -rf "$DATA_DIR"
  command -v secret-tool >/dev/null 2>&1 && secret-tool clear-by-attribute "xdg:schema" "$APP_ID" 2>/dev/null || true
  echo "==> Local wallet data removed."
}
