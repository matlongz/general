#!/bin/sh
# Generate /etc/grub.d/08_desktop_server for this host from
# 08_desktop_server.template, substituting the root filesystem UUID.
#
# Also sets default.target=graphical.target (Desktop boots default.target) and
# adds boot_profile=desktop to GRUB_CMDLINE_LINUX_DEFAULT so 10_linux's Advanced
# entries are marked for boot_profile.sh.
#
# Run as root, then update-grub. Exits non-zero if any step could not complete.
set -e

TEMPLATE="${1:-$(dirname "$0")/08_desktop_server.template}"
[ -r "$TEMPLATE" ] || { echo "template not found: $TEMPLATE" >&2; exit 1; }

GRUBDEF=/etc/default/grub
TARGET=/etc/grub.d/08_desktop_server
MARKER=boot_profile=desktop
FAILED=0

UUID=$(findmnt -no UUID /)
[ -n "$UUID" ] || { echo "could not determine root UUID" >&2; exit 1; }

# ---- preconditions the generated entries depend on -------------------------
# Both entries load /vmlinuz and /initrd.img. If /boot is a separate filesystem
# those symlinks are not reachable from the root GRUB searches, and BOTH entries
# are dead — worth failing here rather than at the boot menu.
if [ "$(findmnt -no TARGET --target /boot 2>/dev/null)" != "/" ]; then
    echo "!! /boot is a separate filesystem; the template's /vmlinuz paths will not resolve." >&2
    echo "   Adjust the linux/initrd lines in $TEMPLATE before using it." >&2
    FAILED=1
fi
for f in /vmlinuz /initrd.img; do
    [ -e "$f" ] || { echo "!! $f missing or dangling — entries would not boot." >&2; FAILED=1; }
done

# ---- render ----------------------------------------------------------------
EXTRA="${EXTRA_CMDLINE:-}"
[ -n "$EXTRA" ] && EXTRA="$EXTRA " || true

# EXTRA_CMDLINE is not persisted anywhere, so re-running without it would
# silently drop params (e.g. hibernation resume=) from a previous run.
if [ -z "$EXTRA" ] && [ -r "$TARGET" ] &&
   grep -q '^# EXTRA_CMDLINE=.' "$TARGET" 2>/dev/null; then
    echo "!! $TARGET was generated with:" >&2
    grep '^# EXTRA_CMDLINE=' "$TARGET" >&2
    echo "   Re-running without EXTRA_CMDLINE would drop those params." >&2
    echo "   Re-run with: EXTRA_CMDLINE=\"...\" sh $0" >&2
    FAILED=1
fi

esc_repl() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }   # sed replacement metachars

{
  sed -e "s|__ROOT_UUID__|$(esc_repl "$UUID")|g" \
      -e "s|__EXTRA_CMDLINE__|$(esc_repl "$EXTRA")|g" "$TEMPLATE"
  printf '# EXTRA_CMDLINE=%s\n' "$EXTRA_CMDLINE"
} > "$TARGET"
chmod 755 "$TARGET"
echo "Wrote $TARGET (root UUID $UUID${EXTRA:+, extra: $EXTRA})"
echo

# ---- other generators that could emit our menuentry IDs --------------------
# grub-mkconfig runs every executable file in /etc/grub.d regardless of name, so
# a backup copy (cp -a keeps +x) keeps emitting its entries. Match on the IDs
# rather than on filename suffixes, which catches any copy.
STRAY=$(grep -lE "gnulinux-(server|desktop)" /etc/grub.d/* 2>/dev/null \
        | while read -r f; do
              [ "$f" = "$TARGET" ] && continue
              [ -x "$f" ] && printf '%s\n' "$f"
          done || true)
if [ -n "$STRAY" ]; then
    echo "!! other executable file(s) in /etc/grub.d emit our menuentry IDs:" >&2
    printf '     %s\n' $STRAY >&2
    echo "   Duplicate entries, and GRUB_DEFAULT becomes ambiguous. Move them out" >&2
    echo "   of /etc/grub.d (chmod -x alone leaves a trap for the next person)." >&2
    FAILED=1
fi

# ---- 10_linux must not also emit a top-level entry -------------------------
# Test the code, not a comment marker: an uncommented `linux_entry ... simple`
# means the stock top-level entry is back and duplicates Desktop.
if [ -r /etc/grub.d/10_linux ]; then
    if grep -qE '^[[:space:]]*linux_entry[^#]*[[:space:]]simple([[:space:]]|\\|$)' /etc/grub.d/10_linux; then
        echo "!! /etc/grub.d/10_linux emits its own top-level entry; it will duplicate Desktop." >&2
        echo "   Comment out the 'linux_entry \"\${OS}\" \"\${version}\" simple' call." >&2
        echo "   (Likely a grub-common upgrade replaced this conffile.)" >&2
        FAILED=1
    else
        echo "10_linux: top-level entry suppressed, Advanced options kept."
    fi
fi
echo

# ---- default.target --------------------------------------------------------
CURRENT_DEFAULT=$(systemctl get-default 2>/dev/null || echo unknown)
case "$CURRENT_DEFAULT" in
  graphical.target)     echo "default.target already graphical.target." ;;
  system-update.target) echo "default.target resolves to system-update.target (an update is staged);"
                        echo "  leaving it alone." ;;
  *)  echo "default.target is '$CURRENT_DEFAULT'; Desktop boots default.target."
      if systemctl set-default graphical.target >/dev/null 2>&1; then
          echo "  -> set default.target = graphical.target"
      else
          echo "  !! could not set it; run: systemctl set-default graphical.target" >&2
          FAILED=1
      fi ;;
esac
echo

# ---- boot_profile=desktop in GRUB_CMDLINE_LINUX_DEFAULT --------------------
# Read current values by sourcing, the way grub-mkconfig does. Note it also
# sources /etc/default/grub.d/*.cfg afterwards, so a snippet there overrides
# this file and is checked separately below.
CUR=$(      { . "$GRUBDEF"; printf '%s' "${GRUB_CMDLINE_LINUX_DEFAULT-}"; } 2>/dev/null ) || CUR=""
CUR_LINUX=$({ . "$GRUBDEF"; printf '%s' "${GRUB_CMDLINE_LINUX-}"; }         2>/dev/null ) || CUR_LINUX=""

# Refuse to rewrite anything we cannot faithfully re-emit inside double quotes.
#   - $ ` \ " change meaning when a single-quoted value is re-quoted with ".
#   - A multi-line (backslash-continued or unclosed-quote) assignment must be
#     checked in the FILE, not in the value: sourcing already folds the
#     continuation away, while the awk rewrite replaces only the first line and
#     leaves the rest orphaned, producing an unterminated string that breaks
#     grub-mkconfig.
UNSAFE=""
case "$CUR" in *['$`\"']*) UNSAFE="shell metacharacter" ;; esac
if awk '
    /^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=/ {
        line=$0
        sub(/^[^=]*=/, "", line)
        if (line ~ /\\$/) { found=1; exit }
        dq=gsub(/"/, "&", line); sq=gsub(/'"'"'/, "&", line)
        if (dq % 2 || sq % 2) { found=1; exit }
    }
    END { exit(found ? 0 : 1) }
' "$GRUBDEF" 2>/dev/null; then
    UNSAFE="multi-line assignment"
fi

for f in /etc/default/grub.d/*.cfg; do
    [ -e "$f" ] || continue
    if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT' "$f"; then
        echo "!! $f also sets GRUB_CMDLINE_LINUX_DEFAULT and is sourced after $GRUBDEF." >&2
        echo "   Add $MARKER there instead; editing $GRUBDEF would have no effect." >&2
        FAILED=1
    fi
done

case " $CUR " in
  *" $MARKER "*)   echo "GRUB_CMDLINE_LINUX_DEFAULT already carries $MARKER." ;;
  *boot_profile=*) echo "!! GRUB_CMDLINE_LINUX_DEFAULT sets a different boot_profile=:" >&2
                   echo "     $CUR" >&2
                   echo "   Leaving it untouched — reconcile by hand." >&2
                   FAILED=1 ;;
  *) if [ -n "$UNSAFE" ]; then
         echo "!! GRUB_CMDLINE_LINUX_DEFAULT contains a $UNSAFE; not rewriting it." >&2
         echo "   Add $MARKER by hand:" >&2
         echo "     $CUR" >&2
         FAILED=1
     elif [ ! -w "$GRUBDEF" ]; then
         echo "!! $GRUBDEF not writable; add $MARKER by hand." >&2
         FAILED=1
     else
         cp -a "$GRUBDEF" "$GRUBDEF.bak-$(date +%s)"
         NEW="$CUR${CUR:+ }$MARKER"
         TMP=$(mktemp)
         # Rewrite the first active assignment, drop later duplicates: NEW came
         # from sourcing, so it already reflects the last-wins value.
         awk -v val="$NEW" '
             /^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=/ {
                 if (!seen) { print "GRUB_CMDLINE_LINUX_DEFAULT=\"" val "\""; seen=1 }
                 next
             }
             { print }
             END { if (!seen) print "GRUB_CMDLINE_LINUX_DEFAULT=\"" val "\"" }
         ' "$GRUBDEF" > "$TMP"
         cat "$TMP" > "$GRUBDEF"      # preserves owner/mode
         rm -f "$TMP"
         echo "Set: GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW\"  (backup: $GRUBDEF.bak-*)"
     fi ;;
esac

# Neither generated entry inherits GRUB_CMDLINE_LINUX (10_linux's entries do).
if [ -n "$CUR_LINUX" ]; then
    echo
    echo "!! GRUB_CMDLINE_LINUX is set: $CUR_LINUX" >&2
    echo "   Neither Server nor Desktop inherits it — only Advanced options does." >&2
    echo "   If those params are needed to boot, re-run with:" >&2
    echo "     EXTRA_CMDLINE=\"$CUR_LINUX\" sh $0" >&2
    FAILED=1
fi
echo

if [ "$FAILED" -ne 0 ]; then
    echo "!! Steps above did not complete. Fix them BEFORE update-grub." >&2
    exit 1
fi

echo "Finish with:  update-grub"
echo "Menu: Debian GNU/Linux Server, Debian GNU/Linux Desktop, then Advanced"
echo "options (kernel rollback + recovery). os-prober/UEFI/fwupd may add more."
echo "Set GRUB_DEFAULT='gnulinux-server' or 'gnulinux-desktop' to choose."
