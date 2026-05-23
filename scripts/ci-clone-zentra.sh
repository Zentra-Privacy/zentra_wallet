#!/usr/bin/env bash
# Clone Zentra core at a pinned tag (default v0.1.0) for native engine builds.
# Usage: ./scripts/ci-clone-zentra.sh [dest_dir]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
DEST="${1:-$ROOT/third_party/zentra}"
REPO="${ZENTRA_REPO:-https://github.com/Zentra-Privacy/zentra.git}"
REF="${ZENTRA_REF:-v0.1.0}"

if [[ -d "$DEST/.git" ]]; then
  echo "==> Updating Zentra in $DEST @ $REF"
  git -C "$DEST" fetch --depth 1 origin "refs/tags/$REF:refs/tags/$REF" 2>/dev/null \
    || git -C "$DEST" fetch --depth 1 origin "$REF"
  git -C "$DEST" checkout -f "$REF"
  git -C "$DEST" submodule update --init --recursive --depth 1
else
  if [[ -d "$DEST/contrib/depends" ]]; then
    echo "::error::Refusing to remove $DEST: contrib/depends is present (CI must clone Zentra before cache restore)"
    exit 1
  fi
  echo "==> Cloning Zentra $REF → $DEST"
  rm -rf "$DEST"
  git clone --depth 1 --branch "$REF" --recurse-submodules "$REPO" "$DEST"
fi

[[ -f "$DEST/src/wallet/api/wallet2_api.h" ]] || {
  echo "::error::Zentra wallet API missing after checkout $REF"
  exit 1
}

echo "zentra_tag=$REF" > "$ROOT/build/zentra-checkout.env"
echo "zentra_path=$DEST" >> "$ROOT/build/zentra-checkout.env"
echo "zentra_commit=$(git -C "$DEST" rev-parse HEAD)" >> "$ROOT/build/zentra-checkout.env"
cat "$ROOT/build/zentra-checkout.env"
