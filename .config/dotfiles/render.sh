#!/bin/sh
# Render dotfiles templates -> live config files, filling placeholders from vars.env.
# Safe by construction: temp file + validation + atomic move; never leaves a broken
# live config. Uses perl (present on macOS + Debian) — no envsubst dependency.
#
# Usage: render.sh [ssh|tmux|all]   (default: all)
#   tars runs `render.sh tmux` — needs no vars.env and never touches ~/.ssh/config.
set -eu
DOT="$HOME/.config/dotfiles"
VARS="$DOT/vars.env"
mode="${1:-all}"

need_vars() {
  for v in "$@"; do
    eval "val=\${$v:-}"
    [ -n "$val" ] || { echo "vars.env: $v is empty/unset" >&2; exit 1; }
  done
}

# Substitute ONLY the explicit placeholders via perl (values passed through env).
subst() {
  SSH_USER="$SSH_USER" TARS_LAN_IP="$TARS_LAN_IP" TAILNET="$TAILNET" \
    perl -pe 's/\$\{(SSH_USER|TARS_LAN_IP|TAILNET)\}/$ENV{$1}/g' "$1"
}

# $1 template  $2 target  $3 do_subst(1|0)  $4 validator (optional)
render() {
  [ -f "$1" ] || { echo "template missing: $1" >&2; exit 1; }
  tmp="$(mktemp)"
  if [ "$3" = 1 ]; then subst "$1" > "$tmp"; else cp "$1" "$tmp"; fi
  if grep -q '${' "$tmp"; then echo "unresolved placeholder in $1" >&2; rm -f "$tmp"; exit 1; fi
  if [ -n "${4:-}" ]; then "$4" "$tmp" || { echo "validation failed for $2" >&2; rm -f "$tmp"; exit 1; }; fi
  [ -f "$2" ] && cp -p "$2" "$2.bak"   # .bak holds real data -> guarded by hook + info/exclude
  mkdir -p "$(dirname "$2")"
  mv "$tmp" "$2"
  echo "rendered $2"
}

ssh_ok() { ssh -F "$1" -G tars >/dev/null 2>&1; }

case "$mode" in
  ssh|all)
    [ -f "$VARS" ] || { echo "missing $VARS (copy vars.env.example, fill in)" >&2; exit 1; }
    # shellcheck disable=SC1090
    . "$VARS"
    need_vars SSH_USER TARS_LAN_IP TAILNET
    render "$DOT/templates/ssh_config.tmpl" "$HOME/.ssh/config" 1 ssh_ok
    ;;
esac
case "$mode" in
  tmux|all)
    render "$DOT/templates/tmux.conf" "$HOME/.tmux.conf" 0
    ;;
esac
