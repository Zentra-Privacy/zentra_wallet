#!/usr/bin/env bash
# Apply wallet-repo patches to pinned Zentra v0.1.0 depends (CI / local engine builds).
# Usage: ./scripts/ci-patch-zentra-depends.sh [zentra_root]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZENTRA="${1:-$ROOT/third_party/zentra}"
PATCH_DIR="$ROOT/scripts/patches/zentra-depends"
MINGW_HOST="x86_64-w64-mingw32"

[[ -d "$ZENTRA/contrib/depends" ]] || {
  echo "::error::Zentra depends tree not found at $ZENTRA"
  exit 1
}

_apply_patch() {
  local name="$1"
  local file="$PATCH_DIR/$name"
  [[ -f "$file" ]] || return 0
  echo "==> Patching Zentra depends: $name"
  if patch -p0 -R --dry-run -d "$ZENTRA" < "$file" >/dev/null 2>&1; then
    echo "    (already applied)"
    return 0
  fi
  patch -p0 -d "$ZENTRA" < "$file"
}

_invalidate_mingw_zeromq_cache() {
  echo "==> Invalidating cached MinGW zeromq (patch may change build recipe)"
  rm -rf "$ZENTRA/contrib/depends/work/build/${MINGW_HOST}/zeromq" \
    "$ZENTRA/contrib/depends/work/staging/${MINGW_HOST}/zeromq" 2>/dev/null || true
  if [[ -d "$ZENTRA/contrib/depends/built/${MINGW_HOST}/zeromq" ]]; then
    find "$ZENTRA/contrib/depends/built/${MINGW_HOST}/zeromq" -type f -name 'zeromq*.tar.gz*' -delete 2>/dev/null || true
  fi
}

_apply_patch zeromq-mingw.patch

grep -q 'config_opts_mingw32=--with-cv-impl=pthread' "$ZENTRA/contrib/depends/packages/zeromq.mk" \
  || { echo "::error::zeromq-mingw.patch did not apply correctly"; exit 1; }

_invalidate_mingw_zeromq_cache

echo "==> Zentra depends patches applied (PATCHSET_VERSION=$(cat "$PATCH_DIR/PATCHSET_VERSION" 2>/dev/null || echo 0))"
