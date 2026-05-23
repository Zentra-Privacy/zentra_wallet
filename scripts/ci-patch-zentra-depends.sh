#!/usr/bin/env bash
# Apply wallet-repo patches to pinned Zentra v0.1.0 depends (CI / local engine builds).
# Usage: ./scripts/ci-patch-zentra-depends.sh [zentra_root]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZENTRA="${1:-$ROOT/third_party/zentra}"
PATCH_DIR="$ROOT/scripts/patches/zentra-depends"
MINGW_HOST="x86_64-w64-mingw32"
ZMQ_MK="$ZENTRA/contrib/depends/packages/zeromq.mk"

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
  patch -p0 -d "$ZENTRA" < "$file" || return 1
}

# Remove broken patchset v2 (pthread cv-impl on MinGW — mutex_t has no get_mutex()).
if [[ -f "$ZMQ_MK" ]]; then
  sed -i '/config_opts_mingw32=--with-cv-impl=pthread/d' "$ZMQ_MK"
fi

_zeromq_mingw_sed_fix() {
  sed -i 's/^$(package)_version=4.3.4$/$(package)_version=4.3.1/' "$ZMQ_MK"
  sed -i 's/^$(package)_sha256_hash=c593001a89f5a85dd2ddf564805deb860e02471171b3f204944857336295c3e5$/$(package)_sha256_hash=bcbabe1e2c7d0eec4ed612e10b94b112dd5f06fcefa994a0c79a45d835cd21eb/' "$ZMQ_MK"
  sed -i '/config_opts_mingw32=--with-cv-impl=pthread/d' "$ZMQ_MK"
  if ! grep -q 'cxxflags_mingw32' "$ZMQ_MK"; then
    sed -i '/$(package)_cxxflags=-std=c++11/a\  $(package)_cxxflags_mingw32+=-O1' "$ZMQ_MK"
  fi
}

_fix_zeromq_mingw_mk() {
  # Idempotent: downgrade 4.3.4 → 4.3.1 + MinGW -O1 (Monero #8409).
  [[ -f "$ZMQ_MK" ]] || return 0
  if grep -q '$(package)_version=4.3.1' "$ZMQ_MK" \
    && grep -q 'cxxflags_mingw32+=-O1' "$ZMQ_MK" \
    && ! grep -q 'config_opts_mingw32=--with-cv-impl=pthread' "$ZMQ_MK"; then
    echo "==> zeromq MinGW fix already present (4.3.1 + -O1)"
    return 0
  fi
  _apply_patch zeromq-mingw.patch || true
  _zeromq_mingw_sed_fix
}

_invalidate_mingw_zeromq_cache() {
  echo "==> Invalidating cached MinGW zeromq builds"
  rm -rf "$ZENTRA/contrib/depends/work/build/${MINGW_HOST}/zeromq" \
    "$ZENTRA/contrib/depends/work/staging/${MINGW_HOST}/zeromq" 2>/dev/null || true
  if [[ -d "$ZENTRA/contrib/depends/built/${MINGW_HOST}/zeromq" ]]; then
    find "$ZENTRA/contrib/depends/built/${MINGW_HOST}/zeromq" -type f -name 'zeromq*.tar.gz*' -delete 2>/dev/null || true
  fi
}

_fix_zeromq_mingw_mk

grep -q '$(package)_version=4.3.1' "$ZMQ_MK" \
  || { echo "::error::zeromq must be 4.3.1 for MinGW cross-build"; exit 1; }
grep -q 'cxxflags_mingw32+=-O1' "$ZMQ_MK" \
  || { echo "::error::zeromq mingw -O1 cxxflags missing"; exit 1; }
grep -q 'config_opts_mingw32=--with-cv-impl=pthread' "$ZMQ_MK" \
  && { echo "::error::remove pthread cv-impl from zeromq.mk"; exit 1; }

_invalidate_mingw_zeromq_cache

echo "==> Zentra depends patches applied (PATCHSET_VERSION=$(cat "$PATCH_DIR/PATCHSET_VERSION" 2>/dev/null || echo 0))"
