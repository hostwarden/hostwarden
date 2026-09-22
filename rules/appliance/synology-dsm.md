# Synology DSM

Base: none

DiskStation Manager (DSM) is the Linux-based operating system of
Synology's NAS models, and no family file applies: there is no
distribution package manager, no `/etc/os-release`
(<https://github.com/netdata/netdata/issues/12068>), and settings
belong to DSM's web interface. Software comes from Package Center,
containers from Container Manager, storage from Storage Manager.
Where `AGENTS.md` or a baseline expects something a Linux server has
(a package manager, automatic security updates, passwordless
`sudo`), this file says what to check instead.

Sources unless noted: the Synology Knowledge Center,
<https://kb.synology.com/>, with the DSM 7 help pages under
`/en-global/DSM/help/`; the release notes,
<https://www.synology.com/en-global/releaseNote/DSM>; the Software
Life Cycle Policy,
<https://kb.synology.com/en-global/WP/Software_Life_Cycle_Policy/2>;
and the Package Developer Guide,
<https://help.synology.com/developer-guide/>. Synology documents
little of the shell; where only third-party code or reports back a
fact, the text says so, and the rule has the agent read the live
system rather than trust it.

## Version Detection

- **This file covers DSM 7.** When `majorversion` is 8 or later, or
  6 or earlier, stop: tell the user that Hostwarden has no rules for
  this release, and change nothing on the host.
- `/etc.defaults/VERSION` holds `key="value"` lines, among them
  `majorversion`, `minorversion`, `productversion` (e.g. `7.2.2`),
  `buildnumber`, `smallfixnumber` and `os_name="DSM"`. Synology
  does not document the file; Salt's grains
  (`salt/grains/core.py`) and Tailscale
  (`hostinfo/hostinfo_linux.go`) read the version from it. Step 1
  of `rules/os-detection.md` prints it; later connections read it
  with `cat /etc.defaults/VERSION`.
- Synology names a release `<productversion>-<buildnumber>`, and a
  later fix to it `Update <n>`, which is `smallfixnumber`
  (`7.2.2-72806 Update 5`, release notes). Record in server memory:
  `Appliance: Synology DSM <productversion>-<buildnumber>`, followed
  by ` Update <smallfixnumber>` when that is not 0, and
  `Model: <model>` from `upnpmodelname` in
  `/etc.defaults/synoinfo.conf`, where third-party scripts read it
  (<https://github.com/007revad/Synology_HDD_db>); the housekeeping
  call prints it.
- **Support comes from the Life Cycle Policy, never from memory.**
  Each minor version (7.1, 7.2, 7.3, …) has its own end of
  maintenance and, for a long-term support version, an end of
  extended life; releases past both get no security fixes. A host
  on such a release is a critical finding. Container Manager needs
  DSM 7.2 or later (see Containers).
- A model stops receiving new DSM versions of its own: the release
  notes list the models a release skips and the models for which it
  is the last one, and the product support status page gives each
  model's phase (<https://www.synology.com/en-global/products/status>).
  A model past its end of life is a finding.

## Privileges

- **Only members of the local `administrators` group may log in
  over SSH or Telnet, and only with a password that is not blank.
  Root is reached with `sudo -i` and the same account's password**
  (Control Panel → Terminal & SNMP → Terminal,
  <https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/system_terminal?version=7>).
  `sudo` therefore asks for a password, and the probe in
  `rules/privilege-escalation.md` records
  `Sudo: requires password (unusable)`. A third-party report adds
  that DSM's `sudoers` requires a terminal, so that `sudo -n` fails
  over SSH even where a rule allows it without a password
  (<https://github.com/usethedata/system_utils>, `DESIGN.md`); read
  the error the probe prints.
- **Do not probe root SSH unless the user says root login is set
  up.** The Knowledge Center names root as an SSH login only up to
  DSM 5.2
  (<https://kb.synology.com/en-global/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet>),
  and auto block counts failed SSH logins (Access and SSH). Record
  `Root SSH: unavailable` and go on in unprivileged mode.
- **Unprivileged mode is the usual state here.** Without root, the
  version, load, memory, the RAID state in `/proc/mdstat`, disk
  space, the package list and pending package updates are readable;
  the syslog, SMART, the containers, the effective SSH settings and
  pending DSM updates are not (Housekeeping and Audits). Say which
  checks were skipped for that reason.
- Passwordless `sudo` for the SSH account is the user's decision
  and the user's change, made at their own root shell; Hostwarden
  does not write `sudoers` here. Third-party reports say a DSM
  update can reset `/etc/sudoers.d/`, so after a DSM update probe
  `sudo -n true` again instead of trusting server memory.
- The `PATH` of a non-root login is not documented. Call Synology's
  tools by their full path: `/usr/syno/bin/synopkg`,
  `/usr/syno/bin/synogetkeyvalue` and `/usr/syno/sbin/synoupgrade`,
  as third-party scripts do
  (<https://github.com/007revad/Synology_app_mover>).

## Access and SSH

- SSH is switched on, and its port set, under Control Panel →
  Terminal & SNMP → Terminal; Advanced Settings there sets the
  cipher, key exchange and MAC levels. The same page offers Telnet.
  Network backup and SFTP switch SSH on by themselves and open port
  22 (same page).
- **Telnet on is a finding.** DSM updates fixed a telnetd
  vulnerability in 2026 (CVE-2026-24061, `7.2.2-72806 Update 6`,
  release notes).
- **Enforced 2-factor authentication applies to SSH**, "SSH
  terminal, SFTP, and rsync with SSH transfer encryption"
  (Control Panel → Security → Account,
  <https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/connection_security_account?version=7>).
  Hostwarden logs in with `BatchMode` and answers no prompt, so a
  login that fails after the user enforced 2FA for administrators
  failed on that; say so and leave the setting to the user.
- **Auto block** (Control Panel → Security → Protection) blocks an
  address after too many failed logins, SSH included
  (<https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/connection_security_protection?version=7>).
  A blocked workstation looks like an unreachable host
  (`rules/ssh-unreachable.md`); the allow list there is the user's
  to edit.
- Key login needs the account's home folder, which exists only with
  the user home service on (Control Panel → User & Group → Advanced
  → User Home,
  <https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/file_user_advanced?version=7>);
  it lies in the `homes` shared folder, e.g.
  `/volume1/homes/<user>`. A third-party guide reports that DSM
  creates home folders with mode 777, which sshd's checks refuse for
  key login
  (<https://github.com/007revad/Synology_SSH_key_setup>): report
  it, and leave the fix to the user.
- **The SSH taboo in `AGENTS.md` covers `/etc/ssh`** (`sshd_config`,
  the host keys), any `sshd_config` below `/etc.defaults`, root's
  `.ssh` and every `.ssh` in the `homes` shared folder: read only.
  DSM writes the Terminal page's settings itself; a user who wants
  them changed does it on that page.

## What Does Not Apply

- **Packages.** There is no `apt`, `dnf` or `opkg` to use, and the
  runtimes skill does not belong here. Software comes from Package
  Center (see Package Center) or runs in a container. Never copy
  binaries into the system directories: DSM tracks only what
  Package Center installed.
- **Firewall.** DSM ships its own, under Control Panel → Security →
  Firewall: profiles of rules per network interface, and for each
  interface a default action, allow or deny, for what no rule
  matches
  (<https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/connection_security_firewall?version=7>).
  Expected: enabled, with deny as the default action. Off, or
  allowing by default, is a finding; on a NAS that only answers a
  trusted LAN the user may well decide to keep it so. Never write
  rules with `iptables` or `nft`: DSM owns the rule set, and
  Container Manager's engine writes chains of its own.
- **Firewall changes are the user's, in the web UI.** This file
  names no revert for them, so under `rules/ssh-safety-net.md` the
  user applies the change with physical access ready. Before any
  rule is added or tightened, name every port that has to stay
  open: the SSH port from the Terminal page, and the DSM web ports
  under Control Panel → Login Portal (DSM's help signs in on 5000
  over HTTP).
- **Automatic updates.** There is no `unattended-upgrades`. DSM's
  own setting, Update Settings on the system update tab of Control
  Panel → Update & Restore, offers "Automatically install important
  updates", "Automatically install the latest updates" (within the
  current version, never a new major one), and, on models released
  in 2024 and earlier, "Notify me and let me decide"
  (<https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/system_dsmupdate?version=7>).
  Expected: one of the first two. Notify-only is a finding, and so
  is any pending update (see Updates). Packages update under Package
  Center → Settings → Auto-update.
- **Services.** DSM starts its services and packages itself; turn a
  service on or off on its settings page, and a package in Package
  Center. `/usr/syno/bin/synopkg status <package>` reads a
  package's state. `rules/service-reload.md` still decides when to
  ask.
- **Network changes over SSH.** Addresses, bonds and routes are set
  under Control Panel → Network, and this file names no revert for
  them: a network change is the user's to make in the web UI with
  physical access ready (`rules/ssh-safety-net.md`). Never run
  `synonet`.

## Configuration

- **The web UI owns the configuration.** Give the user the menu
  path and the values; do not edit a file DSM writes, above all
  `/etc/synoinfo.conf`, its default copy in `/etc.defaults/` and
  anything under `/usr/syno/etc`. Read a key with `grep` or
  `/usr/syno/bin/synogetkeyvalue <file> <key>`.
- The CLI Administrator Guide's tools — `synouser`, `synogroup`,
  `synoshare`, `synonet`, `synoservice` — change users, shares,
  network and services, and only the super-user may run them
  (<https://global.download.synology.com/download/Document/Software/DeveloperGuide/Firmware/DSM/All/enu/Synology_DiskStation_Administration_CLI_Guide.pdf>).
  Hostwarden does not use them. `synowebapi`, which third-party
  guides use to call DSM's settings API from the shell, is not
  documented by Synology; do not use it.
- **Before a larger change, have the user export the
  configuration**: Control Panel → Update & Restore → Configuration
  Backup → Export writes a `.dss` file with users, groups, shared
  folders, network, security and service settings
  (<https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/system_configbackup?version=7>).
  The file stays with the user and never passes through the session.
  `rules/backups.md` applies unchanged to the rare file Hostwarden
  edits.
- **Secrets** (`rules/secrets.md`): `/etc/shadow`, the `.dss`
  export, a container's environment (`docker inspect` prints it;
  never print `Config.Env`), compose files, which carry passwords as
  readily as the Developer Guide's own example does, Hyper Backup's
  encryption keys, and the SMTP password under Control Panel →
  Notification → Email. Read compose files for their structure,
  with the values of password-like keys left out.

## Package Center

- Packages come from Synology, from third-party publishers listed
  in Package Center, or from package sources the user added under
  Package Center → Settings → Package Sources
  (<https://kb.synology.com/en-global/DSM/help/DSM/PkgManApp/configure?version=7>).
  DSM 7 warns at installation of any package not from Synology
  (Developer Guide, Breaking Changes in 7.0). A package's
  `maintainer` names who built it
  (<https://help.synology.com/developer-guide/synology_package/INFO_necessary_fields.html>).
- Third-party packages and sources are outside `AGENTS.md`'s
  official repositories. Ask before installing, updating or
  removing any package, name its maintainer, and never add a
  package source.
- Beta packages (Package Center → Settings → General → Beta) are not
  a stable track: turned on is a finding.
- A package lives under `/var/packages/<package>/`: `INFO`,
  `target` (its files), `etc` and `var`
  (<https://help.synology.com/developer-guide/integrate_dsm/fhs.html>).
  Its operations log to `/var/log/synopkg.log`, its scripts to
  `/var/log/packages/<package>.log`.
- **Some packages run their own containers**, through Container
  Manager: the package creates them at install, starts and stops
  them with itself, recreates them at an upgrade and removes them,
  with their images, at uninstall
  (<https://help.synology.com/developer-guide/resource_acquisition/docker-project.html>).
  Leave those containers to their package.

## Containers

- **Container Manager is DSM's container app**, the successor of the
  Docker package, and needs DSM 7.2 or later
  (<https://www.synology.com/en-global/releaseNote/ContainerManager>).
  It runs on x86-64 models and on some ARMv8 ones; the models are
  listed on the package's page
  (<https://www.synology.com/en-global/dsm/packages/ContainerManager>).
  On the host, `/var/packages/ContainerManager` exists where it is
  installed; on DSM 7.0 and 7.1 the older package is
  `/var/packages/Docker`.
- The engine's `docker` is linked into `/usr/local/bin`, where DSM
  links a package's binaries
  (<https://help.synology.com/developer-guide/resource_acquisition/usrlocal_linker.html>);
  `ls -l /usr/local/bin/docker` shows the link. It needs root: in
  unprivileged mode the containers are not readable over SSH. The
  `docker compose` command works on the command line from Container
  Manager 24.0.2-1542 on (release notes).
- **Where things live.** The engine's data root, images included,
  comes from `docker info --format '{{.DockerRootDir}}'`; community
  reports place it at `/volume<n>/@docker`. The package creates a
  `docker` shared folder (release notes, 24.0.2-1535), where
  projects and their bind mounts usually live. A project's working
  directory is whatever path the user chose when creating it
  (<https://kb.synology.com/en-global/DSM/help/ContainerManager/docker_project?version=7>).
- Read, as root, in one call; the label names a container's project:
  ```
  d=/usr/local/bin/docker
  $d ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Label "com.docker.compose.project"}}'
  $d compose ls -a
  $d info --format '{{.DockerRootDir}} {{.ServerVersion}}'
  ```
  `docker logs <name>` and `docker stats --no-stream` only when a
  container is the question.
- **Create, change, start, stop and remove containers and projects
  in Container Manager, never with `docker` or `docker compose`.**
  A project's Build, Start, Stop and Clean run compose on the
  project's `docker-compose.yml`, so a container changed by hand is
  replaced by what that file says the next time the project is
  built (Project help page). A container's ports, volumes,
  environment and links cannot be changed after creation; the UI's
  way is Duplicate (release notes, 24.0.2-1535). A container with a
  web portal is tied to Web Station as well. Hand the change to the
  user as Container Manager steps.
- **Image updates:** Container Manager detects updates for images
  tagged `latest` (release notes, 20.10.23-1405) and updates one
  under Image → Action → Update
  (<https://kb.synology.com/en-global/DSM/help/ContainerManager/docker_image?version=7>).
  Ask first; the container restarts on the new image.
- A Container Manager update touches every container: the release
  notes of 24.0.2-1606 ask for all of them to be restarted after
  it. Ask before it as before a restart.
- **Virtual machines** run in Virtual Machine Manager
  (<https://kb.synology.com/en-global/DSM/help/Virtualization/requirements_and_limitations?version=7>).
  Read and change them there; stopping or deleting one powers off
  or destroys a server, only on the user's explicit request.

## Storage

- A storage pool is a Linux software RAID array, classic RAID or
  Synology Hybrid RAID (SHR); SHR and pools with several volumes
  add LVM on top, and a volume is Btrfs or ext4, mounted at
  `/volume<n>`
  (<https://kb.synology.com/en-global/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC>,
  <https://kb.synology.com/en-global/DSM/tutorial/What_is_Synology_Hybrid_RAID_SHR>).
- `cat /proc/mdstat` and `df -h` read the state without root. Never
  run `mdadm`, `lvm` or `btrfs` commands that write.
- **The disk taboos in `AGENTS.md` cover every drive**, M.2 cache
  drives included, and Storage Manager's own actions: Secure Erase
  on the HDD/SSD page erases a drive
  (<https://kb.synology.com/en-global/DSM/help/DSM/StorageManager/disk?version=7>).
  Creating, repairing or expanding a pool, replacing or deactivating
  a drive, and removing a volume belong to the user in Storage
  Manager; Hostwarden reports and names the step.
- **Data scrubbing** checks and repairs a pool on Btrfs, or with SHR
  of three or more drives, RAID 5, RAID 6 or RAID F1; it is
  scheduled under Storage Manager → Storage → Schedule Data
  Scrubbing
  (<https://kb.synology.com/en-global/DSM/help/DSM/StorageManager/storage_pool_data_scrubbing?version=7>).
- **Snapshots** of shared folders on Btrfs volumes are taken and
  kept by Snapshot Replication
  (<https://kb.synology.com/en-global/DSM/help/SnapshotReplication/snapshots?version=7>).
  An immutable snapshot cannot be removed until its protection
  period ends. Backups to other targets are Hyper Backup tasks.
- **Drive compatibility.** Storage Manager marks a drive
  Incompatible, Unverified or Unrecognized against Synology's
  compatibility list. On models from 2025 on, DSM 7.3 accepts HDDs
  and 2.5" SATA SSDs that are not listed for new pools on the DS
  Plus and desktop FS series, while M.2 NVMe drives not on the list
  can only be migrated from another Synology system; other series
  are stricter
  (<https://kb.synology.com/en-global/DSM/tutorial/Drive_compatibility_policies>).
  Such a status is a compatibility note, not a health finding;
  SMART decides health. Third-party scripts bypass the list by
  setting `support_disk_compatibility` or `drive_db_test_url` in
  `synoinfo.conf`
  (<https://github.com/007revad/Synology_HDD_db>): report either as
  a change made outside DSM, never suggest one.

## Updates

- **Only through DSM's updater:** the system update tab of Control
  Panel → Update & Restore, or Manual DSM Update there with a file
  from Synology's Download Center. An update cannot be undone —
  "You can only update to a newer version" — and restarts the NAS
  (help page, release notes). Never install an update with
  `synoupgrade`.
- The update is the user's decision, asked for explicitly, with the
  release notes of the target version read and the configuration
  exported (Configuration). A new major version is never installed
  by the update setting, and never by Hostwarden on its own.
- Pending update: the system update tab shows it; as root,
  `/usr/syno/sbin/synoupgrade --check` asks Synology's server
  (tldr-pages, `synoupgrade`). Its output is not documented: show
  it as it is. Compare the installed version with the release notes
  page (`rules/version-check.md`).
- Packages update in Package Center, after asking;
  `/usr/syno/bin/synopkg checkupdateall` lists the pending ones as
  JSON without root (third-party,
  <https://github.com/usethedata/system_utils>). Containers update
  as in Containers.

## Reboots

- Name what stops: every share, package, container and virtual
  machine, and every backup task running.
- Ask the user to restart from DSM's Options menu (Restart), which
  stops the packages the way DSM does. Never shut the NAS down or
  power it off (`AGENTS.md` taboo).

## Logs

- DSM logs through syslog-ng; the Developer Guide sends a
  package's `syslog()` messages to `/var/log/messages`
  (<https://help.synology.com/developer-guide/getting_started/first_package.html>).
  Log Center shows the logs in the web UI; drive logs live only
  there since DSM 7.2 (release notes).
- **Check that `logger -t hostwarden` lands** before relying on it
  (`rules/changelog.md`): after the first journal line on a host,
  run the read-back below. When the line is not in it, log to the
  local changelog only, and record `Journal: not written` in server
  memory. The file is not documented as readable by
  administrators; read it with root where the session has it.
- The activity check reads back, oldest file first so `tail` keeps
  the newest lines:
  ```
  for f in $(ls -tr /var/log/messages*); do
    case $f in *.gz) zcat "$f" ;; *.xz) xzcat "$f" ;; *) cat "$f" ;; esac
  done | grep -E "hostwarden|heinzel" | tail -20
  f=$(ls -tr /var/log/messages* | head -1)
  case $f in *.gz) zcat "$f" ;; *.xz) xzcat "$f" ;; *) cat "$f" ;; esac | head -1
  date
  ```
  The second part and `date` bound the result
  (`rules/activity-check.md` → How far back it reached). An error,
  a permission denied included, means the check did not run.

## Housekeeping and Audits

- The Linux baseline does not apply (see What Does Not Apply).
  Housekeeping reads, in one call; the first part needs no root:
  ```
  cat /etc.defaults/VERSION
  cat /proc/uptime /proc/loadavg
  grep -E "^(MemTotal|MemAvailable|SwapTotal|SwapFree):" /proc/meminfo
  cat /proc/mdstat
  df -h / /volume[0-9]*
  grep -H -E "^(version|maintainer)=" /var/packages/*/INFO
  /usr/syno/bin/synopkg checkupdateall
  grep -H -E "^(upnpmodelname|support_disk_compatibility|drive_db_test_url)=" /etc.defaults/synoinfo.conf /etc/synoinfo.conf
  ```
  and the rest as root, through `sudo -n` where it works:
  ```
  /usr/syno/sbin/synoupgrade --check
  for d in /sys/block/sd* /sys/block/sata* /sys/block/sas* /sys/block/nvme*n* /sys/block/nvc*; do
    [ -e "$d" ] || continue
    echo "== ${d##*/}"
    smartctl -n standby -H -A /dev/${d##*/} | grep -E "result:|Health Status:|Device is in|Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Reported_Uncorrect|grown defect list|Media and Data|Percentage Used"
  done
  for f in $(ls -tr /var/log/messages*); do
    case $f in *.gz) zcat "$f" ;; *.xz) xzcat "$f" ;; *) cat "$f" ;; esac
  done | grep -c -E "Out of memory|I/O error"
  /usr/local/bin/docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Label "com.docker.compose.project"}}'
  ```
  DSM names drives `sd*`, `sata*`, `sas*`, `nvme*` and `nvc*` in
  `/sys/block`, depending on the model (third-party,
  <https://github.com/007revad/Synology_HDD_db>); the SMART loop is
  the probe in
  `.agents/skills/hostwarden-housekeeping/references/smart.md` over
  that list. A drive `smartctl` cannot open prints no health line
  and is named as unknown; Storage Manager → HDD/SSD → Health Info
  is the user's view of it. A USB drive is an `sd*` drive too, and
  often answers only through its bridge. NVMe drives do not run
  SMART tests in DSM (HDD/SSD help page), but report their
  counters. The syslog counts reach back as far as the files do
  (Logs), not the seven days the Linux baseline reads; say how
  far.
- Findings:
  - a DSM release past its end of maintenance, and past its end of
    extended life, or a model past its end of life (Version
    Detection);
  - a pending DSM update, and an update setting that only notifies;
  - load above the CPU count in server memory, memory and swap
    nearly exhausted;
  - an md array degraded (`_` in its `[UU…]` map), resyncing or
    recovering;
  - a volume above 90 % full, or the system partition (`/`) nearly
    full;
  - the SMART findings in `smart.md`;
  - OOM kills or I/O errors in the syslog;
  - pending package updates, and a package from a third-party
    maintainer or source (named, not rated);
  - a container that exited unexpectedly, restarts, or is
    `unhealthy`;
  - `support_disk_compatibility="no"` or a `drive_db_test_url` line
    (Storage);
  - a check that needed root and did not run, named as unchecked.
- DSM keeps these settings where the shell cannot read them without
  an undocumented API. Ask the user once, record the answers in
  server memory with the date, and name them as unchecked when the
  record is older than three months: the update setting; a data
  scrubbing schedule for every pool that supports it; snapshot
  schedules; Hyper Backup tasks and their last result (the
  backup-presence check's `Backup:` line); the configuration backup;
  and email notifications under Control Panel → Notification, which
  are how a failing drive reaches anyone
  (<https://kb.synology.com/en-global/DSM/help/DSM/AdminCenter/system_notification_email?version=7>).
- A security audit reports instead: SSH and Telnet state and port;
  as root, the effective settings from `sshd -T`, read the way the
  security skill's SSH reference reads them; the firewall state and
  default actions; auto block, account protection and 2FA
  enforcement for administrators; the members of `administrators`
  (`grep '^administrators:' /etc/group`); third-party packages,
  package sources and beta packages; containers running privileged
  or on the host network:
  ```
  /usr/local/bin/docker ps -q | xargs -r /usr/local/bin/docker inspect --format '{{.Name}} privileged={{.HostConfig.Privileged}} net={{.HostConfig.NetworkMode}}'
  ```
  and QuickConnect or port forwards the user describes. Security
  Advisor, DSM's own scanner, checks malware, system, account,
  network and update settings against a baseline
  (<https://kb.synology.com/en-global/DSM/help/DSM/SecurityScan/securityscan_overview?version=7>);
  ask the user for its last result rather than rebuild it.
- Fleet audit: compare DSM hosts only with each other, on the
  version, the model, the SSH port (`grep -i '^Port'
  /etc/ssh/sshd_config`, or `sshd -T` as root), Telnet, the
  firewall, and the update setting from server memory. A missing
  `unattended-upgrades` or host-firewall package is not drift.
