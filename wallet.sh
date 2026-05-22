#!/usr/bin/env bash
# Shortcut — same as ./scripts/wallet.sh
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/scripts/wallet.sh" "$@"
