#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" != Linux ]]; then
  echo "macOS 使用 Xcode 16+ 提供的 Swift，无需此脚本。"
  exit 0
fi
TOOLS="${PMIND_TOOLS_DIR:-/workspace/.pmind-native-tools}"
SWIFT="$TOOLS/swift-6.1.3-RELEASE-ubuntu24.04/usr/bin/swift"
mkdir -p "$TOOLS"
if [[ ! -x "$SWIFT" ]]; then
  BASE=https://download.swift.org/swift-6.1.3-release/ubuntu2404/swift-6.1.3-RELEASE
  curl -fL --max-time 900 "$BASE/swift-6.1.3-RELEASE-ubuntu24.04.tar.gz" -o "$TOOLS/swift.tar.gz"
  curl -fL --max-time 60 "$BASE/swift-6.1.3-RELEASE-ubuntu24.04.tar.gz.sig" -o "$TOOLS/swift.tar.gz.sig"
  curl -fL --max-time 60 https://raw.githubusercontent.com/swiftlang/swift-org-website/main/keys/all-keys.asc -o "$TOOLS/swift-keys.asc"
  mkdir -m 700 -p "$TOOLS/gnupg"
  gpg --homedir "$TOOLS/gnupg" --batch --import "$TOOLS/swift-keys.asc"
  gpg --homedir "$TOOLS/gnupg" --batch --verify "$TOOLS/swift.tar.gz.sig" "$TOOLS/swift.tar.gz"
  tar -xzf "$TOOLS/swift.tar.gz" -C "$TOOLS"
fi
"$SWIFT" --version
echo "Linux 仅支持内核验证。运行 ./script/test.sh；GUI 仍需要 macOS。"
