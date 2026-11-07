#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/lib/app_lifecycle.sh"
MODE="${1:-run}"
case "$MODE" in
  run|--build-only|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
if [[ "$(uname -s)" != Darwin ]]; then
  echo "pmind 的原生界面需要 macOS 14+ 和 Xcode 16+。Linux 可运行 swift test 验证内核。" >&2
  exit 1
fi
swift build --product pmind
BUILD_DIR="$(swift build --show-bin-path)"
APP_BUNDLE="$ROOT_DIR/dist/pmind.app"
mkdir -p "$ROOT_DIR/dist"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/dist/.pmind-build.XXXXXX")"
trap 'cleanup_app_staging "$STAGING_DIR" "$APP_BUNDLE"' EXIT
STAGED_BUNDLE="$STAGING_DIR/pmind.app"
mkdir -p "$STAGED_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/pmind" "$STAGED_BUNDLE/Contents/MacOS/pmind"
cp "$ROOT_DIR/Resources/Info.plist" "$STAGED_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(cat VERSION)" "$STAGED_BUNDLE/Contents/Info.plist"
chmod +x "$STAGED_BUNDLE/Contents/MacOS/pmind"
/usr/bin/plutil -lint "$STAGED_BUNDLE/Contents/Info.plist"
# Ad-hoc signing is for this local development build; distribution requires Developer ID.
/usr/bin/codesign --force --sign - "$STAGED_BUNDLE"
/usr/bin/codesign --verify --strict "$STAGED_BUNDLE"
install_app_bundle "$STAGED_BUNDLE" "$APP_BUNDLE" "$MODE"
case "$MODE" in
  --build-only) echo "$APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/pmind" ;;
  --logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "pmind"'
    ;;
  --telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "app.pmind.mac"'
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    for attempt in {1..20}; do
      if pgrep -x pmind >/dev/null; then echo "pmind process started (UI behavior still needs verification)"; exit 0; fi
      sleep 0.25
    done
    echo "pmind did not remain running" >&2; exit 1
    ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
