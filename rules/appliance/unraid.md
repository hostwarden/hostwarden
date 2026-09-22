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

- **This file covers Unraid up to 7.x**, the releases built on
  Slackware. Unraid 8 is announced on a Fedora base (uCore) and is
  not covered
  (<https://unraid.net/blog/unraid-8-announced>). When the version
  is 8 or later, stop: tell the user that Hostwarden has no rules
  for this release yet, and change nothing on the host.
- `/etc/unraid-version` holds one line, `version="<version>"`
  (`unraid/api`, `get-unraid-version-sync.ts`). Step 1 of
  `rules/os-detection.md` prints it; later connections read it with
  `cat /etc/unraid-version`.
- Releases come as Stable, Release Candidate (`-rc.<n>`) and Beta
  (`-beta.<n>`)
  (<https://docs.unraid.net/unraid-os/updating-unraid/release-types/>).
- Record in server memory: `Appliance: Unraid <version>`, and the
  boot device from the type the housekeeping `df -hT /boot` shows:
  `zfs` is an internal boot pool, which always uses ZFS
  (<https://docs.unraid.net/unraid-os/getting-started/set-up-unraid/internal-boot-faq/>);
  anything else is a flash device. Where that is unclear, ask the
  user to read Main → Boot Device rather than guess.

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
  installed by hand into the RAM root is gone after a reboot.
  Tools come as a plugin (see Plugins and Community Applications)
  or run in a container.
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
- **Network changes over SSH.** Addresses, bonds and bridges are set
  under Settings → Network Settings
  (<https://docs.unraid.net/unraid-os/getting-started/set-up-unraid/customize-unraid-settings/>),
  and this file names no revert for them: a network change is the
  user's to make in the web UI with console access ready
  (`rules/ssh-safety-net.md`).
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
- `rules/backups.md` applies to `/boot/config`. The backup directory
  is `/boot/config/hostwarden-backups/`.
- **Secrets on the boot device** (`rules/secrets.md`):
  `config/shadow`, `config/passwd`, `config/smbpasswd`, the
  WireGuard keys under `config/wireguard/`, and Docker templates,
  which can carry application credentials. Never edit them by hand
  — the Users page owns the passwords — and never copy them into the
  backup directory: Unraid Connect's flash backup uploads it
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
- Stopping the array stops every container and VM with it.

## Storage: Array, Parity and Pools

- The array is a set of data disks protected by up to two parity
  disks; pools (for example a cache) sit beside it, on btrfs or
  ZFS. User shares under `/mnt/user` span both; single disks show
  as `/mnt/disk<n>`, pools as `/mnt/<pool>`.
- The disk taboos in `AGENTS.md` cover every array, parity, pool
  and boot device; a write that bypasses Unraid also invalidates
  parity for the whole array.
- Never run `mdcmd`: its arguments are written straight into the
  array driver (`unraid/webgui`, `sbin/mdcmd`). Array state comes
  from `var.ini` (see Housekeeping and Audits).
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

## Updates

- **Only through Unraid's updater:** Tools → Update OS, or Check for
  Update in the top-right menu. Never replace the `bz*` files on
  the boot device yourself, and never install Slackware packages
  over the OS.
- The documentation's order: back up the boot device, read the
  release notes, update the plugins, optionally stop the array,
  update, reboot
  (<https://docs.unraid.net/unraid-os/updating-unraid/>).
- Which versions the updater offers depends on the server's release
  branch, Stable or Next, and the branch is changed in the Unraid
  account, not in the OS.
- Pending updates: compare the version in `/etc/unraid-version` with
  the newest stable release from a live lookup
  (`rules/version-check.md`); the release notes are at
  <https://docs.unraid.net/category/release-notes/>. Containers and
  plugins update from the Apps, Docker and Plugins tabs, after
  asking; running their Check for Updates is the user's step too
  (see Housekeeping).
- Downgrading is a manual step on the boot device and the user's to
  take.

## Reboots

- Name what stops: the array, every container, every VM, every
  share.
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
  (`rules/changelog.md`). The activity check reads back, oldest file
  first so `tail` keeps the newest lines, and takes the rotated
  `syslog.1` along where it exists:
  ```
  for f in /boot/logs/syslog-previous /var/log/syslog.1 /var/log/syslog; do
    [ -e "$f" ] && grep -hE "hostwarden|heinzel" "$f"
  done | tail -20
  for f in /var/log/syslog.1 /var/log/syslog; do
    [ -e "$f" ] && { head -1 "$f"; break; }
  done
  date
  ```
  The second loop and `date` bound the result
  (`rules/activity-check.md` → How far back it reached).
  `/var/log/syslog` and `syslog.1` reach back at most to the boot,
  less once rotation has dropped older files. `syslog-previous`
  adds matches from the boot before when the mirror is on, but not
  to the bound: rotation may have dropped the time between it and
  `syslog.1`.
- Tools → Diagnostics collects an anonymised bundle for support.

## Housekeeping and Audits

- The Linux baseline does not apply (see What Does Not Apply).
  Housekeeping reads, in one call:
  ```
  cat /etc/unraid-version
  date +%s
  grep -E "^(mdState|mdNumDisabled|mdNumInvalid|mdNumMissing|mdResyncAction|sbSynced2|sbSyncErrs)=" /var/local/emhttp/var.ini
  awk -F= '/^\[/{s=$0} /^(status|color|numErrors)=/{v[s]=v[s]" "$0} END{for(k in v) if(v[k]!~/"DISK_NP"/) print k v[k]}' /var/local/emhttp/disks.ini
  n=$(sed -n '/^\[notify\]/,/^\[/s/^path="\(.*\)"/\1/p' /boot/config/plugins/dynamix/dynamix.cfg)
  ls "${n:-/tmp/notifications}/unread" | wc -l
  uptime
  free -h
  df -hT /boot
  for f in /var/log/syslog.1 /var/log/syslog; do
    [ -e "$f" ] && echo "$f: oom $(grep -c 'Out of memory' "$f") io $(grep -c 'I/O error' "$f") ssh $(grep -c 'Failed password' "$f")"
  done
  df -h -t vfat -t xfs -t btrfs
  zpool list -H -o name,cap,health
  for d in $(sed -n 's/^device="\(..*\)"/\1/p' /var/local/emhttp/disks.ini); do
    echo "== $d"
    smartctl -n standby -H -A /dev/$d | grep -E "result:|Health Status:|Device is in|Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Reported_Uncorrect|grown defect list|Media and Data|Percentage Used"
  done
  for f in /var/log/plugins/*.plg; do
    p=${f##*/}; t=/tmp/plugins/$p
    case $p in unRAIDServer*) continue ;; esac
    [ -f "$t" ] || { echo "$p unchecked"; continue; }
    v=; cmp -s "$f" "$t" || v=" $(plugin version "$f") $(plugin version "$t")"
    echo "$p $(date -r "$t" +%s)$v"
  done
  docker ps -a --format '{{.Image}}' | sed -e '\|/|!s|^|library/|' -e '/:[^/]*$/!s/$/:latest/' | sort -u
  j=/var/lib/docker/unraid-update-status.json
  date -r "$j" +%s && grep -E '^    "|"status"' "$j"
  ```
  `var.ini`'s `sbSynced2` is the end of the last parity check in
  epoch seconds, measured against `date +%s`. `disks.ini` lists
  every slot; the `awk` prints one line per slot and drops the
  empty ones (`status="DISK_NP"`). A status that only contains
  `_NP`, as a missing or disabled disk has, stays in. `df -t`
  lists local file systems only, so a dead network mount under
  `/mnt/remotes` cannot hang the call; the btrfs rows include
  the `docker.img` and `libvirt.img` loop mounts. The
  notification directory is `path=` under `[notify]` in
  `dynamix.cfg`, `/tmp/notifications` when unset
  (`unraid/webgui`, `plugins/dynamix/default.cfg`); an `ls`
  error means the count did not run, never that there are none.
  The syslog counts reach back only to the boot (see Logs), not
  the seven days the Linux baseline reads; say which.
  The SMART loop is the probe in
  `.agents/skills/hostwarden-housekeeping/references/smart.md`
  over the `device=` lines of `disks.ini`.
  The update probes read what the last check left and reach no
  network (`unraid/webgui`, `sbin/plugin`, `DockerClient.php`).
  `plugin check`, which the Plugins tab and the scheduled plugin
  check run, downloads each plugin's newest `.plg` to
  `/tmp/plugins/`. The loop skips the OS and prints each plugin with
  the time of that copy, its last check in epoch seconds against
  `date +%s`, and both versions when the copy differs; a newer
  second version is an update. A plugin without a copy is
  `unchecked`: `/tmp` lives in RAM, so it has not been checked since
  the boot, or it names no `pluginURL` a check could reach. The
  Docker tab's check writes one entry per image to
  `unraid-update-status.json`, timed like the plugins by its last
  run, keyed by the image the way `ensureImageTag` in
  `DockerClient.php` writes it and the `sed` above rewrites the
  `docker ps` list: `library/` before a name without a `/`,
  `:latest` when it names no tag. `status` `false` is an update,
  `undef` unchecked, and an image `docker ps` lists without an
  entry was never checked.
- Findings:
  - load (against the CPU count in server memory), memory or swap
    past the baseline thresholds;
  - OOM kills, I/O errors, or failed SSH passwords in the syslog;
  - the array not `STARTED`, a disabled, invalid or missing disk, a
    disk whose `color` is not green, `numErrors` above 0;
  - no parity check in the last three months, or errors in the last
    one: the documentation advises checks "on a monthly or quarterly
    basis", scheduled under Settings → Scheduler;
  - the SMART findings in
    `.agents/skills/hostwarden-housekeeping/references/smart.md`;
  - an array disk or pool above 90 % full, and the boot device
    past the baseline disk thresholds;
  - a pending OS, plugin or container update (see Updates), and a
    server on an RC or beta; a plugin or image not checked, or
    checked more than a week ago, is named as unchecked, never as
    current;
  - no boot device backup: no Unraid Connect flash backup and no
    recent zip from Main → Boot Device → Boot Device Backup, which
    the user downloads and keeps off the server;
  - unread notifications; list them only when the user asks.
- A security audit reports instead: SSH and Telnet state and port;
  with SSH on, the effective settings from `sshd -T`, read the way
  the security skill's SSH reference reads them — root login is how
  Unraid works, so password authentication for root is the finding;
  root's authorized keys by fingerprint, whether the web UI answers
  on HTTPS only, port forwards or a DMZ the user describes, the
  installed plugins and their authors, containers running
  privileged or with host networking, and shares exported
  publicly.
- Fleet audit: compare Unraid servers only with each other, on the
  version and release type, SSH state and port (`USE_SSH`, `PORTSSH`
  in `/boot/config/ident.cfg`), and the age of the last parity
  check. A missing firewall or `unattended-upgrades` is not drift.
