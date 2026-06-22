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
  [ -e "$dir" ] || return 0
  # Use logical paths (pwd), not physical (pwd -P). Zed/libgit2 matches the
  # exact path it opened; resolving symlinks stores the wrong directory.
  dir="$(cd "$dir" && pwd)"

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
    [[ "$dir" != /* ]] && {
      git config --global --unset-all safe.directory "$dir" 2>/dev/null || true
      echo "🧹 Removed invalid safe.directory entry: $dir"
      continue
    }
    [ -e "$dir" ] && continue
    git config --global --unset-all safe.directory "$dir" 2>/dev/null || true
    echo "🧹 Removed stale safe.directory entry: $dir"
  done < <(git_config_paths)
}

exclude_from_git_status() {
  local target="$1"
  local name="$2"
  local common_git_dir exclude_file pattern

  common_git_dir="$(git -C "$target" rev-parse --git-common-dir)"
  exclude_file="$common_git_dir/info/exclude"
  pattern="/$name"

  mkdir -p "$(dirname "$exclude_file")"
  if ! grep -Fxq "$pattern" "$exclude_file" 2>/dev/null; then
    echo "$pattern" >> "$exclude_file"
    echo "🙈 Ignored $pattern in git status (local exclude)"
  fi
}

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

# Zed opens .../<branch>/<repo> (e.g. cyan-plume/bizwiz) due to a known path
# quirk in worktree creation. After flattening, recreate that nested path as a
# symlink so Zed's git panel can find the repo at the path it expects.
ZED_REPO_PATH="$TARGET"
if [ "$TARGET" != "$NESTED" ]; then
  ZED_REPO_PATH="$TARGET/$REPO_NAME"

  # Flattening can leave an empty nested folder before the symlink is recreated.
  if [ -d "$ZED_REPO_PATH" ] && [ ! -L "$ZED_REPO_PATH" ] && [ -z "$(ls -A "$ZED_REPO_PATH" 2>/dev/null)" ]; then
    rmdir "$ZED_REPO_PATH"
    echo "🧹 Removed empty residue folder: $ZED_REPO_PATH"
  fi

  if [ ! -e "$ZED_REPO_PATH" ]; then
    ln -s . "$ZED_REPO_PATH"
    echo "🔗 Created symlink for Zed: $ZED_REPO_PATH -> ."
  fi

  exclude_from_git_status "$TARGET" "$REPO_NAME"
fi

trust_git_directory "$ZED_MAIN_GIT_WORKTREE"
trust_git_directory "$ZED_REPO_PATH"
trust_git_directory "$TARGET"
prune_stale_safe_directories

sed -i '' "s|APP_URL=.*|APP_URL=http://${WORKTREE_NAME}.test|" "$TARGET/.env" 2>/dev/null || true
echo "✅ APP_URL updated to http://${WORKTREE_NAME}.test"
