#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/pmind-launch-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_TMP"' EXIT
mkdir -p "$TEST_TMP/bin"
export PMIND_TEST_LOG="$TEST_TMP/events"
export PMIND_TEST_RUNNING="$TEST_TMP/running"
export PMIND_TEST_QUIT=success
export PMIND_TEST_FAIL_STAGED=""
export PMIND_TEST_FAIL_RESTORE=""

cat > "$TEST_TMP/bin/uname" <<'SH'
#!/usr/bin/env bash
echo Darwin
SH
cat > "$TEST_TMP/bin/swift" <<'SH'
#!/usr/bin/env bash
exit 17
SH
cat > "$TEST_TMP/bin/pkill" <<'SH'
#!/usr/bin/env bash
echo forced-kill >> "$PMIND_TEST_LOG"
SH
cat > "$TEST_TMP/bin/pgrep" <<'SH'
#!/usr/bin/env bash
[[ -f "$PMIND_TEST_RUNNING" ]]
SH
cat > "$TEST_TMP/bin/osascript" <<'SH'
#!/usr/bin/env bash
echo quit >> "$PMIND_TEST_LOG"
case "$PMIND_TEST_QUIT" in
  cancel) exit 1 ;;
  stuck) exit 0 ;;
  success) rm -f "$PMIND_TEST_RUNNING" ;;
esac
SH
cat > "$TEST_TMP/bin/sleep" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TEST_TMP/bin/mv" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "$PMIND_TEST_FAIL_STAGED" || "$1" == "$PMIND_TEST_FAIL_RESTORE" ]]; then exit 1; fi
exec /bin/mv "$@"
SH
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
if bash "$ROOT_DIR/script/build_and_run.sh" > "$TEST_TMP/build.log" 2>&1; then
  fail "a failed build must stop the launch script"
fi
[[ ! -s "$PMIND_TEST_LOG" ]] || fail "a failed build touched the running application"
echo "ok: build failure leaves the running app alone"

source "$ROOT_DIR/script/lib/app_lifecycle.sh"
prepare_case() {
  CASE_DIR="$TEST_TMP/$1"
  mkdir -p "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app"
  echo new > "$CASE_DIR/build/pmind.app/marker"
  echo old > "$CASE_DIR/dist/pmind.app/marker"
  : > "$PMIND_TEST_LOG"
  rm -f "$PMIND_TEST_RUNNING"
  PMIND_TEST_QUIT=success
  PMIND_TEST_FAIL_STAGED=""
  PMIND_TEST_FAIL_RESTORE=""
}
assert_preserved() {
  [[ "$(cat "$CASE_DIR/dist/pmind.app/marker")" == old ]] || fail "old app was replaced"
  [[ "$(cat "$CASE_DIR/build/pmind.app/marker")" == new ]] || fail "staged app was lost"
}

prepare_case canceled
touch "$PMIND_TEST_RUNNING"
PMIND_TEST_QUIT=cancel
if install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" run; then
  fail "canceled quit must cancel installation"
fi
assert_preserved
echo "ok: canceled quit preserves both app bundles"

prepare_case successful
touch "$PMIND_TEST_RUNNING"
install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" run
[[ ! -f "$PMIND_TEST_RUNNING" ]] || fail "app was still running during replacement"
[[ "$(cat "$CASE_DIR/dist/pmind.app/marker")" == new ]] || fail "new app was not installed"
[[ "$(cat "$CASE_DIR/build/previous.app/marker")" == old ]] || fail "old app was not staged for cleanup"
cleanup_app_staging "$CASE_DIR/build" "$CASE_DIR/dist/pmind.app"
[[ ! -e "$CASE_DIR/build" ]] || fail "successful staging was not cleaned up"
[[ "$(cat "$CASE_DIR/dist/pmind.app/marker")" == new ]] || fail "cleanup removed the installed app"
echo "ok: successful normal quit installs the prepared app"

prepare_case not_running
install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" run
[[ ! -s "$PMIND_TEST_LOG" ]] || fail "quit was sent when no app was running"
[[ "$(cat "$CASE_DIR/dist/pmind.app/marker")" == new ]] || fail "new app was not installed"
echo "ok: a stopped app requires no quit request"

prepare_case build_only
touch "$PMIND_TEST_RUNNING"
if install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" --build-only; then
  fail "build-only must not replace a running app"
fi
assert_preserved
[[ ! -s "$PMIND_TEST_LOG" ]] || fail "build-only quit a running app"
echo "ok: build-only leaves a running app untouched"

prepare_case stuck
touch "$PMIND_TEST_RUNNING"
PMIND_TEST_QUIT=stuck
if install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" run; then
  fail "an app that remains running must not be replaced"
fi
assert_preserved
echo "ok: quit timeout preserves both app bundles"

prepare_case failed_install
PMIND_TEST_FAIL_STAGED="$CASE_DIR/build/pmind.app"
if install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" run; then
  fail "a failed move must fail installation"
fi
assert_preserved
echo "ok: failed installation restores the previous app"

prepare_case failed_restore
PMIND_TEST_FAIL_STAGED="$CASE_DIR/build/pmind.app"
PMIND_TEST_FAIL_RESTORE="$CASE_DIR/build/previous.app"
if install_app_bundle "$CASE_DIR/build/pmind.app" "$CASE_DIR/dist/pmind.app" run; then
  fail "a failed restore must not report successful installation"
fi
cleanup_app_staging "$CASE_DIR/build" "$CASE_DIR/dist/pmind.app"
[[ "$(cat "$CASE_DIR/build/previous.app/marker")" == old ]] || fail "cleanup discarded the previous app"
[[ "$(cat "$CASE_DIR/build/pmind.app/marker")" == new ]] || fail "cleanup discarded the staged app"
echo "ok: an unrecoverable move preserves the previous app in staging"
