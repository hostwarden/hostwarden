# OpenWrt

Base: none
Hardware: any

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
- The shell is busybox `ash`, the only one in `/etc/shells`.
- The SSH server is **dropbear**, not OpenSSH, and under the SSH
  taboo in `AGENTS.md`. Its settings are the UCI file
  `/etc/config/dropbear` (Port, Interface, PasswordAuth,
  RootPasswordAuth, RootLogin; one `dropbear` section per
  instance); `/etc/dropbear` holds root's `authorized_keys` and the
  host keys. Read with `uci show dropbear` and `ls -l`, never
  change: a dropbear change is the user's to make, in LuCI
  (System > Administration) or on the console.
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
- The device model comes from `ubus call system board`, not from
  the probe's `/proc/cpuinfo` line.
- Read these in one call, together with which package manager the
  device has (see Package Manager):
  ```
  cat /etc/openwrt_release; ubus call system board; which apk opkg owut
  ```
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
  files from these, mostly into `/var/etc/` or `/tmp/`, and
  overwrite them on every start. Never edit a generated
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
  The backup directory is `/root/hostwarden-backups/`.
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
  flashes nothing), then flash with `sysupgrade -v <image>`.
  `sysupgrade -k` stores the list of installed packages in the
  backup, for reinstalling them afterwards.
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
- Apply a firewall change, and a change to `/etc/config/network`,
  through `rules/ssh-safety-net.md`. Its three commands here:
  - **check:** stage the change with `uci`, then `fw4 check`, which
    renders the ruleset, staged changes included, and tests it with
    nftables without loading it. A failed check means
    `uci revert firewall`, so the broken ruleset never reaches
    flash. For the network there is no check beyond `uci changes`.
  - **apply:** `uci commit firewall; service firewall reload`
    (`uci commit network; service network reload` for the
    network).
  - **revert:** copy the backup of the config file back over it and
    run the same reload, or `service firewall stop` where no
    `inet fw4` table was loaded before. Loaded rules against the
    files: `nft list table inet fw4` and `fw4 print`.

  OpenWrt has no systemd and ships no `at`. The `at` package from
  the feed arms the revert (ask first: it takes flash, see Package
  Manager); without it, the change is the user's, with console
  access ready. rpcd's own timed rollback (`uci apply` with
  `rollback`, then `uci confirm` over ubus) covers only changes
  staged in an rpcd session, not those made with the `uci` command;
  it is what LuCI's Save & Apply uses, so a user without `at` can
  make the change there. Source:
  <https://github.com/openwrt/rpcd/blob/master/uci.c>.
- **Keep every SSH port open from where the user connects.** Read
  every dropbear instance's `Port` and `Interface`
  (`uci show dropbear`) and what actually listens
  (`netstat -tlnp`). Dropbear binds every address unless
  `Interface` is set; the `wan` zone's input policy is what keeps it
  off the internet. A rule that opens SSH on `wan` is a finding;
  ask before adding one.

## Service Manager

- procd. `service` with no arguments lists every init script,
  enabled or disabled (its `enabled` verb), running or stopped
  (procd's instance state over `ubus call service list`). Source:
  procd's `/sbin/service`,
  <https://github.com/openwrt/openwrt/blob/openwrt-25.12/package/system/procd/files/service>.
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
- **A full overlay leaves `/` read-only**, and then nothing can
  be saved, UCI commits included. It is the root entry that turns
  `ro` — mount point `/`, type `overlay` — which
  `grep -F "/ overlay ro," /proc/mounts` finds; OpenWrt's own
  `/etc/profile` warns on the same test. Source:
  <https://github.com/openwrt/openwrt/blob/openwrt-25.12/package/base-files/files/etc/profile>.
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
  logread | head -1
  ```
  The second line is the oldest entry the buffer still holds
  (`rules/activity-check.md` → How far back it reached); it is
  never older than the boot, and on a busy router much younger.
  Its timestamp carries the year.

## Housekeeping and Audits

- The Linux baseline does not apply: no systemd, no journal, no
  `apt`. Housekeeping reads, in one call:
  ```
  cat /etc/openwrt_release; uptime; free; df -Ph /overlay /tmp
  grep -F "/ overlay ro," /proc/mounts; service; uci changes
  logread -l 50; owut check
  nft list chain inet fw4 input | grep -E "policy|jump (input_|handle_)"
  nft list table inet fw4 | grep -E "jump (accept|reject|drop)_from_"
  awk '$2=="00000000" && $8=="00000000" {print $1}' /proc/net/route
  awk '$1~/^0+$/ && $2=="00" && $10!="lo" {print $10}' /proc/net/ipv6_route
  ```
  Where `owut` does not exist, list upgradable packages instead
  (`apk list --upgradeable` or `opkg list-upgradable`, after
  refreshing the lists), reported and not applied (see Package
  Manager). Judge the firewall from the loaded ruleset, not from
  UCI, which can hold a committed change fw4 has not loaded. No
  `inet fw4` table is **CRITICAL** "No active firewall". The
  uplinks are the devices of every IPv4 and IPv6 default route,
  or, where there is none, the `wan` zone's devices. The `input` chain
  sends each device to its zone with `iifname … jump input_<zone>`
  (`*` is a wildcard); the `jump <verdict>_from_<zone>` that ends
  the zone's chain is its policy, and a device no rule names gets
  the `input` chain's own. `accept` for any uplink is **CRITICAL**
  "WAN input open". fw4 ships `REJECT` in `@defaults` and on the
  `wan` zone. Other findings: pending firmware update, a release
  past its end of life, overlay nearly full or read-only,
  uncommitted UCI changes, a service disabled or stopped that should
  run, errors in the log. Sources:
  <https://github.com/openwrt/firewall4/blob/master/root/usr/share/firewall4/templates/ruleset.uc>,
  <https://github.com/openwrt/firewall4/blob/master/root/etc/config/firewall>.
- A security audit reads, in one call, instead of the `sshd`
  checks:
  ```
  uci show dropbear; uci show firewall; netstat -tlnp
  cat /etc/apk/repositories.d/*.list /etc/opkg/*.conf
  ```
  and reports:
  - dropbear's `PasswordAuth`, `RootPasswordAuth` and `Interface`
    per instance; password login from `wan` is CRITICAL;
  - the firewall zones, their input policies and every rule that
    accepts traffic on `wan`;
  - LuCI and other services listening on `wan` (`netstat` against
    the zones);
  - package feeds other than `downloads.openwrt.org`.

  The empty-password check applies as it stands, and finds root
  until the user sets a password: OpenWrt ships without one. The
  unowned-files check is skipped (its **OpenWrt** line). A router
  forwards traffic by design: `net.ipv4.ip_forward=1` is expected
  here, not a finding.
- Fleet audit: a missing `unattended-upgrades`, `sshd -T` or
  `systemctl` is not drift.
