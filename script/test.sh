#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ "$(uname -s)" == Linux ]]; then
  TOOLS="${PMIND_TOOLS_DIR:-/workspace/.pmind-native-tools}"
  if [[ -x "$TOOLS/swift-6.1.3-RELEASE-ubuntu24.04/usr/bin/swift" ]]; then
    export PATH="$TOOLS/swift-6.1.3-RELEASE-ubuntu24.04/usr/bin:$PATH"
  fi
  export CLANG_MODULE_CACHE_PATH="$TOOLS/clang-cache"
  export XDG_CACHE_HOME="$TOOLS/cache"
  exec swift test --scratch-path "$TOOLS/build" --cache-path "$TOOLS/cache" \
    --config-path "$TOOLS/config" --security-path "$TOOLS/security" -j 4 "$@"
else
  exec swift test "$@"
fi
