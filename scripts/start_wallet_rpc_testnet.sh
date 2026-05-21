#!/usr/bin/env bash
# Start zentra-wallet-rpc for Flutter wallet (testnet, dev login disabled).
set -euo pipefail

ZENTRA_ROOT="${ZENTRA_ROOT:-$(cd "$(dirname "$0")/../../zentra" && pwd)}"
BIN="${ZENTRA_ROOT}/build/release/bin/zentra-wallet-rpc"

if [[ ! -x "$BIN" ]]; then
  echo "Build zentra first: cd $ZENTRA_ROOT && scripts/build.sh"
  exit 1
fi

exec "$BIN" --testnet \
  --daemon-address "${ZENTRA_DAEMON:-127.0.0.1:29081}" \
  --trusted-daemon \
  --rpc-bind-ip 127.0.0.1 \
  --rpc-bind-port "${ZENTRA_WALLET_RPC_PORT:-8082}" \
  --disable-rpc-login \
  "$@"
