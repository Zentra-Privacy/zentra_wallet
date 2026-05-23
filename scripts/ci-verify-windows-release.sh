#!/usr/bin/env bash
# Verify Flutter Windows Release folder contains wallet DLL and MinGW runtimes.
set -euo pipefail

REL="${1:-build/windows/x64/runner/Release}"
main="$REL/libzentra_wallet_ffi.dll"

[[ -f "$main" ]] || {
  echo "::error::Missing $main — wallet engine not packaged in Windows build"
  exit 1
}
echo "  OK $(basename "$main")"

for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
  if [[ ! -f "$REL/$dll" ]]; then
    echo "::error::Missing $REL/$dll — MinGW runtime required beside zentra_wallet.exe"
    echo "       Rebuild engine (native_build_mingw) and re-run ci-apply-native-libs before flutter build windows."
    exit 1
  fi
  echo "  OK $dll"
done

echo "==> Windows Release native libs OK"
