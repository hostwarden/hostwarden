# Unraid

Base: none

Unraid is a NAS and virtualisation host built on Slackware, and no
family file applies: no package manager for the user, a root file
system that lives in RAM, and a configuration model of its own. The
OS boots from a boot device — a USB flash drive, or since 7.3 an
internal boot pool — and loads into memory. **Only `/boot` and the
storage under `/mnt` survive a reboot**; a change anywhere else is
gone at the next boot. Where `AGENTS.md` or a baseline expects
something a Linux server has (a package manager, a firewall,
automatic updates, `sudo`), this file says what to check instead.

Sources unless noted: the Unraid documentation,
<https://docs.unraid.net/>, and the `unraid/webgui` and `unraid/api`
repositories on GitHub where the docs are silent.

## Version Detection

- `/etc/unraid-version` holds one line, `version="<version>"`
  (`unraid/api`, `get-unraid-version-sync.ts`). Step 1 of
  `rules/os-detection.md` prints it; later connections read it with
  `cat /etc/unraid-version`.
- Releases come as Stable, Release Candidate (`-rc.<n>`) and Beta
  (`-beta.<n>`)
  (<https://docs.unraid.net/unraid-os/updating-unraid/release-types/>).
  A production server on an RC or beta is a finding.
- Record in server memory: `Appliance: Unraid <version>`, and the
  boot device, `USB flash` or `internal boot pool`, from the source
  `df -h /boot` shows.

## Access and Privileges

- **root is the only login.** Users created under Users are share
  users, who "don't have access to the WebGUI, SSH, or Telnet"
  (<https://docs.unraid.net/unraid-os/system-administration/secure-your-server/user-management/>).
  Every session runs as root, so the least-privilege care
  `AGENTS.md` asks of commands is the only limit.
- SSH is off by default. It is switched on, and its port set, under
  Settings → Management Access; the values are stored in
  `/boot/config/ident.cfg` (`USE_SSH`, `PORTSSH`), and
  `/etc/rc.d/rc.sshd` writes the port and listen addresses into
  `/etc/ssh/sshd_config` at every start (`unraid/webgui`,
  `etc/rc.d/rc.sshd`). The same page offers Telnet; Telnet on is a
  finding.
- **SSH files persist under `/boot/config/ssh/`.** At every start,
  `rc.sshd` copies the files in that directory, not its
  subdirectories, into `/etc/ssh`: the host keys, and an
  `sshd_config` if one was put there. `/root/.ssh` is a symlink to
  `/boot/config/ssh/root`, which holds root's `authorized_keys`
  (<https://docs.unraid.net/unraid-os/release-notes/6.9.0/>). The
  root user's page in the web UI edits the same keys. The SSH taboo
  in `AGENTS.md` covers all of `/boot/config/ssh/` and `/etc/ssh`:
  read only. A user who wants SSH settings changed does it in the
  web UI.

## What Does Not Apply

- **Packages.** There is no package manager to use. Software
  installed by hand into the RAM root is gone after a reboot, and
  the runtimes skill does not belong here either. Tools come as a
  plugin (see Plugins and Community Applications) or run in a
  container.
- **Firewall.** Unraid ships no managed firewall, and a missing one
  is not a finding. Rules written with `iptables` or `nft` by hand
  are lost at the next boot, and Docker manages its own chains on
  the same host: do not add any. The documentation's answer to
  exposure is a VPN — WireGuard is built in, Tailscale comes as a
  plugin — and it says to "never expose the WebGUI directly to the
  internet" and never to put the server in a DMZ
  (<https://docs.unraid.net/unraid-os/system-administration/secure-your-server/security-fundamentals/>).
  Exposure is the finding: a port forward to the web UI or SSH, or
  a DMZ.
- **Automatic security updates.** There is no `unattended-upgrades`
  and no automatic OS update. Pending updates are the finding (see
  Updates).
- **systemd and the journal.** Services are Slackware rc scripts in
  `/etc/rc.d/`, generated from settings on the boot device. Read
  their state with `/etc/rc.d/rc.<name> status`; change a service's
  settings on the web UI page that owns it. `rules/service-reload.md`
  still decides when to ask.

## Configuration

- **The web UI owns the configuration.** Every settings page writes
  its values to `/boot/config/` (`*.cfg`, `plugins/`, `shares/`,
  `pools/`), and the OS rebuilds `/etc` from them at boot. Give the
  user the menu path and the values; do not edit the `.cfg` files
  by hand while the web UI can overwrite them, and never edit
  anything under `/etc` as a fix.
- `/boot/config/go` is the documented place for commands that run
  at every boot, as root: ask before adding a line, and show the
  line.
- `rules/backups.md` applies to `/boot/config`. Keep the copies in
  `/boot/config/hostwarden-backups/`.
- **Secrets on the boot device** (`rules/secrets.md`):
  `config/shadow`, `config/passwd`, `config/smbpasswd`, the
  WireGuard keys under `config/wireguard/`, and Docker templates,
  which can carry application credentials. Never print them, never
  edit them by hand — the Users page owns the passwords — and never
  copy them into the backup directory: Unraid Connect's flash backup
  uploads the boot device and leaves out only `shadow`, `smbpasswd`
  and the WireGuard keys
  (<https://docs.unraid.net/unraid-connect/automated-flash-backup/>).

## Plugins and Community Applications

- Plugins extend the OS itself and run as root. They are managed on
  the Plugins tab; `/var/log/plugins/` lists the installed `.plg`
  files. Community Applications, itself a plugin, is the Apps tab:
  the catalogue for plugins and container templates alike.
- Both are third-party sources (`AGENTS.md`: official repos only).
  The documentation: "Only install plugins from trusted sources or
  well-known developers"
  (<https://docs.unraid.net/unraid-os/using-unraid-to/customize-your-experience/plugins/>);
  Community Applications gives "basic vetting and moderation", no
  more
  (<https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/community-applications/>).
  Ask before installing, updating or removing either, and name the
  author.
- An OS update does not remove a plugin that the new release has
  made redundant or incompatible. Read the release notes against
  the installed plugins before any OS update.
- Safe Mode, a boot option, starts the OS with every plugin
  disabled; it is the user's step when a plugin breaks the system.

## Docker and VMs

- Unraid manages its containers and VMs: the Docker tab and the VMs
  tab, with the settings under Settings → Docker and Settings → VM
  Manager. Container images live in `docker.img` (or a directory) on
  the `system` share, container data in the `appdata` share, and
  each container's template on the boot device
  (<https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/overview/>).
- Read with `docker ps -a --format '{{.Names}}\t{{.Status}}'` and
  `virsh list --all`; `docker stats --no-stream` only when resource
  use is the question. Do not create, change or remove a container
  or a VM with `docker` or `virsh`: Unraid does not know about the
  change, and an update from the Docker tab recreates the container
  from its template. Hand the change to the user as web UI steps.
- Stopping a container or a VM takes a service down: ask first.
  Stopping the array stops every container and VM with it.

## Storage: Array, Parity and Pools

- The array is a set of data disks protected by up to two parity
  disks; pools (for example a cache) sit beside it, on btrfs or
  ZFS. User shares under `/mnt/user` span both; single disks show
  as `/mnt/disk<n>`, pools as `/mnt/<pool>`.
- The disk taboos in `AGENTS.md` cover every array, parity, pool
  and boot device; a write that bypasses Unraid also invalidates
  parity for the whole array.
- Never send anything to `mdcmd` but `status`: every other argument
  is written straight into the array driver (`unraid/webgui`,
  `sbin/mdcmd`). `mdcmd status` only prints `/proc/mdstat`.
- **Array operations belong to the user**, on Main → Array
  Operations: start, stop, parity check, rebuild, adding or
  replacing a disk, New Config. Hostwarden reports and names the
  step. The documentation's warnings to repeat when one comes up:
  - An unmountable disk: do not format it when the web UI offers
    to — formatting erases it. The fix is a file system repair
    (<https://docs.unraid.net/unraid-os/troubleshooting/common-issues/data-recovery/>).
  - "Do not use New Config for disk rebuilds": it clears the history
    a rebuild needs
    (<https://docs.unraid.net/unraid-os/using-unraid-to/manage-storage/array/array-health-and-maintenance/>).
- Array state is in `/var/local/emhttp/var.ini` (`mdState`,
  `mdNumDisabled`, `mdNumInvalid`, `mdNumMissing`, `mdResyncAction`,
  and `sbSynced2`, the end of the last parity check as epoch
  seconds, with `sbSyncErrs`); per-disk state in
  `/var/local/emhttp/disks.ini` (`status`, `color`, `numErrors`,
  `device`; an empty slot has `status="DISK_NP"`).
  `/boot/config/parity-checks.log` is the parity history, one line
  per check, newest last.

## Updates

- **Only through Unraid's updater:** Tools → Update OS, or Check for
  Update in the top-right menu. Never replace the `bz*` files on
  the boot device yourself, and never install Slackware packages
  over the OS.
- The documentation's order: back up the boot device, read the
  release notes, update the plugins, optionally stop the array,
  update, reboot
  (<https://docs.unraid.net/unraid-os/updating-unraid/>). An update
  needs a reboot (see Reboots).
- Which versions the updater offers depends on the server's release
  branch, Stable or Next, and the branch is changed in the Unraid
  account, not in the OS. Keep production servers on Stable.
- Pending updates: compare the version in `/etc/unraid-version` with
  the newest stable release from a live lookup
  (`rules/version-check.md`); the release notes are at
  <https://docs.unraid.net/category/release-notes/>. Containers and
  plugins update from the Apps, Docker and Plugins tabs, after
  asking.
- Downgrading is a manual step on the boot device and the user's to
  take.

## Reboots

- Ask first, and name what stops: the array, every container, every
  VM, every share.
- Reboot through the web UI or with `reboot`. Never `powerdown`: it
  is deprecated and, without `-r`, halts the machine (`AGENTS.md`
  taboo).
- Leave no process with its working directory under `/mnt` before a
  reboot or an array stop. Unraid waits for open terminal and SSH
  sessions, and a forced stop after the timeout is an unclean
  shutdown, which "can trigger an automatic parity check" at the
  next boot
  (<https://docs.unraid.net/unraid-os/troubleshooting/common-issues/unclean-shutdowns/>).

## Logs

- The syslog is `/var/log/syslog`. `/var/log` is a 128 MB tmpfs
  (`unraid/webgui`, `etc/rc.d/rc.S`): **everything in it, the
  `hostwarden` journal lines included, is gone after a reboot.**
- Settings → Syslog Server makes logs persist: a local or remote
  syslog server, or "Mirror syslog to boot drive", which writes
  `/boot/logs/syslog` and renames it to `syslog-previous` at the
  next boot. The documentation warns that the mirror wears the boot
  device and is for chasing a crash, not for good
  (<https://docs.unraid.net/unraid-os/troubleshooting/diagnostics/capture-diagnostics-and-logs/>).
  Do not turn it on for Hostwarden's sake.
- `logger -t hostwarden` lands in `/var/log/syslog`
  (`rules/changelog.md`). The activity check reads back, older file
  first so `tail` keeps the newest lines:
  ```
  for f in /boot/logs/syslog-previous /var/log/syslog; do
    [ -e "$f" ] && grep -hE "hostwarden|heinzel" "$f"
  done | tail -20
  uptime
  ```
  An empty result reaches back only to the boot `uptime` shows; say
  so, and read the local changelog for the time before.
- Tools → Diagnostics collects an anonymised bundle for support.

## Housekeeping and Audits

- The Linux baseline does not apply (see What Does Not Apply).
  Housekeeping reads, in one call:
  ```
  grep -E "^(mdState|mdNumDisabled|mdNumInvalid|mdNumMissing|mdResyncAction|sbSynced2|sbSyncErrs)=" /var/local/emhttp/var.ini
  grep -E "^(\[|status=|color=|numErrors=|device=)" /var/local/emhttp/disks.ini
  ls /tmp/notifications/unread | wc -l
  df -h -t vfat -t xfs -t btrfs -t zfs
  uptime
  for d in $(sed -n 's/^device="\(..*\)"/\1/p' /var/local/emhttp/disks.ini); do
    echo "== $d"
    smartctl -n standby -H -A /dev/$d | grep -E "result:|STANDBY|Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Reported_Uncorrect|Media_and_Data|Percentage Used"
  done
  ```
  `-n standby` leaves a spun-down disk asleep. `df -t` lists local
  file systems only, so a dead network mount under `/mnt/remotes`
  cannot hang the call; ZFS prints one row per dataset.
- Findings:
  - the array not `STARTED`, a disabled, invalid or missing disk, a
    disk whose `color` is not green, `numErrors` above 0;
  - no parity check in the last three months, or errors in the last
    one: the documentation advises checks "on a monthly or quarterly
    basis", scheduled under Settings → Scheduler;
  - SMART health not passing, or reallocated, pending or
    uncorrectable sectors;
  - a user share, disk or pool above 90 % full, and the boot device
    nearly full;
  - a pending OS, plugin or container update (see Updates), and a
    server on an RC or beta;
  - no boot device backup: no Unraid Connect flash backup and no
    recent zip from Main → Boot Device → Boot Device Backup, which
    the user downloads and keeps off the server;
  - unread notifications in `/tmp/notifications/unread/`, the
    default path, which the user can change under Settings →
    Notifications; list them only when the user asks.
- A security audit reports instead: SSH and Telnet state and port,
  root's authorized keys by fingerprint, whether the web UI answers
  on HTTPS only, port forwards or a DMZ the user describes, the
  installed plugins and their authors, containers running
  privileged or with host networking, and shares exported
  publicly.
- Fleet audit: compare Unraid servers only with each other; a
  missing firewall or `unattended-upgrades` is not drift (see What
  Does Not Apply).
