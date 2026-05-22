#!/usr/bin/env bash
set -euo pipefail

WALLET_ROOT="${WALLET_ROOT:-/wallet}"
ZENTRA_ROOT="${ZENTRA_ROOT:-/zentra}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

_git_safe() {
  git config --global --add safe.directory "$1" 2>/dev/null || true
}
_git_safe "$ZENTRA_ROOT"
_git_safe "$WALLET_ROOT"

if [[ -d "$ZENTRA_ROOT/.git" ]]; then
  echo "==> Zentra submodules"
  (cd "$ZENTRA_ROOT" && git submodule update --init --recursive)
fi

ZENTRA_BUILD="${ZENTRA_BUILD:-$WALLET_ROOT/build/docker/zentra-release}"
FFI_BUILD="${FFI_BUILD:-$WALLET_ROOT/build/docker/native_ffi}"
mkdir -p "$ZENTRA_BUILD" "$FFI_BUILD"

echo "==> Docker Zentra build: $ZENTRA_BUILD"
echo "==> Docker FFI build:   $FFI_BUILD"

export WALLET_ROOT JOBS FFI_BUILD
# shellcheck source=/dev/null
source "$WALLET_ROOT/scripts/lib/native_build.sh"
native_build_host "$ZENTRA_ROOT" "$ZENTRA_BUILD"
