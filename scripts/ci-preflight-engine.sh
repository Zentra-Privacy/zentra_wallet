#!/usr/bin/env bash
# Fail fast before hours-long Zentra depends builds (Phase 1 engine-ubuntu).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZENTRA="${1:-$ROOT/third_party/zentra}"
fail() { echo "::error::$1"; exit 1; }

echo "==> Engine build preflight"

for cmd in git cmake make patch python3 curl; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"
done

if ! ldconfig -p 2>/dev/null | grep -q 'libtinfo.so.5'; then
  fail "libtinfo5 missing (required for Zentra Android depends NDK). Run: sudo apt install libtinfo5"
fi

if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  fail "MinGW gcc missing. Run: sudo ./scripts/ci-install-linux-deps.sh all"
fi
if ! x86_64-w64-mingw32-g++ -dumpmachine >/dev/null 2>&1; then
  fail "x86_64-w64-mingw32-g++ cannot run. Install: g++-mingw-w64-x86-64 gcc-mingw-w64-x86-64 mingw-w64"
fi

if [[ -x "$ROOT/scripts/ci-configure-mingw-posix.sh" ]]; then
  bash "$ROOT/scripts/ci-configure-mingw-posix.sh"
fi

# Quick MinGW smoke compile (catches broken toolchain before libiconv/zeromq).
_mingw_ok=0
if x86_64-w64-mingw32-gcc -x c - -o /tmp/zw-mingw-test.exe <<<'int main(){return 0;}' 2>/dev/null; then
  _mingw_ok=1
  rm -f /tmp/zw-mingw-test.exe
fi
[[ "$_mingw_ok" == "1" ]] || fail "MinGW test compile failed (x86_64-w64-mingw32-gcc cannot create executables)"

[[ -f "$ZENTRA/src/wallet/api/wallet2_api.h" ]] || fail "Zentra not checked out: $ZENTRA"

if [[ -f "$ZENTRA/contrib/depends/packages/zeromq.mk" ]]; then
  grep -q '$(package)_version=4.3.1' "$ZENTRA/contrib/depends/packages/zeromq.mk" \
    || fail "zeromq must be 4.3.1 for MinGW. Run: ./scripts/ci-patch-zentra-depends.sh"
  grep -q 'cxxflags_mingw32+=-O1' "$ZENTRA/contrib/depends/packages/zeromq.mk" \
    || fail "zeromq MinGW -O1 missing. Run: ./scripts/ci-patch-zentra-depends.sh"
  grep -q 'config_opts_mingw32=--with-cv-impl=pthread' "$ZENTRA/contrib/depends/packages/zeromq.mk" \
    && fail "zeromq pthread cv-impl breaks MinGW (remove via ci-patch-zentra-depends.sh)"
fi

echo "==> Preflight OK (toolchain, libtinfo5, MinGW, Zentra, depends patches)"
