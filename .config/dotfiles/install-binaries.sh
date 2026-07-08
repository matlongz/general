#!/bin/sh
# Install the pinned CLI binaries into ~/.local (opt + bin symlinks) for a new
# machine, at the exact versions in versions.env. Idempotent: skips a tool that
# already reports the pinned version. No Homebrew / apt — GitHub-release tarballs,
# the same mechanic used to build `case` (macOS) and `tars` (Debian).
#
# Supported: macOS arm64, Linux x86_64. Other platforms: edit the asset maps.
set -eu
DOT="$(cd "$(dirname "$0")" && pwd)"
. "$DOT/versions.env"

OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS/$ARCH" in
  Darwin/arm64)          PLAT=darwin ;;
  Linux/x86_64|Linux/amd64) PLAT=linux ;;
  *) echo "unsupported platform $OS/$ARCH — extend the asset maps in this script" >&2; exit 1 ;;
esac

mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
DL="$(mktemp -d)"; trap 'rm -rf "$DL"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }
link() { ln -sf "$1" "$HOME/.local/bin/$2"; }
fetch() { curl -fsSL "$1" -o "$DL/$2"; }

# --- nvim ---
if ! { have nvim && nvim --version | head -1 | grep -q "v$NVIM_VERSION"; }; then
  if [ "$PLAT" = darwin ]; then A=nvim-macos-arm64; else A=nvim-linux-x86_64; fi
  fetch "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/$A.tar.gz" nvim.tgz
  tar xzf "$DL/nvim.tgz" -C "$HOME/.local/opt"; link "$HOME/.local/opt/$A/bin/nvim" nvim
  echo "installed nvim $NVIM_VERSION"
fi

# --- fd ---
if ! { have fd && fd --version | grep -q "$FD_VERSION"; }; then
  if [ "$PLAT" = darwin ]; then A="fd-v$FD_VERSION-aarch64-apple-darwin"; else A="fd-v$FD_VERSION-x86_64-unknown-linux-gnu"; fi
  fetch "https://github.com/sharkdp/fd/releases/download/v$FD_VERSION/$A.tar.gz" fd.tgz
  tar xzf "$DL/fd.tgz" -C "$HOME/.local/opt"; link "$HOME/.local/opt/$A/fd" fd
  echo "installed fd $FD_VERSION"
fi

# --- ripgrep ---
if ! { have rg && rg --version | head -1 | grep -q "$RIPGREP_VERSION"; }; then
  if [ "$PLAT" = darwin ]; then A="ripgrep-$RIPGREP_VERSION-aarch64-apple-darwin"; else A="ripgrep-$RIPGREP_VERSION-x86_64-unknown-linux-musl"; fi
  fetch "https://github.com/BurntSushi/ripgrep/releases/download/$RIPGREP_VERSION/$A.tar.gz" rg.tgz
  tar xzf "$DL/rg.tgz" -C "$HOME/.local/opt"; link "$HOME/.local/opt/$A/rg" rg
  echo "installed ripgrep $RIPGREP_VERSION"
fi

# --- lazygit ---
if ! { have lazygit && lazygit --version | grep -q "version=$LAZYGIT_VERSION"; }; then
  if [ "$PLAT" = darwin ]; then A="lazygit_${LAZYGIT_VERSION}_darwin_arm64"; else A="lazygit_${LAZYGIT_VERSION}_linux_x86_64"; fi
  fetch "https://github.com/jesseduffield/lazygit/releases/download/v$LAZYGIT_VERSION/$A.tar.gz" lg.tgz
  mkdir -p "$HOME/.local/opt/lazygit-$LAZYGIT_VERSION"
  tar xzf "$DL/lg.tgz" -C "$HOME/.local/opt/lazygit-$LAZYGIT_VERSION"
  link "$HOME/.local/opt/lazygit-$LAZYGIT_VERSION/lazygit" lazygit
  echo "installed lazygit $LAZYGIT_VERSION"
fi

# --- fzf ---
if ! { have fzf && fzf --version | grep -q "$FZF_VERSION"; }; then
  if [ "$PLAT" = darwin ]; then A="fzf-$FZF_VERSION-darwin_arm64"; else A="fzf-$FZF_VERSION-linux_amd64"; fi
  fetch "https://github.com/junegunn/fzf/releases/download/v$FZF_VERSION/$A.tar.gz" fzf.tgz
  mkdir -p "$HOME/.local/opt/fzf-$FZF_VERSION"
  tar xzf "$DL/fzf.tgz" -C "$HOME/.local/opt/fzf-$FZF_VERSION"
  link "$HOME/.local/opt/fzf-$FZF_VERSION/fzf" fzf
  echo "installed fzf $FZF_VERSION"
fi

# --- node (nodejs.org tarball; needed by pyright/vtsls/yaml/json/bash servers + prettier) ---
if ! { have node && node --version | grep -q "v$NODE_VERSION"; }; then
  if [ "$PLAT" = darwin ]; then A="node-v$NODE_VERSION-darwin-arm64"; else A="node-v$NODE_VERSION-linux-x64"; fi
  fetch "https://nodejs.org/dist/v$NODE_VERSION/$A.tar.xz" node.txz
  tar xf "$DL/node.txz" -C "$HOME/.local/opt"
  for b in node npm npx; do link "$HOME/.local/opt/$A/bin/$b" "$b"; done
  echo "installed node $NODE_VERSION"
fi

echo "done. Ensure ~/.local/bin is FIRST on PATH (SETUP.md step 2)."
