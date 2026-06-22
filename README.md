# zed-setup

Personal [Zed](https://zed.dev) editor configuration, version-controlled so it can be synced across machines and restored on a fresh install.

## Why this exists

Zed stores most settings under `~/.config/zed`, which is easy to lose when reinstalling or switching computers. This repo tracks the pieces that matter for day-to-day work:

- **Editor preferences** — theme, fonts, diagnostics, PHP language server settings, and Cursor agent defaults in `settings.json`.
- **Git worktree automation** — Zed can create git worktrees for parallel branches. These configs wire that up for Laravel projects using [Herd](https://herd.laravel.com): new worktrees get a copied `.env`, a Herd-compatible `APP_URL`, and a flattened directory layout when needed.

Without this repo, you would reconfigure Zed manually and run the same worktree setup steps by hand every time you start a new branch checkout.

## Setup

### 1. Install Zed

Download and install Zed from [zed.dev](https://zed.dev).

### 2. Clone into the Zed config directory

Back up any existing config first if you have one:

```bash
mv ~/.config/zed ~/.config/zed.bak
```

Clone this repo:

```bash
git clone https://github.com/Chege-Simon/zed-setup.git ~/.config/zed
```

Or, if you already have a checkout elsewhere, symlink it:

```bash
ln -s /path/to/zed-setup ~/.config/zed
```

### 3. Make the worktree script executable

```bash
chmod +x ~/.config/zed/setup-worktree.sh
```

### 4. Restart Zed

Quit and reopen Zed so it picks up `settings.json` and `tasks.json`.

## Usage

### Everyday editing

Open Zed as usual. Settings apply globally — no extra steps.

Notable defaults in `settings.json`:

| Setting | Value | Purpose |
|---|---|---|
| `git.worktree_directory` | `../worktrees` | Worktrees are created in a sibling folder next to the main repo |
| `languages.PHP.language_servers` | `intelephense` | PHP support via Intelephense |
| `agent_servers.cursor` | registry | Cursor agent with `composer-2.5[fast=true]` as default model |

### Creating a git worktree

This setup is aimed at Laravel + Herd workflows, but the worktree hook works for any project that uses a `.env` file.

1. Open a git repository in Zed.
2. Create a new worktree from the git panel (or use Zed's worktree commands).
3. Zed places the worktree in `<repo-parent>/worktrees/<branch-name>/` based on the `worktree_directory` setting.
4. On creation, the **"setup new worktree"** task runs automatically via the `create_worktree` hook defined in `tasks.json`.

The hook calls `setup-worktree.sh`, which:

1. **Copies `.env`** from the main worktree into the new worktree (if one exists).
2. **Flattens nested worktrees** for Laravel projects — if Zed creates `worktrees/<branch>/<repo-name>/`, the script moves the inner directory up so Herd can serve it at `<branch>.test`.
3. **Recreates the nested path as a symlink** — Zed's git panel still looks for `.../<branch>/<repo-name>/` after flattening. The script adds `<repo-name> -> .` inside the flattened folder so Zed finds the repo where it expects it, then excludes that symlink from git status so it does not appear as a new folder.
4. **Trusts exact paths in Git** — adds the nested path Zed opens (not just the flattened root) to `safe.directory`. Uses logical paths so symlink targets match what libgit2 checks.
5. **Updates `APP_URL`** in the new worktree's `.env` to `http://<worktree-name>.test`, matching Herd's convention.

After the task finishes, visit the URL in your browser (Herd must be running and the domain should resolve automatically).

If an existing worktree still shows a git trust error, re-run setup manually from the flattened folder:

```bash
ZED_MAIN_GIT_WORKTREE=/path/to/main/repo \
ZED_WORKTREE_ROOT=/path/to/worktrees/my-branch/my-repo \
~/.config/zed/setup-worktree.sh
```

Or trust the nested path Zed shows in the error and create the symlink yourself:

```bash
cd /path/to/worktrees/my-branch
ln -s . my-repo
git config --global --add safe.directory "$(pwd)/my-repo"
```

### Customizing for your machine

- **Herd path** — `tasks.json` prepends Herd's bin directory to `PATH` so CLI tools are available during the hook. Adjust the path if your Herd install location differs.
- **Worktree directory** — change `git.worktree_directory` in `settings.json` if you prefer worktrees somewhere else (absolute or relative to the repo root).
- **Script location** — `tasks.json` references `~/.config/zed/setup-worktree.sh`. If you keep the repo elsewhere, update the path in `tasks.json` to match.

## What's in this repo

```
settings.json         # Zed editor settings
tasks.json            # Worktree creation hook → setup-worktree.sh
setup-worktree.sh     # Copies .env, flattens layout, sets APP_URL
```

Local-only Zed data (prompt libraries, etc.) lives under `~/.config/zed` but is not tracked here.

## Updating

Pull the latest config on any machine:

```bash
cd ~/.config/zed && git pull
```

Then restart Zed.
