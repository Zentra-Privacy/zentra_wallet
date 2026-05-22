#!/usr/bin/env bash
# Zentra Wallet — single entry point (menu + all commands).
#
#   ./wallet.sh              interactive menu
#   ./wallet.sh build-docker
#   ./wallet.sh run
#   ./wallet.sh help
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export WALLET_ROOT="$ROOT"

LIB="$ROOT/scripts/lib"
# shellcheck source=lib/native_build.sh
source "$LIB/native_build.sh"
# shellcheck source=lib/docker_native.sh
source "$LIB/docker_native.sh"
# shellcheck source=lib/install_docker.sh
source "$LIB/install_docker.sh"
# shellcheck source=lib/flutter_run.sh
source "$LIB/flutter_run.sh"
# shellcheck source=lib/clean_data.sh
source "$LIB/clean_data.sh"

SO_PATH="$ROOT/packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so"
DOCKER_IMAGE="${NATIVE_IMAGE:-zentra-wallet-native-build:ubuntu22}"
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
  C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_CYAN='\033[36m'; C_RED='\033[31m'
else
  C_RESET= C_BOLD= C_DIM= C_GREEN= C_YELLOW= C_CYAN= C_RED=
fi

_hr() { printf '%s\n' "${C_DIM}────────────────────────────────────────${C_RESET}"; }
_ok() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
_warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
_err() { printf '  %sx%s %s\n' "$C_RED" "$C_RESET" "$*"; }

_resolve_zentra() {
  if [[ -n "${ZENTRA_ROOT:-}" && -d "${ZENTRA_ROOT}/src/wallet/api" ]]; then
    echo "$(cd "$ZENTRA_ROOT" && pwd)"; return
  fi
  if [[ -d "$ROOT/../zentra/src/wallet/api" ]]; then
    echo "$(cd "$ROOT/../zentra" && pwd)"; return
  fi
  if [[ -d "$ROOT/third_party/zentra/src/wallet/api" ]]; then
    echo "$(cd "$ROOT/third_party/zentra" && pwd)"; return
  fi
  echo ""
}

cmd_status() {
  _hr
  printf '%s%s Zentra Wallet — status%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  _hr
  local z; z="$(_resolve_zentra)"
  [[ -n "$z" ]] && _ok "Zentra: $z" || _warn "Zentra: not found"
  [[ -f "$SO_PATH" ]] && _ok "Native lib: $(ls -lh "$SO_PATH" | awk '{print $5, $9}')" || _warn "Native lib: missing → ./wallet.sh build-docker"
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      _ok "Docker: OK"
    elif sudo docker info >/dev/null 2>&1; then
      _warn "Docker: needs sudo (run: newgrp docker)"
    else
      _err "Docker: daemon down"
    fi
  else
    _warn "Docker: not installed → ./wallet.sh install-docker"
  fi
  command -v flutter >/dev/null 2>&1 && _ok "Flutter: $(flutter --version 2>/dev/null | head -1)" || _warn "Flutter: not in PATH"
  _hr
}

cmd_install_docker() { _hr; install_docker_engine; }

cmd_build_docker() {
  local z="${1:-$(_resolve_zentra)}"
  docker_native_build "${z:-}"
}

cmd_build_host() {
  local z="${1:-$(_resolve_zentra)}"
  [[ -z "$z" ]] && { _err "Zentra source not found"; return 1; }
  native_build_host "$z"
}

cmd_rebuild_image() { REBUILD_IMAGE=1 cmd_build_docker "${1:-}"; }

cmd_run_app() {
  [[ ! -f "$SO_PATH" ]] && { _warn "Building native lib first…"; cmd_build_docker || return 1; }
  flutter_wallet_run -d linux "$@"
}

cmd_devices() { flutter_wallet_run -l; }

cmd_clean_docker_cache() {
  read -r -p "Remove build/docker/? Type yes: " a
  [[ "$a" == "yes" ]] && rm -rf "$ROOT/build/docker" && _ok "Removed build/docker/" || echo "Cancelled"
}

cmd_clean_docker() {
  _hr
  printf '%sDocker cleanup%s\n' "$C_BOLD" "$C_RESET"
  cat <<'EOF'

  [a] Containers only (wallet image + stopped prune)
  [b] Containers + remove Docker image (rebuild on next build-docker)
  [c] Everything: containers + image + build/docker/ cache

EOF
  read -r -p "  Choose [a/b/c] or Enter to cancel: " choice
  case "$choice" in
    a|A) docker_cleanup_wallet ;;
    b|B) docker_cleanup_wallet --image ;;
    c|C) docker_cleanup_wallet --image --cache ;;
    *) echo "  Cancelled." ;;
  esac
}

cmd_clean_data() { clean_wallet_data "$@"; }

cmd_full_flow() { cmd_build_docker; echo; cmd_run_app; }

_ask_zentra_path() {
  local c; c="$(_resolve_zentra)"
  if [[ -n "$c" ]]; then
    printf '\n  Zentra: %s\n' "$c"
    read -r -p "  Enter=new path, Enter=keep: " p
    [[ -z "$p" ]] && { echo "$c"; return; }
    [[ -d "$p/src/wallet/api" ]] && { echo "$(cd "$p" && pwd)"; return; }
    return 1
  fi
  read -r -p "  Zentra path: " p
  [[ -d "$p/src/wallet/api" ]] && echo "$(cd "$p" && pwd)"
}

_show_menu() {
  clear 2>/dev/null || true
  _hr
  printf '%s%s  Zentra Wallet%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  [[ -f "$SO_PATH" ]] && printf '  %sNative lib: ready%s\n' "$C_GREEN" "$C_RESET" || printf '  %sNative lib: not built%s\n' "$C_YELLOW" "$C_RESET"
  _hr
  cat <<'MENU'
  [1]  Install Docker
  [2]  Build native library (Docker / Ubuntu 22)  ← recommended
  [3]  Build native library (this PC, no Docker)
  [4]  Run app (Linux)
  [5]  Build + Run
  [6]  Flutter devices
  [7]  Rebuild Docker image
  [8]  Clean Docker cache (build/docker/)
  [9]  Status
  [10] Clean wallet test data (local)
  [11] Remove Docker containers / image (wallet)
  [0]  Exit
MENU
  _hr
}

_menu_loop() {
  while true; do
    _show_menu
    read -r -p "  Choose [0-11]: " c
    printf '\n'
    case "$c" in
      1) cmd_install_docker; read -r -p "Enter…" _ ;;
      2) p="$(_ask_zentra_path 2>/dev/null || true)"; cmd_build_docker "${p:-}" || true; read -r -p "Enter…" _ ;;
      3) p="$(_ask_zentra_path 2>/dev/null || true)"; [[ -n "${p:-}" ]] && cmd_build_host "$p" || true; read -r -p "Enter…" _ ;;
      4) cmd_run_app || true ;;
      5) cmd_full_flow || true; read -r -p "Enter…" _ ;;
      6) cmd_devices; read -r -p "Enter…" _ ;;
      7) p="$(_ask_zentra_path 2>/dev/null || true)"; cmd_rebuild_image "${p:-}" || true; read -r -p "Enter…" _ ;;
      8) cmd_clean_docker_cache; read -r -p "Enter…" _ ;;
      9) cmd_status; read -r -p "Enter…" _ ;;
      10) cmd_clean_data; read -r -p "Enter…" _ ;;
      11) cmd_clean_docker; read -r -p "Enter…" _ ;;
      0|q) exit 0 ;;
      *) _err "Invalid"; sleep 1 ;;
    esac
  done
}

case "${1:-}" in
  ""|menu) _menu_loop ;;
  status) cmd_status ;;
  install-docker) cmd_install_docker ;;
  build-docker|build) shift; cmd_build_docker "${1:-}" ;;
  build-host) shift; cmd_build_host "${1:-}" ;;
  rebuild-image) shift; cmd_rebuild_image "${1:-}" ;;
  run|start) shift; cmd_run_app "$@" ;;
  devices) cmd_devices ;;
  clean-docker) cmd_clean_docker_cache ;;
  clean-docker-containers|docker-clean) shift; docker_cleanup_wallet "$@" ;;
  clean-data) shift; cmd_clean_data "$@" ;;
  full|all) cmd_full_flow ;;
  help|-h|--help)
    cat <<EOF
Zentra Wallet — ./wallet.sh

  ./wallet.sh                 Menu
  ./wallet.sh status
  ./wallet.sh install-docker
  ./wallet.sh build-docker    Native .so (Ubuntu 22 Docker)
  ./wallet.sh build-host      Native .so (host)
  ./wallet.sh run             Linux app
  ./wallet.sh full            build-docker + run
  ./wallet.sh clean-data           Reset local wallet files
  ./wallet.sh clean-docker         Remove build/docker/ folder only
  ./wallet.sh docker-clean         Remove containers (+ menu: image, cache)
  ./wallet.sh docker-clean --image --cache --yes   Full Docker reset
EOF
    ;;
  *) _err "Unknown: $1"; echo "  ./wallet.sh help"; exit 1 ;;
esac
