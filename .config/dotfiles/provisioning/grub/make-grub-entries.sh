#!/bin/sh
# Generate /etc/grub.d/08_desktop_server for this host from
# 08_desktop_server.template, substituting the root filesystem UUID, and set
# default.target=graphical.target (the Desktop entry boots default.target).
#
# Checks preconditions BEFORE writing and exits non-zero without touching
# anything if they fail. Does not modify /etc/default/grub.
#
# Run as root, then update-grub.
set -e

TEMPLATE="${1:-$(dirname "$0")/08_desktop_server.template}"
TARGET=/etc/grub.d/08_desktop_server
GRUBDEF=/etc/default/grub
fail() { echo "!! $*" >&2; FAILED=1; }
FAILED=0

[ -r "$TEMPLATE" ] || { echo "template not found: $TEMPLATE" >&2; exit 1; }

# ---- preconditions ---------------------------------------------------------
# --first-only: a stacked/bind mount on / would otherwise yield two rows and a
# multi-line UUID. `|| true` so set -e doesn't pre-empt the message below.
UUID=$(findmnt --first-only -no UUID / 2>/dev/null || true)
case "$UUID" in
  '')            fail "could not determine the root filesystem UUID" ;;
  *[!0-9a-fA-F-]*|*'
'*)              fail "root UUID looks wrong: $UUID" ;;
esac

# Both entries load /vmlinuz + /initrd.img. A separate /boot puts them out of
# reach of the filesystem GRUB searches, and both entries would be dead.
[ "$(findmnt --first-only -no TARGET --target /boot 2>/dev/null)" = "/" ] ||
    fail "/boot is a separate filesystem; the template's /vmlinuz paths will not resolve"
for f in /vmlinuz /initrd.img; do
    [ -e "$f" ] || fail "$f is missing or a dangling symlink; the entries would not boot"
done

# EXTRA_CMDLINE is not persisted anywhere else, so a re-run without it would
# silently drop params (hibernation resume=, driver flags) from a previous run.
EXTRA="${EXTRA_CMDLINE:-}"
if [ -z "$EXTRA" ] && [ -r "$TARGET" ]; then
    PREV=$(sed -n 's/^# EXTRA_CMDLINE=//p' "$TARGET" 2>/dev/null || true)
    [ -n "$PREV" ] && fail "$TARGET was generated with EXTRA_CMDLINE=\"$PREV\";
   re-running without it would drop those params. Re-run with:
     EXTRA_CMDLINE=\"$PREV\" sh $0"
fi

[ "$FAILED" -eq 0 ] || { echo "Nothing was changed." >&2; exit 1; }

# ---- render (atomically: never truncate a working generator) ---------------
esc_repl() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }   # sed replacement metachars
[ -n "$EXTRA" ] && EXTRA_SUB="$EXTRA " || EXTRA_SUB=""

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
{
  sed -e "s|__ROOT_UUID__|$(esc_repl "$UUID")|g" \
      -e "s|__EXTRA_CMDLINE__|$(esc_repl "$EXTRA_SUB")|g" "$TEMPLATE"
  printf '# EXTRA_CMDLINE=%s\n' "$EXTRA"
} > "$TMP"

# The generated file is a shell script grub-mkconfig executes; if it does not
# parse, update-grub fails. Cheap to check, and the old file is still intact.
sh -n "$TMP" 2>/dev/null || true       # body after `exec tail` is GRUB syntax, not shell
grep -q "^menuentry .*'gnulinux-server'" "$TMP" &&
grep -q "^menuentry .*'gnulinux-desktop'" "$TMP" ||
    { echo "!! rendered file is missing an expected menuentry; not installing" >&2; exit 1; }

cat "$TMP" > "$TARGET"
chmod 755 "$TARGET"
echo "Wrote $TARGET (root UUID $UUID${EXTRA:+, EXTRA_CMDLINE=\"$EXTRA\"})"
echo

# ---- other generators emitting our menuentry IDs ---------------------------
# grub-mkconfig runs every executable file in /etc/grub.d whatever its name, so
# a backup copy (cp -a keeps +x) keeps emitting its entries.
for f in /etc/grub.d/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    [ "$f" = "$TARGET" ] && continue
    if grep -qE "menuentry_id_option '(gnulinux-server|gnulinux-desktop)'" "$f" 2>/dev/null; then
        fail "$f also emits our menuentry IDs — duplicate entries, and
   GRUB_DEFAULT becomes ambiguous. Move it out of /etc/grub.d:
     mv '$f' /root/"
    fi
done

# ---- 10_linux must not also emit a top-level entry -------------------------
# Its `linux_entry ... simple` call is expected to be commented out. That call
# and the submenu opener share a guard on GRUB_DISABLE_SUBMENU, so setting that
# option also puts every advanced/recovery entry at top level.
if [ -r /etc/grub.d/10_linux ]; then
    if grep -qE '^[[:space:]]*linux_entry[^#]*[[:space:]]simple([[:space:]]|\\|$)' /etc/grub.d/10_linux; then
        fail "/etc/grub.d/10_linux emits its own top-level entry; it duplicates Desktop.
   Comment out its 'linux_entry \"\${OS}\" \"\${version}\" simple' call.
   (A grub-common upgrade may have replaced this conffile.)"
    else
        echo "10_linux: top-level entry suppressed, Advanced options kept."
    fi
fi
if [ -r "$GRUBDEF" ] && grep -qE '^[[:space:]]*GRUB_DISABLE_SUBMENU=(true|y|yes)' "$GRUBDEF"; then
    fail "GRUB_DISABLE_SUBMENU is set: 10_linux will emit every kernel and recovery
   entry at top level instead of inside 'Advanced options'."
fi

# ---- default.target --------------------------------------------------------
CURRENT_DEFAULT=$(systemctl get-default 2>/dev/null || echo unknown)
if [ "$CURRENT_DEFAULT" = graphical.target ]; then
    echo "default.target already graphical.target."
else
    echo "default.target is '$CURRENT_DEFAULT'; the Desktop entry boots default.target."
    if systemctl set-default graphical.target >/dev/null 2>&1; then
        echo "  -> set default.target = graphical.target"
    else
        fail "could not set default.target; run: systemctl set-default graphical.target"
    fi
fi

# Neither generated entry inherits GRUB_CMDLINE_LINUX (10_linux's entries do).
# Sourced in a subshell with set -e disabled: grub-mkconfig sources this file
# without -e, and a bare `grep -q` or a failed command substitution in it would
# otherwise abort the subshell and silently yield an empty value.
CUR_LINUX=$( set +e; . "$GRUBDEF" >/dev/null 2>&1; printf '%s' "${GRUB_CMDLINE_LINUX-}" ) || CUR_LINUX=""
if [ -n "$CUR_LINUX" ]; then
    case " $EXTRA " in
      *" $CUR_LINUX "*) : ;;
      *) echo
         echo "Note: GRUB_CMDLINE_LINUX is set: $CUR_LINUX" >&2
         echo "  Only 10_linux's entries inherit it; Server and Desktop do not." >&2
         echo "  If those params are needed to boot, re-run with:" >&2
         echo "    EXTRA_CMDLINE=\"$CUR_LINUX\" sh $0" >&2 ;;
    esac
fi
echo

[ "$FAILED" -eq 0 ] || { echo "!! Fix the above BEFORE update-grub." >&2; exit 1; }

echo "Finish with:  update-grub"
echo "Menu: 'Debian GNU/Linux Server (CLI)', 'Debian GNU/Linux Desktop (Gnome)',"
echo "then 'Advanced options' (kernel rollback + recovery); os-prober/UEFI/fwupd"
echo "may add more. GRUB_DEFAULT='gnulinux-server' or 'gnulinux-desktop' selects."
echo
echo "Advanced-options entries carry no boot_profile= marker, so boot_profile.sh"
echo "uses DEFAULT_MODE from /etc/default/boot-profile for those (default: desktop)."
