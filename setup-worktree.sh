#!/bin/bash
set -euo pipefail

# Zed task hooks may run with a minimal environment (wrong or missing HOME).
# libgit2 reads the same global gitconfig as the CLI, so point at the real one.
export HOME="${HOME:-/Users/$(id -un)}"
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"

git_config_paths() {
  git config --global --get-all safe.directory 2>/dev/null || true
}

trust_git_directory() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  dir="$(cd "$dir" && pwd -P)"

  if git_config_paths | grep -Fxq "$dir"; then
    return 0
  fi

  git config --global --add safe.directory "$dir"
  echo "✅ Git trusted $dir (wrote to $GIT_CONFIG_GLOBAL)"
}

prune_stale_safe_directories() {
  local dir
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    [[ "$dir" == *"*"* ]] && continue
    [ -d "$dir" ] && continue
    git config --global --unset-all safe.directory "$dir" 2>/dev/null || true
    echo "🧹 Removed stale safe.directory entry: $dir"
  done < <(git_config_paths)
}

REPO_NAME=$(basename "$ZED_MAIN_GIT_WORKTREE")
NESTED="$ZED_WORKTREE_ROOT"

# Zed's libgit2 requires exact paths (wildcards like /worktrees/* do not work).
# Trust before any git commands, and again after flatten when the path changes.
trust_git_directory "$ZED_MAIN_GIT_WORKTREE"
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
prune_stale_safe_directories

sed -i '' "s|APP_URL=.*|APP_URL=http://${WORKTREE_NAME}.test|" "$TARGET/.env" 2>/dev/null || true
echo "✅ APP_URL updated to http://${WORKTREE_NAME}.test"
