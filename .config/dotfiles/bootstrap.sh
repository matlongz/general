#!/bin/sh
# One-time per-clone setup for the `general` dotfiles bare repo.
# Installs the guards that keep secrets/local files from being committed.
set -eu
GD="${GENERAL_GIT:-$HOME/.general.git}"
[ -d "$GD" ] || { echo "bare repo not found at $GD (clone general first)" >&2; exit 1; }

# Never surface untracked files (so keys/local files can't be swept into a commit).
git --git-dir="$GD" config status.showUntrackedFiles no

# Local defense-in-depth excludes (belt-and-suspenders with the pre-commit hook).
EX="$GD/info/exclude"
for p in \
  '.config/dotfiles/vars.env' \
  '.ssh/config' '.ssh/config.bak' \
  '.tmux.conf' '.tmux.conf.bak' \
  '.ssh/id_*' '.ssh/*_ed25519' '*.pem' '.credentials.json' \
  '.ssh/known_hosts' '.ssh/agent'
do
  grep -qxF "$p" "$EX" 2>/dev/null || echo "$p" >> "$EX"
done

# Install the tracked pre-commit hook (copy, not symlink).
cp "$HOME/.config/dotfiles/hooks/pre-commit" "$GD/hooks/pre-commit"
chmod +x "$GD/hooks/pre-commit"

echo "bootstrap: showUntrackedFiles=no, excludes written, pre-commit hook installed"
