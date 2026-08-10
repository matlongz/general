#!/bin/sh
# make-grub-entries.sh — generate /etc/grub.d/08_desktop_server for THIS host
# from 08_desktop_server.template, substituting the live root filesystem UUID.
#
# Also configures the two things the Desktop side depends on, because both are
# easy to miss and each silently breaks something if skipped:
#   1. default.target = graphical.target  — the stock 10_linux "Debian GNU/Linux"
#      entry IS desktop mode; it boots default.target, so that must be graphical.
#   2. GRUB_CMDLINE_LINUX_DEFAULT gains boot_profile=desktop — marks the stock
#      entries for boot_profile.sh, so desktop mode does not rely on DEFAULT_MODE.
#
# Run as root, then update-grub (printed at the end).
#
# Requires: / and /boot on the same partition (template uses /vmlinuz symlinks).
set -e

TEMPLATE="${1:-$(dirname "$0")/08_desktop_server.template}"
[ -r "$TEMPLATE" ] || { echo "template not found: $TEMPLATE" >&2; exit 1; }

UUID=$(findmnt -no UUID /)
[ -n "$UUID" ] || { echo "could not determine root UUID" >&2; exit 1; }

FAILED=0   # set to 1 by any step that could not complete; exit status at the end

# Optional extra kernel params (e.g. hibernation: resume=UUID=... resume_offset=...).
# Trailing space so it slots cleanly before boot_profile= when non-empty.
EXTRA="${EXTRA_CMDLINE:-}"
[ -n "$EXTRA" ] && EXTRA="$EXTRA " || true

# Escape characters that are special on the REPLACEMENT side of sed (& means
# "the whole match", \ escapes, | is our delimiter). Without this, an
# EXTRA_CMDLINE containing any of them silently corrupts the generated entry.
esc_repl() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

sed -e "s|__ROOT_UUID__|$(esc_repl "$UUID")|g" \
    -e "s|__EXTRA_CMDLINE__|$(esc_repl "$EXTRA")|g" \
    "$TEMPLATE" > /etc/grub.d/08_desktop_server
chmod 755 /etc/grub.d/08_desktop_server
echo "Wrote /etc/grub.d/08_desktop_server (root UUID $UUID${EXTRA:+, extra: $EXTRA})"
echo

# ---- 0. stray generators in /etc/grub.d ------------------------------------
# grub-mkconfig executes EVERY executable file in /etc/grub.d, whatever it is
# named. A backup copy left there (cp -a preserves the +x bit!) keeps emitting
# its old menuentries: you get duplicate entries, a duplicate menuentry_id that
# makes GRUB_DEFAULT ambiguous, and — worst — a stale Desktop entry still
# pinning systemd.unit=, which silently re-breaks offline updates.
STRAY=$(find /etc/grub.d -maxdepth 1 -type f -perm -u+x \
        \( -name '*.bak' -o -name '*.bak-*' -o -name '*.orig' -o -name '*.old' \
           -o -name '*~' -o -name '*.save' -o -name '*.dpkg-*' -o -name '*.disabled' \) \
        2>/dev/null || true)
if [ -n "$STRAY" ]; then
    echo "!! EXECUTABLE backup/stray files in /etc/grub.d — grub-mkconfig WILL run these:" >&2
    printf '     %s\n' $STRAY >&2
    echo "   They emit duplicate menu entries and may still pin systemd.unit=." >&2
    echo "   Move them OUT of /etc/grub.d (chmod -x is not enough to be safe):" >&2
    for s in $STRAY; do echo "     mv $s /root/" >&2; done
    FAILED=1
fi

# 10_linux is a dpkg CONFFILE patched to suppress its top-level "simple" entry
# (this file provides Desktop instead). A grub-common upgrade can restore the
# maintainer's version, silently adding a third top-level entry that duplicates
# Desktop. Detect that rather than let it be discovered in the boot menu.
if [ -r /etc/grub.d/10_linux ]; then
    if grep -q 'LOCAL EDIT' /etc/grub.d/10_linux; then
        echo "10_linux: top-level 'simple' entry still suppressed (good)."
    else
        echo "!! /etc/grub.d/10_linux no longer carries the LOCAL EDIT patch." >&2
        echo "   Its top-level entry will reappear and duplicate the Desktop entry." >&2
        echo "   Likely cause: a grub-common upgrade replaced the conffile." >&2
        echo "   Re-comment the 'linux_entry \"\${OS}\" \"\${version}\" simple' call" >&2
        echo "   (guarded by: if [ \"x\$is_top_level\" = xtrue ] ...)." >&2
        FAILED=1
    fi
fi
echo

# ---- 1. default.target ----------------------------------------------------
# The Desktop side is 10_linux's stock entry, which boots default.target.
CURRENT_DEFAULT=$(systemctl get-default 2>/dev/null || echo unknown)
case "$CURRENT_DEFAULT" in
  graphical.target)
    echo "default.target already graphical.target — stock entry boots the GUI." ;;
  system-update.target)
    # /system-update is staged; the generator is redirecting. Not an error.
    echo "default.target resolves to system-update.target (an update is staged)."
    echo "  Leaving it alone; it reverts to graphical.target after the update runs." ;;
  *)
    echo "default.target is '$CURRENT_DEFAULT'; the stock Desktop entry boots default.target."
    if systemctl set-default graphical.target >/dev/null 2>&1; then
        echo "  -> set default.target = graphical.target"
    else
        echo "  !! could not set it; run: systemctl set-default graphical.target" >&2
        FAILED=1
    fi ;;
esac
echo

# ---- 2. boot_profile=desktop on the stock entries -------------------------
GRUBDEF=/etc/default/grub
MARKER=boot_profile=desktop

# Read the CURRENT values by sourcing the file, exactly as grub-mkconfig does.
# Parsing it with grep/sed instead would mishandle single-quoted and unquoted
# assignments: appending a fresh line in those cases makes the LAST assignment
# win when the file is sourced, silently discarding existing kernel args
# (splash, resume=, mitigations=, driver flags...). Sourcing avoids that class
# of bug entirely. Runs in a command substitution, so nothing leaks into here.
CUR=$( { . "$GRUBDEF"; printf '%s' "${GRUB_CMDLINE_LINUX_DEFAULT-}"; } 2>/dev/null ) || CUR=""
CUR_LINUX=$( { . "$GRUBDEF"; printf '%s' "${GRUB_CMDLINE_LINUX-}"; } 2>/dev/null ) || CUR_LINUX=""

case " $CUR " in
  *" $MARKER "*)  MARKER_STATE=present ;;
  *boot_profile=*) MARKER_STATE=conflict ;;
  *)              MARKER_STATE=absent ;;
esac

if [ ! -w "$GRUBDEF" ]; then
    echo "!! $GRUBDEF not writable; add $MARKER to GRUB_CMDLINE_LINUX_DEFAULT by hand" >&2
    FAILED=1
elif [ "$MARKER_STATE" = present ]; then
    echo "GRUB_CMDLINE_LINUX_DEFAULT already carries $MARKER."
elif [ "$MARKER_STATE" = conflict ]; then
    # A different boot_profile= is set — don't guess, the host may be intentionally odd.
    echo "!! GRUB_CMDLINE_LINUX_DEFAULT already sets a different boot_profile= value:" >&2
    echo "     $CUR" >&2
    echo "   Leaving it untouched — reconcile by hand." >&2
    FAILED=1
elif case "$CUR" in *'"'*) true ;; *) false ;; esac; then
    # A literal double quote in the value would break the rewrite below.
    echo "!! GRUB_CMDLINE_LINUX_DEFAULT contains a double quote; edit by hand:" >&2
    echo "     $CUR" >&2
    FAILED=1
else
    cp -a "$GRUBDEF" "$GRUBDEF.bak-$(date +%s)"
    NEW="$CUR${CUR:+ }$MARKER"
    # Rewrite the first active assignment and drop any later duplicates: NEW was
    # computed by sourcing, so it already reflects the last-wins value.
    TMP=$(mktemp)
    awk -v val="$NEW" '
        /^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=/ {
            if (!seen) { print "GRUB_CMDLINE_LINUX_DEFAULT=\"" val "\""; seen=1 }
            next
        }
        { print }
        END { if (!seen) print "GRUB_CMDLINE_LINUX_DEFAULT=\"" val "\"" }
    ' "$GRUBDEF" > "$TMP"
    cat "$TMP" > "$GRUBDEF"      # preserves owner/mode of the original
    rm -f "$TMP"
    echo "Set: GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW\""
    echo "  (backup: $GRUBDEF.bak-*)"
fi

# The Server entry is hand-written and does NOT inherit GRUB_CMDLINE_LINUX,
# which the stock entries do get. If this host needs params there, Desktop would
# boot and Server might not — so say so rather than let it be discovered at 3am.
if [ -n "$CUR_LINUX" ]; then
    echo
    echo "!! GRUB_CMDLINE_LINUX is set: $CUR_LINUX" >&2
    echo "   The stock (desktop) entries get it; the Server entry does NOT." >&2
    echo "   If those params are needed to boot, re-run with:" >&2
    echo "     EXTRA_CMDLINE=\"$CUR_LINUX\" sh $0" >&2
fi
echo

# ---- sanity: GRUB_DEFAULT must name an entry that still exists -------------
if grep -q "GRUB_DEFAULT=.*gnulinux-desktop" "$GRUBDEF" 2>/dev/null; then
    echo "!! GRUB_DEFAULT names 'gnulinux-desktop', which no longer exists." >&2
    echo "   Desktop mode is now 10_linux's stock entry. Use one of:" >&2
    echo "     GRUB_DEFAULT='gnulinux-server'   # boot CLI by default" >&2
    echo "     GRUB_DEFAULT=1                   # boot the stock (desktop) entry" >&2
fi

if [ "$FAILED" -ne 0 ]; then
    echo >&2
    echo "!! One or more steps did not complete (see !! lines above)." >&2
    echo "   Fix them BEFORE update-grub, or desktop boot / profile detection" >&2
    echo "   will be incomplete." >&2
    exit 1
fi

echo "Finish with:"
echo "  update-grub"
echo
echo "Menu will be: Server (this file), then the stock 'Debian GNU/Linux'"
echo "(= desktop) and its 'Advanced options' submenu for kernel rollback/recovery."
echo
echo "Note: on a PURE headless host with no GUI installed, skip the graphical"
echo "set-default above (systemctl set-default multi-user.target)."
