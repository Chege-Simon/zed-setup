#!/bin/bash
set -euo pipefail

REPO_NAME=$(basename "$ZED_MAIN_GIT_WORKTREE")
NESTED="$ZED_WORKTREE_ROOT"

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

sed -i '' "s|APP_URL=.*|APP_URL=http://${WORKTREE_NAME}.test|" "$TARGET/.env" 2>/dev/null || true
echo "✅ APP_URL updated to http://${WORKTREE_NAME}.test"
