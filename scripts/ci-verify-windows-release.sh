#!/usr/bin/env bash
# Verify Flutter Windows Release folder contains wallet DLL (and MinGW runtimes if bundled).
set -euo pipefail

REL="${1:-build/windows/x64/runner/Release}"
main="$REL/libzentra_wallet_ffi.dll"

[[ -f "$main" ]] || {
  echo "::error::Missing $main — wallet engine not packaged in Windows build"
  exit 1
}
echo "  OK $(basename "$main")"

for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
  if [[ -f "$REL/$dll" ]]; then
    echo "  OK $dll"
  else
    echo "::warning::$dll not in Release (may be statically linked or load may fail on user PCs)"
  fi
done

echo "==> Windows Release native libs OK"
