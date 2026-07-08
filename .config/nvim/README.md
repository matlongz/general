# Neovim config (LazyVim base)

Personal Neovim setup — must behave **identically on macOS and Debian Linux**.
Full design rationale: nvim-setup-plan (Codex-reviewed, July 2026).

## Three pinned layers (commit together, only after validation)

1. `lazy-lock.json` — plugin graph (restored via `:Lazy restore`)
2. `bootstrap-tools.sh` — Mason tool manifest, exact versions
3. Binaries (below) — same versions both machines, GitHub release tarballs into
   `~/.local/opt`, symlinked into `~/.local/bin`. No Homebrew, no apt for these.

| Binary  | Pinned version | macOS asset (arm64)                        | Debian asset (x86_64)                          |
|---------|----------------|--------------------------------------------|------------------------------------------------|
| nvim    | v0.12.4        | nvim-macos-arm64.tar.gz                     | nvim-linux-x86_64.tar.gz                        |
| fd      | v10.4.2        | fd-v10.4.2-aarch64-apple-darwin.tar.gz      | fd-v10.4.2-x86_64-unknown-linux-gnu.tar.gz      |
| fzf     | v0.74.0        | fzf-0.74.0-darwin_arm64.tar.gz              | fzf-0.74.0-linux_amd64.tar.gz                   |
| lazygit | v0.63.0        | lazygit_0.63.0_darwin_arm64.tar.gz          | lazygit_0.63.0_linux_x86_64.tar.gz              |
| ripgrep | (present)      | system install                              | ripgrep-<same-ver>-x86_64-unknown-linux-musl    |
| node    | v22.20.0       | (already installed)                         | node-v22.20.0-linux-x64.tar.xz (nodejs.org)     |

Verify archives against each release's checksum file; `xattr -c` on macOS downloads.

## Bootstrap a new machine — ORDER MATTERS (pins before any normal launch)

```sh
# 0. Debian prereqs: apt install git build-essential; binaries per table above;
#    clipboard: wl-clipboard (Wayland) / xclip (X11); over SSH, OSC 52 is automatic.
#    TERMINAL FONT (per-machine infra, like clipboard): a Nerd Font is REQUIRED for
#    LazyVim's icons — JetBrainsMono Nerd Font v3.4.0 (github.com/ryanoasis/nerd-fonts).
#    macOS: ttf files into ~/Library/Fonts, then set the font in the terminal profile.
#    Debian desktop: into ~/.local/share/fonts + fc-cache -f. Over SSH: the LOCAL
#    terminal's font is what matters — nothing to install on the remote.
git clone <this-repo> ~/.config/nvim
nvim --headless "+Lazy! restore" +qa   # plugins at locked versions; no interactive session
~/.config/nvim/bootstrap-tools.sh      # Mason tools at manifest versions (--force = authoritative)
nvim                                   # first interactive launch — extras' ensure_installed no-ops
```

## Post-install validation (each machine, each update)

1. `:LazyHealth` and `:checkhealth` — zero errors (optional-provider warnings OK)
2. `:Mason` — every manifest entry at its pinned version; `ruff --version` / `prettier --version` match
3. One file per language (py/ts/yaml/json/md/sh/sql/Django html) — highlighting + LSP where expected;
   `:set ft?` on `**/templates/*.html` returns `htmldjango`
4. Smoke: `<Space>e` neo-tree, `<Space><Space>` picker, `<Space>/` grep, `:DiffviewOpen`, `<Space>gg` lazygit
5. `:Lazy` — no dap/neotest/venv-selector plugins active (python-trim guard)
6. Only then commit lockfile + manifest + this README's binary table

## Deliberate decisions (don't "fix" these)

- No `lang.yaml` extra — yamlls wired directly with validation OFF (k8s/kustomize noise; matches VSCode choice)
- No `lang.sql` extra — treesitter highlighting only; enable the extra later if query execution is wanted
- Django templates: highlight/indent only, NO formatter (prettier would mangle template tags)
- No DAP/debugger/test plugins (python-trim.lua enforces); no AI/Copilot plugins ever (AI happens in a separate CLI); no PR tooling (gh CLI covers it)
- Keep LazyVim defaults (snacks picker, blink.cmp) — don't swap components
- Update deliberately: `:Lazy update` monthly-ish → validate → commit; rollback = git revert lockfile + `:Lazy restore`

## Syncing across machines (matlongz/general)

Tracked in the `matlongz/general` dotfiles repo as a **bare repo with `$HOME` as
work-tree** — files live in place, no symlinks:

    alias general='git --git-dir=$HOME/.general.git --work-tree=$HOME'

- Pull latest: `general pull`
- Push edits: `general add ~/.config/nvim/<file> && general commit -m "…" && general push`
- Safety: `status.showUntrackedFiles=no` + key-exclude patterns in
  `.general.git/info/exclude` keep SSH keys/credentials out. Never `general add -A`.
- Servers (tars) use sparse-checkout (`.general.git/info/sparse-checkout` = `.config/nvim/`)
  so they sync ONLY this nvim config, not the laptop's `.ssh/config` / `.bash_profile`.
