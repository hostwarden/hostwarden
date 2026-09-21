# OpenWrt

Base: none

OpenWrt is Linux, but no family file applies: its own package
manager and repositories, a busybox userland, procd instead of
systemd, and a configuration model, UCI, that generates the
services' own config files and overwrites them. It runs on routers
and access points with a few megabytes of flash.

**The router is everyone's way out.** A wrong firewall, network or
wireless change cuts off every device behind it, not just your SSH
session, and nobody can reach the internet to look up the fix. Ask
before every change in this file, say what the user loses if it
goes wrong, and make sure they can reach the device another way
(LAN cable, failsafe mode) before a network or firewall change.

Sources unless noted: the OpenWrt documentation,
<https://openwrt.org/docs/start>, and the `openwrt/openwrt` source
of the current release branch,
<https://github.com/openwrt/openwrt/tree/openwrt-25.12>.

## Access and Shell

- **root is the only account with a shell**; there is no `sudo`
  unless someone installed it. Connect as root
  (`rules/privilege-escalation.md` still decides what a command
  needs).
- The shell is busybox `ash`, the only one in `/etc/shells`. The
  probe's `ps` line fails here (`rules/busybox.md`); record
  `Shell: ash (root)` from root's entry in `/etc/passwd`.
- The SSH server is **dropbear**, not OpenSSH. Its settings are the
  UCI file `/etc/config/dropbear` (Port, Interface, PasswordAuth,
  RootPasswordAuth, RootLogin; one `dropbear` section per
  instance). Root's keys are in `/etc/dropbear/authorized_keys`,
  the host keys are `/etc/dropbear/dropbear_*_host_key`.
- **The SSH taboo in `AGENTS.md` covers dropbear**: its UCI file,
  `uci set`/`delete`/`commit` on `dropbear`, and all of
  `/etc/dropbear`. Read with `uci show dropbear` and `ls -l`,
  never change. A dropbear change the user wants is theirs to make,
  in LuCI (System > Administration) or on the console.
- Dropbear has no SFTP server. Copy with `scp -O` (legacy protocol);
  `rsync` is not installed by default.
- Recovery without the network: failsafe mode, entered with a
  button press during boot; see
  <https://openwrt.org/docs/guide-user/troubleshooting/failsafe_and_factory_reset>.

## Version Detection

- `cat /etc/openwrt_release`: `DISTRIB_RELEASE` (e.g. `25.12.5`,
  or `SNAPSHOT` for a development build), `DISTRIB_TARGET` (the
  hardware platform, e.g. `ath79/generic`) and `DISTRIB_ARCH` (the
  package architecture).
- `ubus call system board` adds the device: `model`, `board_name`,
  `rootfs_type`, and a `release` table with the same version.
- `/etc/os-release` has `ID="openwrt"` and `ID_LIKE="lede openwrt"`;
  the detection probe reads it.
- Hardware: the probe's `nproc` does not exist here. Count CPUs
  with `grep -c ^processor /proc/cpuinfo`, and take the device
  model from `ubus call system board`.
- Record in server memory:
  `Appliance: OpenWrt <version> (<target>, <model>)`.
- Releases, their support status and end-of-life dates:
  <https://openwrt.org/releases/start>, never from memory. A
  release past its end of life, or a snapshot build on a router
  that is supposed to be stable, is a finding.

## Configuration: UCI

- **Every setting lives in `/etc/config/<name>`** (`network`,
  `wireless`, `firewall`, `dhcp`, `system`, `dropbear` and one file
  per package that has one). Services generate their real config
  files from these, mostly into `/var/etc/` or `/tmp/`, which are
  RAM, and overwrite them on every start. Never edit a generated
  file; the change is gone at the next reload.
- **Change settings with `uci`**, not with an editor:
  - `uci show <config>` and `uci get <config>.<section>.<option>`
    read;
  - `uci set`, `add`, `add_list`, `del_list` and `delete` stage a
    change in `/tmp/.uci`;
  - `uci changes` shows what is staged, `uci revert <config>`
    drops it;
  - `uci commit <config>` writes it to flash.
  Always name the config on `commit`: a bare `uci commit` also
  writes whatever else is staged in `/tmp/.uci`. Run `uci changes`
  first; changes you did not stage are someone else's, so stop and
  ask.
- **Apply** with `reload_config`, which reloads each service whose
  config changed, or with the service's own `reload` (see Service
  Manager). A committed change that was never applied takes effect
  at the next reboot, unannounced.
- `rules/backups.md` applies to `/etc/config/<name>` before any
  change: a copy with `cp`, or `uci export <config>` into a file.
  Keep copies in `/root/hostwarden-backups/`; `/tmp` is RAM.
  `sysupgrade -b /tmp/backup-<date>.tar.gz` archives the whole
  configuration; copy it off the device with `scp -O` before a
  larger change.
- LuCI, the web UI, writes the same files through the same
  mechanism. Tell the user which menu shows a setting when they
  would rather make the change there.

## Package Manager

- **25.12 and later: `apk`** (apk-tools 3). 24.10 and earlier:
  `opkg`. `which apk opkg` shows which one the device has; use only
  that one.

  | Task             | apk                      | opkg                   |
  | ---------------- | ------------------------ | ---------------------- |
  | Refresh lists    | `apk update`             | `opkg update`          |
  | List upgradable  | `apk list --upgradeable` | `opkg list-upgradable` |
  | Installed        | `apk list --installed`   | `opkg list-installed`  |
  | Install          | `apk add <pkg>`          | `opkg install <pkg>`   |
  | Remove           | `apk del <pkg>`          | `opkg remove <pkg>`    |
  | Dry run          | `--simulate`             | `--noaction`           |
  | Owner of a file  | `apk info --who-owns`    | `opkg search`          |

  Source:
  <https://openwrt.org/docs/guide-user/additional-software/opkg-to-apk-cheatsheet>.
- Repositories: `/etc/apk/repositories.d/distfeeds.list` (apk),
  `/etc/opkg/distfeeds.conf` (opkg). Own feeds go into
  `customfeeds.list` or `customfeeds.conf`. A feed that is not
  `downloads.openwrt.org` is a third-party source (`AGENTS.md`:
  official repos only); report it, and ask before adding one.
- **Never upgrade all packages** (`apk upgrade`, or `opkg upgrade`
  over the whole list). OpenWrt warns that it may soft-brick the
  device: the package manager does not check ABI or kernel
  compatibility, and every upgraded package occupies flash a second
  time, beside its copy in `/rom`. Updates come as a new firmware
  image (see Updates). Upgrading a single package the user
  installed, after a dry run, is fine. Source:
  <https://openwrt.org/meta/infobox/upgrade_packages_warning>.
- Every installed package takes flash (see Flash and Overlay) and
  is lost at the next sysupgrade unless it is reinstalled or built
  into the image. Check free space before installing, and do not
  install a tool just to run a check (`rules/busybox.md`).
- Language runtimes (the `hostwarden-runtimes` skill) do not belong
  on a router.

## Updates

- **The update path is a new firmware image**, flashed with
  `sysupgrade`. It keeps the configuration by default (the files
  `sysupgrade -l` lists) and **reboots the device**, which takes the
  network down for everyone for minutes. Always ask.
- Where it is installed, **`owut`** (Attended Sysupgrade, shipped
  in images for devices with more flash) is the documented way:
  `owut check` lists what an upgrade would bring, read-only;
  `owut upgrade` builds an image with the installed packages
  included and flashes it. Source:
  <https://openwrt.org/docs/guide-user/installation/sysupgrade.owut>.
  The LuCI Attended Sysupgrade app does the same from the web UI.
- Without `owut`: the user downloads the sysupgrade image for the
  device from <https://firmware-selector.openwrt.org/>. Check it
  with `sysupgrade -T <image>` (tests image and kept configuration,
  flashes nothing), then flash with `sysupgrade -v <image>`. Every
  package installed after the fact has to be reinstalled afterwards.
  `sysupgrade -k` stores the package list in the backup.
- Never flash with `-n` (discards the configuration), `-F` (skips
  the image check) or an image for another device, and never skip a
  major release without reading its release notes first.
- `firstboot`, `jffs2reset` and `factoryreset` erase all settings
  and packages: a factory reset. Never.

## Automatic Security Updates

- OpenWrt ships no automatic update mechanism, and a missing one is
  not a finding. Pending firmware updates are (`owut check`, or the
  version against the release page).
- Do not set one up with cron: an unattended sysupgrade reboots the
  network for everyone, and an unattended mass package upgrade is
  what the Package Manager section rules out.

## Firewall

- **Expected:** firewall4 (`fw4`) on nftables, configured in
  `/etc/config/firewall`: zones (`lan`, `wan`, and any the user
  added), with the default `wan` zone rejecting input and dropping
  forwarded traffic, and forwarding allowed from `lan` to `wan`.
  Source:
  <https://openwrt.org/docs/guide-user/firewall/firewall_configuration>.
- Read-only: `uci show firewall`, `fw4 print` (the ruleset fw4
  would load), `nft list ruleset` (the ruleset that is loaded).
- **Change rules through UCI** (`uci add firewall rule`, …, see
  Configuration: UCI), never with `nft` directly: the next reload
  replaces the whole ruleset. Own nftables snippets go into
  `/etc/nftables.d/*.nft`, which fw4 includes.
- Before applying: `fw4 check` renders the ruleset and tests it
  with nftables without loading it. It must pass. Then
  `service firewall reload`. There is no timed rollback; the check
  is the only safety net before the change is live.
- **Keep every SSH port open from where the user connects.** Read
  every dropbear instance's `Port` and `Interface`
  (`uci show dropbear`) and what actually listens
  (`netstat -tlnp`). Dropbear binds every address unless
  `Interface` is set; the `wan` zone's input policy is what keeps it
  off the internet. A rule that opens SSH on `wan` is a finding;
  ask before adding one.

## Service Manager

- procd. `service` with no arguments lists every init script,
  enabled or disabled, running or stopped.
- `service <name> reload|restart|start|stop|status`, or
  `/etc/init.d/<name>` with the same verbs;
  `enable`/`disable`/`enabled` control the start at boot.
  `rules/service-reload.md` decides when to ask.
- `service network restart` takes every interface down and up,
  `wifi` every radio: everyone on them loses the connection, and a
  wrong change keeps it down. Ask first, every time.
- Cron: busybox `crond`, jobs in `/etc/crontabs/root`
  (`crontab -l`); `service cron restart` after a change. The init
  script does not start cron while `/etc/crontabs/` is empty.
- Time: `sysntpd` (busybox `ntpd`), servers in
  `uci show system.ntp`.

## Flash and Overlay

- `/rom` is the read-only firmware (squashfs), `/overlay` the
  writable part (JFFS2 or UBIFS) on top of it; `/` is the two
  merged. Free flash: `df -h /overlay`. A few hundred kilobytes is
  normal on a small device; watch the trend, not the percentage.
- **A full overlay is remounted read-only**, and then nothing can
  be saved, UCI commits included:
  `grep " overlay ro," /proc/mounts` finds it.
- `/tmp` (and `/var`, which links to it) is RAM. Nothing written
  there survives a reboot, and a large file there takes memory from
  the router.
- Extroot (the overlay on a USB stick) moves the writable part off
  the flash; `df -h /overlay` then shows the stick.

## Logs

- `logread` reads logd, a ring buffer in RAM: 128 KiB by default
  (`log_size` in `uci show system`). It is lost at every reboot,
  and on a busy router it rotates within hours. `logread -l <n>`
  shows the last lines. Never use `logread -f` over
  non-interactive SSH: it does not exit.
- A persistent log exists only where the user set `log_file` to
  storage that survives a reboot, or `log_ip` to a remote syslog
  server.
- `logger -t hostwarden` reaches logd. The activity check reads it
  back with:
  ```
  logread | grep -E "hostwarden|heinzel" | tail -20
  ```
  An empty result covers only the time since the last reboot or
  the start of the buffer, whichever is shorter; say so, and read
  the local changelog for older sessions.

## Housekeeping and Audits

- The Linux baseline does not apply: no systemd, no journal, no
  `apt`. Housekeeping reads, in one call:
  ```
  cat /etc/openwrt_release; uptime; free; df -Ph /overlay /tmp
  grep " overlay ro," /proc/mounts; service; uci changes
  logread -l 50
  ```
  plus `owut check` where it exists, or `apk list --upgradeable` /
  `opkg list-upgradable` after refreshing the lists (reported, not
  applied: see Package Manager). Findings: pending firmware update,
  a release past its end of life, overlay nearly full or read-only,
  uncommitted UCI changes, a service disabled or stopped that should
  run, errors in the log.
- A security audit reports instead of the `sshd` checks:
  - dropbear's `PasswordAuth`, `RootPasswordAuth` and `Interface`
    per instance (`uci show dropbear`); password login from `wan`
    is CRITICAL;
  - whether root has a password at all:
    `grep -c "^root::" /etc/shadow` prints `1` when it has none,
    which is CRITICAL (OpenWrt ships that way until the user sets
    one), and never print the file itself;
  - the firewall zones, their input policies and every rule that
    accepts traffic on `wan` (`uci show firewall`);
  - LuCI and other services listening on `wan` (`netstat -tlnp`
    against the zones);
  - package feeds other than `downloads.openwrt.org`.

  The unowned-files check cannot run here: busybox `find` has no
  `-nouser`, and the Alpine variant needs `stat`, which the build
  leaves out (`rules/busybox.md`). Report it as skipped.

  A router forwards traffic by design: `net.ipv4.ip_forward=1` is
  expected here, not a finding.
- Fleet audit: compare OpenWrt devices only with each other. A
  missing `unattended-upgrades`, `sshd -T` or `systemctl` is not
  drift.
