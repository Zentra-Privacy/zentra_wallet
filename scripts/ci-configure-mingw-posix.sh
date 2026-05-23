#!/usr/bin/env bash
# Use MinGW posix threading (required for protobuf + C++11 std::mutex on cross-build).
# Ubuntu default is often win32, which breaks depends protobuf 3.6.1.
set -euo pipefail

if ! command -v update-alternatives >/dev/null 2>&1; then
  echo "Warning: update-alternatives not found; ensure MinGW posix gcc/g++ are default"
  exit 0
fi

_set_alt() {
  local name="$1"
  local path="$2"
  if [[ -x "$path" ]]; then
    update-alternatives --set "$name" "$path"
    echo "==> $name -> $path"
  else
    echo "Warning: $path not found (skip $name)"
  fi
}

_set_alt x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
_set_alt x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# Verify C++11 mutex works with selected compiler.
if ! x86_64-w64-mingw32-g++ -x c++ -std=c++11 - -o /tmp/zw-mingw-mutex-test.exe <<<'#include <mutex>
int main() { std::mutex m; return 0; }' 2>/dev/null; then
  echo "::error::MinGW posix g++ cannot compile std::mutex test (protobuf will fail)"
  x86_64-w64-mingw32-g++ -x c++ -std=c++11 - -o /tmp/zw-mingw-mutex-test.exe <<<'#include <mutex>
int main() { std::mutex m; return 0; }' || true
  exit 1
fi
rm -f /tmp/zw-mingw-mutex-test.exe

echo "==> MinGW posix toolchain OK"
