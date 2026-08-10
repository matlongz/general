#!/bin/sh
# /usr/local/sbin/boot_profile.sh [server|desktop]
# Apply a "server" or "desktop" runtime profile. Mode = optional arg, else the
# GRUB entry booted (boot_profile= on the kernel cmdline, or legacy
# systemd.unit=), else DEFAULT_MODE.
# Host-specific settings live in /etc/default/boot-profile. Reusable on any
# Debian host; nothing is permanently disabled (services only stopped/started).
# Re-run after a live target switch, e.g.:  sudo boot_profile.sh server

# ---- defaults (override in /etc/default/boot-profile) ----
DESKTOP_DAEMONS="bluetooth.service cups.service cups-browsed.service ModemManager.service"
SERVER_PROFILE="performance"
DESKTOP_PROFILE="balanced"
SERVER_STOP_EXTRA=""
DEFAULT_MODE="desktop"
[ -r /etc/default/boot-profile ] && . /etc/default/boot-profile

rc=0
log() { logger -t boot-profile "$1"; echo "boot-profile: $1"; }

# ---- determine mode (literal match, no regex) ----
# Priority: arg > boot_profile= > systemd.unit= (legacy) > DEFAULT_MODE.
# systemd.unit= is read for entries generated before boot_profile= existed.
# Recovery entries carry neither token and fall through to DEFAULT_MODE, which
# is harmless: boot-profile.service is WantedBy=multi-user.target and rescue
# mode does not pull it in.
MODE="$1"
if [ -z "$MODE" ]; then
    MODE="$DEFAULT_MODE"
    set -f                      # /proc/cmdline is unquoted below; don't glob it
    for tok in $(cat /proc/cmdline); do
        case "$tok" in
            systemd.unit=multi-user.target) MODE=server  ;;
            systemd.unit=graphical.target)  MODE=desktop ;;
        esac
    done
    for tok in $(cat /proc/cmdline); do    # second pass: boot_profile= wins
        case "$tok" in
            boot_profile=server)  MODE=server  ;;
            boot_profile=desktop) MODE=desktop ;;
        esac
    done
    set +f
fi

set_powerprofile() {   # $1 = profile name (via power-profiles-daemon if present)
    if ! command -v powerprofilesctl >/dev/null 2>&1; then
        log "power-profiles-daemon not installed; skipping CPU profile"; return
    fi
    if powerprofilesctl set "$1" 2>&1 | logger -t boot-profile; then
        log "power profile -> $1"
    else
        log "WARNING: 'powerprofilesctl set $1' failed (polkit/D-Bus?) — profile NOT changed"; rc=1
    fi
}

case "$MODE" in
  server)
    set_powerprofile "$SERVER_PROFILE"
    for u in $DESKTOP_DAEMONS $SERVER_STOP_EXTRA; do systemctl stop "$u" 2>/dev/null || true; done
    log "server profile applied"
    ;;
  desktop)
    set_powerprofile "$DESKTOP_PROFILE"
    for u in $DESKTOP_DAEMONS; do systemctl start "$u" 2>/dev/null || true; done
    log "desktop profile applied"
    ;;
  *)
    log "ERROR: unknown mode '$MODE' (expected server|desktop)"; exit 2 ;;
esac
exit $rc
