#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/pmind-release-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_TMP"' EXIT
mkdir -p "$TEST_TMP/bin"
cat > "$TEST_TMP/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PMIND_TEST_GH_LOG"
if [[ "$1" == api ]]; then
  case "$PMIND_TEST_RELEASE_STATE" in
    absent) exit 1 ;;
    draft) printf '%s\ttrue\n' "$GITHUB_SHA" ;;
    published) printf '%s\tfalse\n' "$GITHUB_SHA" ;;
    mismatch) printf '0000000000000000000000000000000000000000\ttrue\n' ;;
  esac
elif [[ "$2" == upload && "$PMIND_TEST_UPLOAD_FAIL" == true ]]; then
  exit 1
fi
SH
chmod +x "$TEST_TMP/bin/gh"
export PATH="$TEST_TMP/bin:$PATH"
export GITHUB_REPOSITORY=example/pmind
export GITHUB_SHA=1234567890123456789012345678901234567890
export GITHUB_RUN_NUMBER=12 GITHUB_RUN_ID=123
export GITHUB_REF=refs/heads/main GITHUB_EVENT_NAME=push
export PMIND_TEST_GH_LOG="$TEST_TMP/gh.log"
export PMIND_TEST_RELEASE_STATE=absent PMIND_TEST_UPLOAD_FAIL=false
export GITHUB_STEP_SUMMARY="$TEST_TMP/summary"
fail() { echo "FAIL: $*" >&2; exit 1; }
prepare_case() {
  CASE_DIR="$TEST_TMP/$1"
  mkdir -p "$CASE_DIR"
  for arch in arm64 x86_64; do
    printf 'archive-%s\n' "$arch" > "$CASE_DIR/pmind-macos-$arch.zip"
    (cd "$CASE_DIR"; sha256sum "pmind-macos-$arch.zip" > "pmind-macos-$arch.zip.sha256")
  done
  : > "$PMIND_TEST_GH_LOG"
  PMIND_TEST_RELEASE_STATE=absent
  PMIND_TEST_UPLOAD_FAIL=false
  GITHUB_REF=refs/heads/main
  GITHUB_EVENT_NAME=push
}
reject() {
  if bash "$ROOT_DIR/script/publish_release.sh" "$CASE_DIR" > "$TEST_TMP/output" 2>&1; then
    fail "publication should have been rejected"
  fi
}

prepare_case pull_request
GITHUB_EVENT_NAME=pull_request
reject
[[ ! -s "$PMIND_TEST_GH_LOG" ]] || fail "PR attempted a release API call"
echo 'ok: pull requests cannot publish'

prepare_case other_branch
GITHUB_REF=refs/heads/feature
GITHUB_EVENT_NAME=workflow_dispatch
reject
[[ ! -s "$PMIND_TEST_GH_LOG" ]] || fail "another branch attempted a release API call"
echo 'ok: manual builds on other branches cannot publish'

prepare_case missing
rm "$CASE_DIR/pmind-macos-x86_64.zip"
reject
[[ ! -s "$PMIND_TEST_GH_LOG" ]] || fail "missing assets reached the API"
echo 'ok: both architectures are required'

prepare_case corrupt
echo corrupt >> "$CASE_DIR/pmind-macos-arm64.zip"
reject
[[ ! -s "$PMIND_TEST_GH_LOG" ]] || fail "corrupt assets reached the API"
echo 'ok: checksum failures stop publication'

prepare_case new
bash "$ROOT_DIR/script/publish_release.sh" "$CASE_DIR" > "$TEST_TMP/output"
grep -q 'release create build-12-1234567.*--target 1234567890123456789012345678901234567890.*--draft --prerelease --latest=false' "$PMIND_TEST_GH_LOG" || fail 'draft must target the exact tested commit'
grep -q 'release upload .*pmind-macos-arm64.zip.*pmind-macos-x86_64.zip' "$PMIND_TEST_GH_LOG" || fail 'both archives must be uploaded'
grep -q 'release edit .*--draft=false --prerelease --latest=false' "$PMIND_TEST_GH_LOG" || fail 'complete draft was not published as a prerelease'
echo 'ok: a complete draft is published with both architectures'

prepare_case retry
PMIND_TEST_RELEASE_STATE=draft
bash "$ROOT_DIR/script/publish_release.sh" "$CASE_DIR" > "$TEST_TMP/output"
if grep -q 'release create' "$PMIND_TEST_GH_LOG"; then fail 'retry created another draft'; fi
grep -q 'release edit' "$PMIND_TEST_GH_LOG" || fail 'retry did not finish the draft'
echo 'ok: a partial draft can be retried'

prepare_case published
PMIND_TEST_RELEASE_STATE=published
bash "$ROOT_DIR/script/publish_release.sh" "$CASE_DIR" > "$TEST_TMP/output"
if grep -q 'release ' "$PMIND_TEST_GH_LOG"; then fail 'published assets were modified'; fi
echo 'ok: a published build is unchanged on rerun'

prepare_case mismatch
PMIND_TEST_RELEASE_STATE=mismatch
reject
if grep -q 'release ' "$PMIND_TEST_GH_LOG"; then fail 'another commit was modified'; fi
echo 'ok: an existing release for a different commit is protected'

prepare_case failed_upload
PMIND_TEST_UPLOAD_FAIL=true
reject
if grep -q 'release edit' "$PMIND_TEST_GH_LOG"; then fail 'incomplete assets were published'; fi
echo 'ok: failed uploads leave an unpublished draft'
