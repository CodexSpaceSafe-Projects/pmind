#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${GITHUB_REPOSITORY:?}" "${GITHUB_SHA:?}" "${GITHUB_RUN_NUMBER:?}" "${GITHUB_RUN_ID:?}"
if [[ "${GITHUB_REF:-}" != refs/heads/main || ( "${GITHUB_EVENT_NAME:-}" != push && "${GITHUB_EVENT_NAME:-}" != workflow_dispatch ) ]]; then
  echo "仅发布 main 的成功推送或手动构建。" >&2
  exit 1
fi
[[ "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ && "$GITHUB_RUN_NUMBER" =~ ^[1-9][0-9]*$ ]]
cd "${1:-$ROOT_DIR/release}"
assets=()
for arch in arm64 x86_64; do
  test -s "pmind-macos-$arch.zip"
  test -s "pmind-macos-$arch.zip.sha256"
  sha256sum --check "pmind-macos-$arch.zip.sha256"
  assets+=("pmind-macos-$arch.zip" "pmind-macos-$arch.zip.sha256")
done

version="$(cat "$ROOT_DIR/VERSION")"
tag="build-${GITHUB_RUN_NUMBER}-${GITHUB_SHA:0:7}"
url="https://github.com/${GITHUB_REPOSITORY}/releases/tag/${tag}"
if metadata="$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" --jq '[.target_commitish, .draft] | @tsv' 2>/dev/null)"; then
  IFS=$'\t' read -r target draft <<< "$metadata"
  if [[ "$target" != "$GITHUB_SHA" ]]; then
    echo "已有预发布的来源提交不符，停止修改。" >&2
    exit 1
  fi
  if [[ "$draft" == false ]]; then
    echo "预发布已完成：${url}"
    exit 0
  fi
else
  notes="$(mktemp)"
  trap 'rm -f "$notes"' EXIT
  cat > "$notes" <<EOF
pmind ${version} 的自动开发预发布版。

- Apple Silicon：pmind-macos-arm64.zip
- Intel：pmind-macos-x86_64.zip
- 对应的 .sha256 文件用于完整性校验。
- 来源提交：${GITHUB_SHA}
- 构建记录：https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}

安装包使用本地开发签名，尚未经过 Developer ID 签名和 Apple 公证。
EOF
  gh release create "$tag" --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" \
    --title "pmind ${version} 开发构建 #${GITHUB_RUN_NUMBER}" --notes-file "$notes" \
    --draft --prerelease --latest=false
fi

# Retry partial drafts; published releases above are left unchanged.
gh release upload "$tag" "${assets[@]}" --repo "$GITHUB_REPOSITORY" --clobber
gh release edit "$tag" --repo "$GITHUB_REPOSITORY" --draft=false --prerelease --latest=false
printf '%s\n' "$url"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '[下载开发预发布版](%s)\n' "$url" >> "$GITHUB_STEP_SUMMARY"
fi
