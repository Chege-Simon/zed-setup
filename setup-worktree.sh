#!/bin/bash
set -euo pipefail

trust_git_directory() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  dir="$(cd "$dir" && pwd)"
  if git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$dir"; then
    return 0
  fi
  git config --global --add safe.directory "$dir"
  echo "✅ Git trusted $dir"
}

REPO_NAME=$(basename "$ZED_MAIN_GIT_WORKTREE")
NESTED="$ZED_WORKTREE_ROOT"

trust_git_directory "$NESTED"

if [ "$(basename "$NESTED")" = "$REPO_NAME" ]; then
  WORKTREE_NAME=$(basename "$(dirname "$NESTED")")
else
  WORKTREE_NAME=$(basename "$NESTED")
fi

cp "$ZED_MAIN_GIT_WORKTREE/.env" "$NESTED/" 2>/dev/null || true

if [ -f "$NESTED/artisan" ] && [ "$(basename "$NESTED")" = "$REPO_NAME" ] && [ "$WORKTREE_NAME" != "$REPO_NAME" ]; then
  PARENT="$(dirname "$NESTED")"
  TEMP="${PARENT}-flatten-tmp"
  echo '📦 Flattening nested worktree structure...'
  git -C "$NESTED" worktree move "$NESTED" "$TEMP"
  rm -rf "$PARENT"
  mv "$TEMP" "$PARENT"
  git -C "$ZED_MAIN_GIT_WORKTREE" worktree repair "$PARENT"
  echo '✅ Flattened successfully'
  TARGET="$PARENT"
else
  TARGET="$NESTED"
fi

trust_git_directory "$TARGET"

sed -i '' "s|APP_URL=.*|APP_URL=http://${WORKTREE_NAME}.test|" "$TARGET/.env" 2>/dev/null || true
echo "✅ APP_URL updated to http://${WORKTREE_NAME}.test"
