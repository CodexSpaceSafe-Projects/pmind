#!/usr/bin/env bash

# Install only a fully built and signed staging bundle. Never modify a running app's files.
install_app_bundle() {
  local staged="$1" destination="$2" mode="$3" attempt
  local backup="${staged%/*}/previous.app"
  [[ -d "$staged" && ! -e "$backup" ]] || return 1
  if pgrep -x pmind >/dev/null 2>&1; then
    if [[ "$mode" == --build-only ]]; then
      echo "pmind 正在运行，未替换 .app；请先保存并退出应用再构建。" >&2
      return 1
    fi
    # NSApplication/NSDocument handles pending edits and lets the user cancel quitting.
    if ! osascript -e 'tell application id "app.pmind.mac" to quit'; then
      echo "应用未正常退出，已取消替换与启动。" >&2
      return 1
    fi
    for attempt in {1..50}; do
      if ! pgrep -x pmind >/dev/null 2>&1; then break; fi
      sleep 0.1
    done
    if pgrep -x pmind >/dev/null 2>&1; then
      echo "pmind 仍在运行，已取消替换；请保存并关闭所有实例后重试。" >&2
      return 1
    fi
  fi
  if [[ -e "$destination" ]]; then
    mv "$destination" "$backup" || return 1
  fi
  if ! mv "$staged" "$destination"; then
    if [[ -e "$backup" ]]; then
      mv "$backup" "$destination" || echo "无法恢复旧应用，请检查 $backup。" >&2
    fi
    return 1
  fi
}

cleanup_app_staging() {
  local staging="$1" destination="$2"
  if [[ -e "$staging/previous.app" && ! -e "$destination" ]]; then
    if ! mv "$staging/previous.app" "$destination"; then
      echo "旧应用恢复失败，已保留暂存目录：$staging" >&2
      return
    fi
  fi
  rm -rf -- "$staging"
}
