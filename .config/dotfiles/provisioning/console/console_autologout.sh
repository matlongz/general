# /etc/profile.d/console_autologout.sh
#
# PURPOSE
#   Auto-logout idle shells on the PHYSICAL text consoles (tty1-tty6) after
#   15 minutes of inactivity at the prompt. Drops back to the login prompt, so
#   a password is required to log back in.
#
# SCOPE
#   Scoped to real consoles only. SSH sessions and terminal emulators run on a
#   pseudo-terminal (/dev/pts/*), which does NOT match /dev/tty[0-9]*, so they
#   are never affected (verified). This means SSH, Claude Code, and GNOME
#   Terminal keep working with no timeout.
#
# INSTALL
#   sudo cp ~/console_autologout.sh /etc/profile.d/console_autologout.sh
#   sudo chmod 644 /etc/profile.d/console_autologout.sh
#   # effective at the next console login
#
# REMOVE
#   sudo rm /etc/profile.d/console_autologout.sh
#
# NOTES
#   * The  [ -z "$TMOUT" ]  guard avoids the "bash: TMOUT: readonly variable"
#     error that occurs if /etc/profile is re-sourced in the same shell
#     (su, sudo -i, etc.) after TMOUT was made readonly.
#   * TMOUT=900 is exactly the CIS ceiling (<= 900 seconds and != 0).
#   * TMOUT only counts idle time at the prompt; it does not interrupt a
#     running foreground command.
#   * The filename just needs a .sh extension to be sourced by /etc/profile;
#     hyphen vs underscore in the name makes no functional difference.
case "$(tty 2>/dev/null)" in
    /dev/tty[0-9]*)
        if [ -z "${TMOUT:-}" ]; then
            TMOUT=900
            readonly TMOUT
            export TMOUT
        fi
        ;;
esac
