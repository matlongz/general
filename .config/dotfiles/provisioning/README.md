# Debian Server/Desktop Provisioning Kit

Reusable configs + scripts for provisioning a **Debian 13 (trixie)** machine that
can boot as either a **GUI desktop** or a lean **headless server** (e.g. for
`kind` / Kubernetes load testing), selectable from the GRUB menu, with a runtime
profile applied automatically per mode.

Tested on: `tars` (Ryzen 7 5700U, 28 GB) and `kipp` (Core m3, MacBook). All
components are host-agnostic; per-host differences live in **`/etc/default/boot-profile`**
and the GRUB UUID (generated per host).

> ### ⚠️ Read before running any of this on a machine you care about
>
> This is **not** a copy-and-run quickstart. It makes machine-level changes —
> rewrites GRUB entries, changes `default.target`, raises kernel and PAM
> limits — tuned for the two hosts above. Adapt it; don't
> assume it fits.
>
> Read each section before applying it. In particular the GRUB step assumes:
> **`/` and `/boot` on the same partition** (entries use the `/vmlinuz` symlink),
> an unencrypted boot, a GNOME desktop present for "desktop" mode, and no unusual
> kernel arguments. On an encrypted-boot, separate-`/boot`, or non-GNOME system
> the GRUB section needs changing before it will do the right thing — a wrong
> entry here can leave a machine unbootable. Keep the stock `10_linux` entries
> ("Advanced options") as your recovery path, and know how to reach them.
>
> The load-test tuning is sized for a **single-user** load-test box (see the
> caveats in that section). The rest — boot profile, console auto-logout — is
> low-risk and reversible.

---

## Components

| Path | Installs to | Purpose | Host-specific? |
|---|---|---|---|
| `boot-profile/boot_profile.sh` | `/usr/local/sbin/boot_profile.sh` | Applies server/desktop runtime profile (CPU + daemons) based on boot mode | No |
| `boot-profile/boot-profile.service` | `/etc/systemd/system/` | Runs `boot_profile.sh` once at boot | No |
| `boot-profile/49-boot-profile-powerprofiles.rules` | `/etc/polkit-1/rules.d/` | Allows **any root process** (not just this oneshot) to switch power profiles without a prompt. No escalation — root can do this anyway — but it is not scoped to the service | No |
| `boot-profile/boot-profile.conf` | `/etc/default/boot-profile` | **Per-host** knobs (daemons, profiles, extra stops, default mode) | **Yes — edit** |
| `load-test/99-kind-loadtest.conf` | `/etc/sysctl.d/` | Kernel tuning for kind + host-side load generators | No |
| `load-test/99-loadtest-limits.conf` | `/etc/security/limits.d/` | Raises `nofile` for login/SSH sessions | No |
| `console/console_autologout.sh` | `/etc/profile.d/console_autologout.sh` | Auto-logout idle **physical console** sessions (not SSH) | No |
| `grub/08_desktop_server.template` | (generated) | Template for BOTH top-level GRUB entries (Server + Desktop) | UUID substituted |
| `grub/make-grub-entries.sh` | (run once) | Generates `/etc/grub.d/08_desktop_server` and sets `default.target=graphical.target` | — |

---

## Prerequisites

- Debian 12/13 with systemd and GRUB.
- **Boot-mode switching** needs the two GRUB entries (see step 1), and assumes
  `/` and `/boot` are on the **same partition** (they use `/vmlinuz` symlinks).
- `/etc/grub.d/10_linux` must be patched to suppress its top-level "simple"
  entry (search it for `LOCAL EDIT`), or you get a third entry duplicating
  Desktop. It is a dpkg conffile — keep your version on `grub-common` upgrades.
  Do **not** disable `10_linux` outright: its "Advanced options" submenu is the
  only way to boot an older kernel or recovery mode.
- `power-profiles-daemon` is **optional** — `boot_profile.sh` skips the CPU step
  if it's absent.
- **Load testing** additionally needs `docker`, `kind`, `kubectl`, and the user
  in the `docker` group. Point Docker's `data-root` at your largest/fastest disk
  via `/etc/docker/daemon.json` (`"data-root": "/mnt/data/docker"`) — kind stores
  node containers + images there.

---

## Install (run as root on the target host)

Lives in the `matlongz/general` dotfiles repo (bare repo, `$HOME` as work-tree),
so on a provisioned host it is already checked out at
`~/.config/dotfiles/provisioning` — inside the `.config/dotfiles/` sparse-checkout
pattern, so it lands on both the workstation and server profiles.

```sh
cd ~/.config/dotfiles/provisioning

# 1. GRUB Server + Desktop menu entries (per-host UUID)
sudo sh grub/make-grub-entries.sh
#   ^ also sets default.target=graphical.target (Desktop boots default.target).
#     Checks preconditions BEFORE writing and exits non-zero without changing
#     anything if they fail — check the exit status before update-grub.
#     Does not modify /etc/default/grub.
#
#     Extra kernel params for these two entries go via EXTRA_CMDLINE (they do
#     NOT inherit GRUB_CMDLINE_LINUX):
#       sudo EXTRA_CMDLINE="resume=UUID=<fs> resume_offset=<N>" sh grub/make-grub-entries.sh
#     The value is recorded as a '# EXTRA_CMDLINE=' line in the generated file,
#     and a later run without it is refused rather than silently dropping it.
sudo sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT='gnulinux-server'/" /etc/default/grub  # or 'gnulinux-desktop'
sudo update-grub
# Menu: "Debian GNU/Linux Server (CLI)", "Debian GNU/Linux Desktop (Gnome)",
# then "Advanced options" (kernel rollback + recovery) from the patched 10_linux.
# (optional: match boot resolution)  add to /etc/default/grub:
#   GRUB_GFXMODE=1920x1080 ; GRUB_GFXPAYLOAD_LINUX=keep ; then update-grub

# 2. Per-mode boot profile
sudo install -m755 boot-profile/boot_profile.sh /usr/local/sbin/boot_profile.sh
sudo install -m644 boot-profile/boot-profile.service /etc/systemd/system/boot-profile.service
sudo install -m644 boot-profile/49-boot-profile-powerprofiles.rules /etc/polkit-1/rules.d/49-boot-profile-powerprofiles.rules
sudo install -m644 boot-profile/boot-profile.conf /etc/default/boot-profile
sudoedit /etc/default/boot-profile     # tune for this host (see "Per-host config")
sudo systemctl daemon-reload
sudo systemctl enable --now boot-profile.service

# 3. Load-test kernel tuning (harmless on desktop; skip if not a test box)
sudo install -m644 load-test/99-kind-loadtest.conf /etc/sysctl.d/99-kind-loadtest.conf
sudo install -m644 load-test/99-loadtest-limits.conf /etc/security/limits.d/99-loadtest.conf
sudo sysctl --system

# 4. Console idle auto-logout (optional security)
sudo install -m644 console/console_autologout.sh /etc/profile.d/console_autologout.sh
```

Reconnect your SSH session after step 3 so the new `nofile` soft limit applies.

---

## Per-host config: `/etc/default/boot-profile`

| Variable | Meaning |
|---|---|
| `DESKTOP_DAEMONS` | Units stopped in **server** mode / started in **desktop** mode (space-separated). Trim to what the host has. |
| `SERVER_PROFILE` / `DESKTOP_PROFILE` | power-profiles-daemon profile per mode (`powerprofilesctl list`). |
| `SERVER_STOP_EXTRA` | Extra units to stop **only** in server mode — e.g. a data stack to pause during load tests: `SERVER_STOP_EXTRA="postgresql.service"`. |
| `DEFAULT_MODE` | Mode when the cmdline carries neither `boot_profile=` nor `systemd.unit=`. The Server and Desktop entries carry a marker; **`10_linux`'s Advanced options entries do not**, so this decides those. Recovery entries never run the service at all (`WantedBy=multi-user.target`, and rescue does not pull it in). Set `"server"` on a headless box with no Desktop entry. |

Apply a mode change live without reboot: `sudo boot_profile.sh server` (or `desktop`).

---

## Verify

```sh
# boot profile
systemctl status boot-profile.service            # active (exited), Result=success
sudo journalctl -t boot-profile -b               # "power profile -> ..." / "... profile applied"
powerprofilesctl get                             # server->performance, desktop->balanced
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# kernel tuning
cat /proc/sys/fs/inotify/max_user_watches /proc/sys/fs/inotify/max_user_instances
ulimit -Sn ; ulimit -Hn                          # 65536 / 1048576 in a fresh login

# grub menu
# Any executable file in /etc/grub.d is a generator, whatever its name — a
# backup copy (cp -a keeps +x) keeps emitting its entries. Expect only NN_name:
ls -l /etc/grub.d/ | grep -vE '^total|README'
grep -lE 'gnulinux-(server|desktop)' /etc/grub.d/*   # only 08_desktop_server
# 10_linux must not emit its own top-level entry (would duplicate Desktop).
# Test the code, not the LOCAL EDIT comment — a conffile merge can keep the
# comment and restore the call:
grep -nE '^[[:space:]]*linux_entry[^#]*[[:space:]]simple([[:space:]]|\\|$)' /etc/grub.d/10_linux
#   no match = suppressed (same expression make-grub-entries.sh uses)

sudo grep -E "^\s*(menuentry|submenu)" /boot/grub/grub.cfg
#   expect: Server, Desktop, "Advanced options" submenu (+ os-prober / UEFI
#   firmware / fwupd entries, which are normal)
sudo grep -E "^\s+linux\s" /boot/grub/grub.cfg   # Desktop: NO systemd.unit=; Server: multi-user.target
systemctl get-default                            # graphical.target (Desktop relies on this)
grep -o 'boot_profile=[a-z]*' /proc/cmdline      # matches the entry you booted

# offline system updates reach the installer (Desktop mode)
pkcon offline-get-prepared                       # what is staged, if anything
ls -l /system-update                             # after `pkcon offline-trigger`: symlink to
                                                 # prepared-update. THIS is the deterministic
                                                 # check — `systemctl get-default` may or may not
                                                 # report system-update.target on a running
                                                 # system, since the redirect is a boot-time
                                                 # generator, so don't rely on it.
pkcon offline-status                             # after an update reboot: a real result,
                                                 # NOT "no update results available"
journalctl -u packagekit-offline-update.service -b -1   # non-empty = the installer actually ran
```

---

## Why the tuning values are what they are

- **inotify (`fs.inotify.max_user_watches=1048576`, `max_user_instances=8192`)** —
  the #1 kind scaling bottleneck; low values cause `too many open files` and stuck
  pods. kind's official minimum is `524288 / 512`; OpenShift/kops use `8192`
  instances. These are **global (per-UID) and DO reach kind containers.**
  Refs: kind known-issues, OpenShift/kops sysctl guidance.
- **`net.*` (somaxconn, port range, backlogs, tcp_tw_reuse, arp gc_thresh)** —
  these are **network-namespace-scoped**, so they tune the **HOST only**, not the
  inside of kind pods (containers get a fresh netns). Useful for host-side load
  generators (k6/wrk/hey). For **in-pod** sysctls, use a kind cluster config with
  `sysctls:` — the host file does not propagate. `tcp_tw_reuse=1` is safe
  (outbound side); never use the removed `tcp_tw_recycle`.
- **`ip_local_port_range=15000 65535` + `ip_local_reserved_ports=30000-32767`** —
  wide ephemeral range for connection-heavy tests, but the reservation protects
  the Kubernetes **NodePort** band so the host can't transiently steal a port
  kind/docker needs to bind.
  ⚠️ `ip_local_reserved_ports` is a **single global list, not additive**. If this
  host already reserves ports for other software, `sysctl --system` will silently
  replace those reservations. Check `sysctl net.ipv4.ip_local_reserved_ports`
  first and merge the ranges rather than overwriting.
- **`nofile` soft=65536 / hard=1048576** — modest **soft** avoids slow
  fd-closing loops in some software (a 1M soft limit is a footgun); programs raise
  their own soft up to hard when needed. `hard=1048576` == Debian's default
  `fs.nr_open` ceiling; to go higher, raise `fs.nr_open` in the sysctl file.
  Scope: `limits.d` is **PAM-only** (login/ssh/su/cron) — it does **not** affect
  systemd services or Docker/containerd (Docker's unit already grants 524288).
  For a load generator run **under systemd**, set `LimitNOFILE=` on its unit or
  `DefaultLimitNOFILE=` in `/etc/systemd/system.conf`.
  ⚠️ These limits (and the raised inotify counts) apply to **every** PAM login,
  not just yours. That's fine on a single-user box; on a shared or
  untrusted-login host it hands a compromised account more room to exhaust
  kernel memory and the file table. Scope it per-user (`@group` or a username
  instead of `*`) if the machine isn't yours alone.
- **CPU: `performance` governor + EPP=`performance` (server)** — on `amd-pstate-epp`
  this pins max sustained clocks and biases to performance under load. Driven via
  `power-profiles-daemon` so desktop can drop back to `balanced`. The polkit rule
  lets the root boot service switch profiles without an interactive session.
- **boot-profile design** — `Type=oneshot`+`RemainAfterExit=yes`,
  `WantedBy=multi-user.target` (runs in BOTH modes since graphical pulls in
  multi-user); mode read from `/proc/cmdline` (`boot_profile=`, with legacy
  `systemd.unit=` still honoured). Reversible (stop/start only, never
  disable/mask). Runtime `systemctl isolate` does NOT re-apply — re-run
  `boot_profile.sh <mode>` manually if you switch live.

- **Why Desktop must not pin `systemd.unit=`**

  Pinning `systemd.unit=` on the kernel cmdline makes systemd boot that unit
  **directly and never resolve `default.target`**. PackageKit/GNOME Software
  offline updates work *only* through `default.target`:
  `systemd-system-update-generator` redirects
  `default.target -> system-update.target` when `/system-update` exists. A pinned
  `systemd.unit=` bypasses that redirect, so staged updates never install — the
  box reboots, skips the update, and Software still shows them pending. There is
  **no error message anywhere**, because `packagekit-offline-update.service`
  never runs at all (`journalctl -u packagekit-offline-update.service` is empty
  across every boot, and `pkcon offline-status` says "no update results
  available"). Symptom presents as "updates fail no matter how many times I
  restart".

  **Both top-level entries come from this kit**, and `10_linux` is locally
  patched to comment out its own top-level "simple" entry (search it for
  `LOCAL EDIT`) so it contributes only the "Advanced options" submenu. Without
  that patch there would be a third top-level entry duplicating Desktop.

  ⚠️ `/etc/grub.d/10_linux` is a dpkg **conffile**. A `grub-common` upgrade will
  ask whether to keep your patched version; taking the maintainer's version
  silently restores the duplicate. `make-grub-entries.sh` checks for the patch
  and fails loudly if it has gone.

  Trade-off worth knowing: both entries here follow the `/vmlinuz` symlink, so a
  half-finished kernel postinst that leaves it dangling makes *both*
  unbootable. "Advanced options" is the mitigation — its entries use versioned
  paths (`/boot/vmlinuz-<ver>`) and include recovery mode. **Never disable
  `10_linux` entirely**; it is the recovery path.

  The Server entry keeps its pin deliberately: headless hosts don't run GNOME
  Software, and pinning `multi-user.target` is what makes Server mean server.
  Consequence: **offline updates apply in Desktop mode only.** `unattended-upgrades`
  still handles security updates in both modes.

  Mode detection uses a separate `boot_profile=` token, so the boot target and
  the runtime profile are independent. Server and Desktop carry it directly.
  `10_linux`'s Advanced options entries carry no marker and fall back to
  `DEFAULT_MODE` — which is why the kit does not touch
  `GRUB_CMDLINE_LINUX_DEFAULT` to inject one: that rewrite has to parse sourced
  shell, and getting it wrong corrupts the file `grub-mkconfig` reads.

---

## Revert / uninstall

```sh
sudo systemctl disable --now boot-profile.service
sudo rm /usr/local/sbin/boot_profile.sh /etc/systemd/system/boot-profile.service \
        /etc/polkit-1/rules.d/49-boot-profile-powerprofiles.rules /etc/default/boot-profile \
        /etc/sysctl.d/99-kind-loadtest.conf /etc/security/limits.d/99-loadtest.conf \
        /etc/profile.d/console_autologout.sh /etc/grub.d/08_desktop_server
sudo systemctl daemon-reload ; sudo sysctl --system
sudo sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/" /etc/default/grub   # was 'gnulinux-server'
sudo systemctl set-default graphical.target   # if you changed it
sudo update-grub
# restore any daemons stopped by the last server-mode run:
sudo systemctl start bluetooth cups ModemManager
```

---

## Not included here (host/desktop-specific, documented separately)

- `keyd` macOS-style keyboard mapping (`~/keyd-default.conf`) — desktop ergonomics, not server provisioning.
- Docker `daemon.json` `data-root` relocation — set per host to your data disk.
- GNOME desktop settings (dash-to-dock, idle lock, prompt) — desktop-only.
