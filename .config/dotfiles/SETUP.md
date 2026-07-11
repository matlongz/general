# Bootstrap a new machine to case/tars parity

Runbook for a human or agent to provision a new machine from this dotfiles repo
(`matlongz/general`, a bare repo with `$HOME` as work-tree — no symlinks). Two
profiles:

- **workstation** (like `case`, macOS laptop): full dotfiles, renders `~/.ssh/config`
  + `~/.tmux.conf`, uses the editor interactively.
- **server** (like `tars`, Debian): sparse-checkout `.config/nvim/` + `.config/dotfiles/`,
  renders `~/.tmux.conf` only (never an ssh config), reachable via Tailscale.

Pinned versions are in `versions.env` (binaries), `../nvim/bootstrap-tools.sh`
(LSP/formatter tools), and `../nvim/lazy-lock.json` (plugins). Bump deliberately.

## 0. Prerequisites (install via the OS package manager — the only apt/system step)
- `git`, `curl`, `tar`, `xz`, and a C compiler (`build-essential` on Debian / Xcode CLT on macOS — for treesitter).
- Debian only: `sudo apt install python3-venv` (Mason builds `ruff` in a venv; without it ruff install fails).
- GitHub access over HTTPS for `matlongz/general` (stored credential or a PAT).

## 1. Clone the dotfiles bare repo + get the templates
```sh
git clone --bare https://github.com/matlongz/general.git "$HOME/.general.git"
general() { git --git-dir="$HOME/.general.git" --work-tree="$HOME" "$@"; }
# server profile only: limit to nvim + dotfiles BEFORE checkout
git --git-dir="$HOME/.general.git" config core.sparseCheckout true
printf '.config/nvim/\n.config/dotfiles/\n' > "$HOME/.general.git/info/sparse-checkout"
general checkout -f main    # workstation: omit the two sparse lines to get everything
```

## 2. Install pinned binaries + fix PATH
```sh
"$HOME/.config/dotfiles/install-binaries.sh"     # nvim, fd, rg, lazygit, fzf, node → ~/.local
# Ensure ~/.local/bin is FIRST on PATH (bypasses any older apt nvim):
grep -q 'HOME/.local/bin:' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
# macOS interactive login shells: also add shared aliases to ~/.bash_profile:
#   [ -f "$HOME/.config/dotfiles/templates/shell_aliases.sh" ] && . "$HOME/.config/dotfiles/templates/shell_aliases.sh"
```

## 3. Install the commit guards (versioned, per-clone)
```sh
"$HOME/.config/dotfiles/bootstrap.sh"    # showUntrackedFiles=no + info/exclude + pre-commit hook
```

## 4. Render live configs from templates
```sh
cp "$HOME/.config/dotfiles/vars.env.example" "$HOME/.config/dotfiles/vars.env"
$EDITOR "$HOME/.config/dotfiles/vars.env"        # fill SSH_USER / TARS_TS_IP / TAILNET
"$HOME/.config/dotfiles/render.sh" all            # workstation: ssh + tmux (validates ssh -G)
# server profile: "$HOME/.config/dotfiles/render.sh" tmux   (no vars.env needed for tmux)
```

## 5. Bring up Neovim (pinned plugins + tools) — ORDER MATTERS
```sh
nvim --headless "+Lazy! restore" +qa              # plugins at locked versions
"$HOME/.config/nvim/bootstrap-tools.sh"           # Mason LSP/formatters at pinned versions
# treesitter parsers install on first real launch, or force headlessly (see nvim/README.md)
```

## 6. Manual, machine-specific steps (cannot be scripted)
- **Nerd Font** (`versions.env`: JetBrainsMono, v3.4.0): install into the terminal that
  DISPLAYS this machine's sessions (local terminal font), set the profile font. Required
  for icons. Raw Linux console can't render them (bitmap font) — the nvim config
  auto-falls-back to ASCII when `TERM=linux`.
- **Tailscale** (server profile / remote access): `curl -fsSL https://tailscale.com/install.sh | sh`
  then `sudo tailscale up` and authenticate in a browser. See the `tars-remote-access` notes.
- **Tailscale fe80 guard** (server profile, after Tailscale is up): prevents the
  same-LAN link-local blackhole (peers' traffic times out after they sleep/wake).
  Install per `../server/tailscale-fe80-guard/README.md` — two `install` commands
  plus `systemctl enable --now tailscale-fe80-guard.service`.

## 7. Validate (nvim/README.md has the full checklist)
`:LazyHealth` + `:checkhealth` (0 errors) · `:Mason` versions match · open a file per
language (`:set ft?` = `htmldjango` on templates) · picker/neo-tree/diffview/lazygit launch ·
`:Lazy` shows no dap/neotest/venv · `ssh tars` works (workstation) ·
`systemctl is-enabled tailscale-fe80-guard` = enabled (server).

## Notes
- Never `general add -A`; add explicit paths. Secrets/live configs are blocked by the hook +
  excludes (`vars.env`, `.ssh/config[.bak]`, `.tmux.conf[.bak]`, private keys).
- Only `.config/dotfiles/**` + `.config/nvim/**` are tracked. Templatize anything new before tracking.
