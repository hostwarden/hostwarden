# UGREEN UGOS Pro

Base: none
Hardware: vendor

UGOS Pro is the operating system of UGREEN's NASync NAS series, DH,
DX, DXP and iDX. Underneath it is Debian 12 (bookworm), but no family
file applies: UGOS Pro updates as a whole firmware image, its root
file system is built from read-only images with a writable layer on
top, and the web UI and the vendor's services own the configuration.
Where `AGENTS.md` or a baseline expects something a Debian server
has (apt, `unattended-upgrades`, ufw), this file says what to check
instead. systemd, the journal and the Debian userland are there and
work as on Debian for reading.

**The NAS usually holds data that exists nowhere else**, and its
volumes use vendor extensions that a stock Linux kernel refuses to
mount (see Storage). A wrong move on a storage pool is not undone by
a reinstall.

UGREEN's SSH guide warns that its support does not cover problems
caused through SSH and that the owner pays for a reflash or repair
they make necessary
(<https://support.ugnas.com/knowledgecenter/detail/article/en-US/481>).
Say so once, before the first change a session makes on the host.

Sources unless noted: UGREEN's Knowledge Center,
<https://support.ugnas.com/knowledgecenter/> (articles cited by
number, `…/detail/article/en-US/<number>`), UGREEN's developer
documentation, <https://developer.ugnas.com/en/doc/>, and UGREEN's
open-source compliance repository for the Debian base,
<https://github.com/ugreen-opensource/ugospro-debian12>, whose
`SOFTWARE_MANIFEST.csv` lists the Debian packages UGOS Pro ships.
Where UGREEN is silent, community projects are cited and the text
says so; treat those facts as observations to confirm on the live
host, not as documented behaviour.

## Version Detection

- **This file covers UGOS Pro 1.x.** When the version is 2 or
  later, stop (`rules/os-detection.md` → Layers).
- **The older UGOS (without "Pro") is not covered either.** UGREEN
  moved those NAS models to UGOS Pro, and after the switch the old
  storage can only be mounted as external storage (article 412).
  A host that reports no UGOS Pro version, or that the user calls
  plain UGOS, gets nothing changed: stop and tell the user.
- The version is the firmware version, four numbers such as
  `1.19.1.0126`; UGREEN's articles name their minimum firmware in
  that form (article 938). The web UI shows it under Control Panel
  → Update & Restore → Update (article 110).
- On the host, `/etc/os-release` carries it as `OS_VERSION`, beside
  `OS_IS_BETA` for a beta build (community:
  `runlevel1977-del/UgreenNASAdmin`, which reads both). Step 1 of
  `rules/first-detection.md` prints both lines; later connections read
  them with:
  ```
  grep -E "^OS_(VERSION|IS_BETA)=" /etc/os-release
  ```
  UGREEN does not document these keys. Where they are missing, ask
  the user for the version from Control Panel → Update & Restore
  instead of reading it from anything else.
- x86 and ARM models run different builds: DXP, DX and the DH2600
  are x86, the DH2300 and DH4300 series ARM (article 915). The iDX
  series has release numbers of its own. The CPU architecture comes
  from the probe's `uname -m`.
- Record in server memory: `Appliance: UGOS Pro <version>`, with
  `(beta)` appended where `OS_IS_BETA` is true, and the model the
  user names or the web UI shows.
- Release notes: UGREEN publishes a monthly "UGOS Pro <Month> <Year>
  System Update Notes" article in the Knowledge Center (article 915
  is July 2026) and the firmware per model in the Download Center,
  <https://nas.ugreen.com/pages/downloads>. Take the newest version
  from there by a live lookup (`rules/version-check.md`), never from
  memory.

## Access and Privileges

- **Only administrators can log in over SSH.** Common users have no
  access to the SSH setting and no SSH login (article 522). There is
  no separate root login in UGREEN's documentation: an administrator
  logs in and becomes root with `sudo -i`, which asks for the same
  administrator password again (article 481).
- **`sudo` asks for the password**, so
  `rules/privilege-escalation.md` applies as written for that case:
  on a stock system the session is usually unprivileged, and
  everything below that needs root (storage, containers, most of
  Housekeeping and Audits) goes into the sysadmin report.
  UGREEN documents only an administrator login followed by
  `sudo -i`, so the root SSH fallback of that file is not probed
  here: a refused `root@` login would count towards UGOS's
  automatic IP blocking. Record `Root SSH: unavailable` without the
  probe, unless the user says root SSH is set up.
  Passwordless sudo for the SSH user is the user's decision
  and the user's step: UGREEN documents no such setting, and
  whether a sudoers drop-in survives a firmware update is not
  documented either. Say both when the user asks.
- **SSH is switched on under Control Panel → Terminal**, with its
  settings on the same page: port (22 by default), an automatic
  disable time, access restrictions such as LAN only, the
  encryption level (High or Low) and SFTP (articles 84 and 481).
  The Low level widens the cipher suites in `sshd_config` for old
  clients (article 84).
- **The automatic disable time switches SSH off on its own.** Read
  whether the user set one and record it in server memory: a host
  that stops answering on port 22 may simply have reached it
  (`rules/ssh-unreachable.md`). Turning SSH back on is the user's
  step in the web UI.
- The same page offers Telnet, which sends passwords in plain text
  (article 84). Telnet on is a finding.
- The SSH taboo in `AGENTS.md` holds. The web UI writes
  `sshd_config` from the Terminal page, so an SSH change is the
  user's to make there.
- **Keys:** OpenSSH reads `~/.ssh/authorized_keys` of the
  administrator. UGREEN's guide requires the administrator's
  Personal Folder to be enabled first, `~/.ssh` at mode 700 and
  `authorized_keys` at 600, and says to test key login again after
  a restart and after major updates
  (<https://ai.ugreen.com/blogs/how-to/connect-nas-ssh-root-access>).
  A community project reports that UGOS has reset these permissions
  and broken key login (`ln-12/UGOS_scripts`, its SSH key script).
  A key login that stops working is the user's to repair.
- After a network reset (see What Does Not Apply), UGOS enables a
  temporary `admin` account with no password until an
  administrator password is set (articles 110 and 294). Never log
  in with it.
- The shell, `PATH` and group memberships of the SSH user are read
  from the live host (`rules/ssh-user.md`), not assumed.

## What Does Not Apply

- **Packages.** apt and dpkg are present, but UGOS Pro updates
  only as a firmware image. UGREEN documents no use of apt;
  community reports on `ugreen-forum.de` say not to upgrade with
  apt, only with the firmware, and describe unmet dependencies
  after installing single packages, because the package lists move
  on while the installed base does not
  (<https://ugreen-forum.de/forum/thread/1811-update-ueber-ssh-per-apt-update-gefaehrlich/>).
  So: no `apt-get install`, `upgrade` or `dist-upgrade`, no source
  added, and no `apt-get update` either, since the lists it fetches
  are what the next install resolves against. `dpkg -l` reads what
  is installed. Software UGOS does not ship, language runtimes included
  (the `hostwarden-runtimes` skill), runs in a container (see
  Docker and Virtual Machines) or comes from the App Center.
- **Automatic security updates.** There is no
  `unattended-upgrades` (UGREEN's manifest does not list it), and
  its absence is not a finding. The firmware update policy replaces
  it (see Updates).
- **ufw and a hand-made firewall.** UGOS Pro has its own firewall
  under Control Panel → Security → Firewall (see Firewall). Never
  install ufw or firewalld, never enable `nftables.service`, and
  never add `iptables` or `nft` rules by hand: the Docker engine
  writes its own rules on the same host, and UGOS does not know
  about a hand-made one.
- **Network changes over SSH.** Addresses, link aggregation and
  bridges are set under Control Panel → Network (no revert:
  `rules/ssh-safety-net.md`). UGREEN's recovery is Control Panel →
  Update & Restore → Reset network, or the RESET button held for
  five seconds, which restores the network settings and leaves the
  data alone (articles 110 and 294).
- **Services.** `systemctl status`, `systemctl is-active` and
  `journalctl -u` read as on Debian, and so do the Enabled services
  and Service status forms of `rules/os/debian.md` → Service
  Manager. The vendor's own services are
  units named `*_serv` (community: `runlevel1977-del/UgreenNASAdmin`
  lists `storage_serv`, `docker_serv`, `gateway_serv` and more).
  Never start, stop or restart one: the web UI and the apps depend
  on them, and a Samba, NFS or nginx setting changes on the web UI
  page that owns it. `rules/service-reload.md` still decides when
  to ask.

## Configuration

- **The web UI owns the configuration.** Give the user the menu
  path and the values; never edit a file under `/etc` as a fix.
  Community projects report files that UGOS rewrites on a settings
  change or at boot, among them its nginx configuration under
  `/etc/nginx/` and the crontab (`ln-12/UGOS_scripts`,
  `unblock_ports/`).
- **The root file system is layered.** Community analysis of a
  DXP6800 Pro found read-only squashfs images for the userland,
  kernel modules, firmware and UGREEN's own layer, stacked with a
  writable overlay, and an A/B pair of root partitions
  (`manawenuz/ugreen-os-ext4-recovery`, `docs/ugos-architecture.md`).
  A change outside the web UI may therefore be kept, lost or
  shadowed by the next firmware image; UGREEN documents none of
  it. Say so before any change outside the web UI, and prefer a
  container or an App Center app.
- Vendor directories, from the same community sources: `/ugreen`
  (UGREEN's service files; community tools keep `/ugreen/ssl` at
  mode 0700), `/usr/ugreen` and `/var/ugreen`. Read, never
  change.
- **The configuration backup is the web UI's.** Before a larger
  change, the user downloads one under Control Panel → Update &
  Restore → Local backup, a `.ugb` file; the same page restores it
  and can keep a copy in the UGREEN Account (article 110).
  `rules/backups.md` applies with its default directory to any file
  a session does edit; whether `/var/backups` survives a firmware
  update is not documented.
- **Secrets** (`rules/secrets.md`): the `.ugb` configuration
  backup (it stays with the user), everything under
  `/ugreen/ssl`, DDNS provider keys and tokens entered under
  Control Panel → Device Connection, the UGREEN Account, and the
  environment of Compose projects and containers, which often
  carries application passwords. Read container environments as
  names only.

## App Center

- Apps are installed, updated, disabled and uninstalled in the App
  Center; the settings there choose the default volume and turn
  automatic app updates on (article 116). An app lives under
  `/volume<n>/@appstore/<app-id>`, reached as
  `/var/packages/<app-id>`, with its data, cache and logs in
  `@appdata`, `@appcache` and `@applog` on the same volume
  (<https://developer.ugnas.com/en/doc/backend/application/install-directory.html>).
- **Manual installation** of a `.upk` package from outside the App
  Center, and a firmware image from any source but UGREEN's
  Download Center, are third-party sources (`AGENTS.md`: official
  repos only). Ask before either, and never use Update & Restore →
  Import root public key, which exists to accept firmware from
  another source (article 110).

## Docker and Virtual Machines

- **Docker is an App Center app**, not part of the firmware. It is
  not supported on the DH2300 with 4 GB, and UGREEN advises against
  it on ARM models with 4 GB or less (articles 772 and 938). It
  installs to `/volume<n>/@appstore/com.ugreen.docker` (article
  397). `docker` is not in UGREEN's Debian manifest; find it with
  `command -v docker`. The engine needs root.
- The Docker app has pages for Projects (Compose), Containers,
  Images, Networks, Logs and Management (article 236). **A new
  Project gets its folder under the `docker` shared folder**,
  `docker/<project>`, which holds its Compose file (article 411);
  a shared folder's real path is `/volume<n>/<folder>` (article
  611). The engine's data root lives on a volume as well: community
  scripts find it as `/volume<n>/@docker` and the app's own records
  of Projects in `@appstore/com.ugreen.docker/db/docker_info_log.db`
  (`Railsimulatornet/UGREEN-NAS-Docker-Backup-Restore`). Read the
  data root with `docker info` rather than assume it.
- Read with:
  ```
  docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}\t{{.Label "com.docker.compose.project"}}'
  docker info --format '{{.ServerVersion}} {{.DockerRootDir}}'
  ```
  `docker logs --tail 50 <name>` and `docker stats --no-stream`
  when a container is the question.
- **Change containers in the Docker app, never with `docker` or
  `docker compose`.** UGREEN's rules by origin (articles 236 and
  539):
  - a container created by hand or from JSON: edited in the
    Containers page;
  - a container of a Compose Project: the Project's configuration
    is edited in the Projects page and the Project redeployed;
  - a container app from the App Center, marked "Dependency
    Package": its configuration cannot be changed, and it is
    updated, repaired and uninstalled only in the App Center.
    Uninstalling it, or the Docker app, deletes its data for good.
  The app keeps its own records of Projects and containers, so a
  change made past it leaves the UI out of step, and an App Center
  update replaces a container app whatever was done to it. Hand the
  change to the user as web UI steps.
- Updating the Docker app deactivates every container app until the
  user reactivates it (article 539). Ask first, and say so.
- With the UGOS firewall on, ports a container publishes may be
  blocked until a rule allows them (article 353). So the Docker
  checks of the housekeeping baseline's Firewall Status and of the
  security skill's `references/firewall-nftables-docker.md` do not
  apply here: `nft` and `iptables` cannot show which rules are the
  UGOS firewall's (see Firewall), and their remedy, hand-written
  rules, is forbidden. Instead, list each published port not bound
  to `127.0.0.1` or `[::1]` with the UGOS firewall rule the user
  reads for it. The finding is a port that the first matching rule
  allows from every source, or that no rule matches while the
  default action is "Access allowed", unless server memory records
  it as meant to be public.
- **Virtual machines** are the Virtual Machine app from the App
  Center, not supported on the DH series (article 772). UGREEN's
  Debian manifest lists QEMU and libvirt's library; whether a
  `virsh` client is present is read with `command -v virsh`, and
  only `virsh list --all` is used. Starting, stopping, changing
  and deleting a VM are the user's, in the app: stopping one powers
  off a server.

## Storage

- **Storage pools and volumes are the Storage app's.** A storage
  pool is a set of drives in a RAID type (Basic, JBOD, RAID 0, 1,
  5, 6, 10); volumes are created on a pool with Btrfs or ext4; SSD
  cache, hot spares, RAID type changes and expansion are managed
  there too (articles 313, 498 and 662). A volume is mounted at
  `/volume<n>` (article 611).
- Underneath, from UGREEN's manifest and community analysis: Linux
  md RAID (`mdadm`), LVM on top of each array, with logical volumes
  named like `ug_<id>_<number>_pool<n>-volume<n>`, and the file
  system on those (`manawenuz/ugreen-os-ext4-recovery`,
  `docs/ugos-architecture.md`). The same analysis found that UGOS
  marks its ext4 and Btrfs volumes with **vendor feature flags that
  a stock Linux kernel refuses to mount**, and that `e2fsck` from
  stock e2fsprogs rejects.
- **Only reads apply here:** the Change tier of `rules/storage.md`
  is out too, and so is a file system check even with `-n`. UGOS
  keeps its own records of pools and volumes, and a repair tool
  that does not know the vendor flags can refuse the volume or
  damage it. Read with
  `cat /proc/mdstat`, `mdadm --detail`, `lvs`, `findmnt`, `df` and
  `btrfs device stats`.
- The disk taboos in `AGENTS.md` include the internal system
  drive with UGOS's A/B root partitions. The Storage app's Hard
  Drive → Data erasing overwrites a whole drive, and creating a
  pool or adding a drive formats it
  (articles 313 and 314): they happen only in the web UI, by the
  user, on an explicit request.
- **Storage operations belong to the user**, in the Storage app:
  repairing a degraded pool, replacing or disabling a drive,
  expansion, RAID type changes, SSD cache, and data organizing,
  which UGREEN recommends regularly for RAID 5 and 6 pools to keep
  their data consistent. Hostwarden reports and names the step.
  Disabling a drive degrades its pool (article 314).
- **Snapshots** exist on Btrfs volumes only and are managed in the
  Snapshot app with a schedule (article 662). Snapshots take space
  as data changes (article 712).

## Firewall

- **UGOS Pro's firewall is Control Panel → Security → Firewall**:
  profiles of ordered rules by source address, location, port or
  built-in service and network interface, with a default action
  "Access allowed" or "Access denied". It has to be enabled on that
  page, and its default action is "Access allowed" (articles 353
  and 354).
- Report its state from what the user reads there; UGREEN
  documents no command for it. Rules the Docker engine and UGOS
  write can be read as root with `nft list ruleset` or
  `iptables-save`, both in UGREEN's manifest. Neither shows which
  rules belong to the UGOS firewall.
- The firewall off, or a profile whose default action is "Access
  allowed", is a finding under the standing expectation in
  `AGENTS.md`, whatever deny rules it holds: every source no rule
  names is still let in. On a NAS that only its LAN reaches the
  user may decide to keep it that way; record the decision.
- **Firewall changes are the user's, in the web UI.** UGREEN's
  order: add and enable the allow rules, the one for the user's own
  device first, test access, and only then switch the default
  action to "Access denied" (article 353). UGREEN's notes
  that apply: with link aggregation only the first interface's rules
  apply, several ports on one subnet can break the rules, and IPv6
  needs rules of its own (article 353). Locked out, the user signs
  in from the LAN, or resets the network.
- Under Control Panel → Security also sit DoS protection and the
  automatic blocking of IPs after failed logins, with an allow list
  (article 225). A session's own failed logins count there too
  (`rules/ssh-connections.md` → Avoid failed logins).

## Updates

- **Only through UGOS's updater:** Control Panel → Update & Restore
  → Update, which checks on its own and offers the update, or a
  firmware `.img` for the exact model from the Download Center
  through Manual installation (article 110). Never through apt, and
  never a firmware image from elsewhere.
- **An update stops every app service and restarts the NAS**
  (articles 110 and 383): it is a reboot and needs the user's
  agreement (see Reboots). Read the release notes of the target
  version first.
- The update policy, under More settings → Update settings: download
  important updates automatically (UGREEN's recommendation),
  download every update automatically, or notify only; and how
  often to check (article 110). UGREEN's text does not say whether
  an automatic policy also installs and restarts on its own; ask the
  user what the NAS did before, and record it.
- **Pending update:** the Update page shows it. UGREEN documents no
  command that reads it. Compare `OS_VERSION` with the newest
  release for the model from a live lookup (see Version Detection),
  or ask the user to read the Update page; without either, name
  the update state as unknown, never as current.
- Apps, Docker included, update in the App Center, by hand or with
  its automatic updates (article 116). The Docker app can check
  images for updates on a schedule (Management → Image update
  detection, article 236); updating a container or Project is the
  user's step in the Docker app, after asking.
- Downgrading is a manual firmware installation and the user's to
  take.

## Reboots

- Name what stops: every share, every app, every container and VM.
  Containers come back after the reboot only where "Auto restart"
  or a Compose `restart` policy says so (articles 938 and 411).
- Reboot through the web UI (the "Me" menu → Reboot, article 855)
  or with `systemctl reboot` as root, always after asking. The web
  UI's Shutdown and a scheduled shutdown under Control Panel →
  Hardware & Power → Power (article 855) halt the NAS: the
  `AGENTS.md` taboo covers them, and a schedule the user wants is
  the user's to set.

## Logs

- UGOS runs systemd's journal and rsyslog (UGREEN's manifest).
  `logger -t hostwarden` reaches the journal
  (`rules/changelog.md`), and the journal read-back in
  `rules/activity-check.md` applies unchanged. Whether the journal
  survives a reboot or a firmware update is not documented.
- The Logs app in the web UI holds UGOS's own system and
  application logs, for administrators only (article 216). On the
  host, community tools read the vendor services' logs as
  `/var/ugreen/log/*.slog` (`runlevel1977-del/UgreenNASAdmin`), and
  an App Center app writes to `/volume<n>/@applog/<app-id>`
  (developer documentation, Install Directory).

## Housekeeping and Audits

- The Linux baseline applies, except its package, automatic-update
  and firewall checks, which this file replaces, and "Kernel:
  Running vs Installed" and "Critical Services: Running Binary vs
  Installed Package", which assume apt-installed packages. Disk
  Usage runs with `-x squashfs` added: the read-only image layers
  are always full, and their 100 % is no finding. The baseline's
  own `-x overlay` hides the writable root, so `df -h /` runs
  beside it and `/` is rated against the same limits. Read, in the
  same call as root:
  ```
  cat /proc/mdstat
  for md in $(awk '/^md[0-9]+ :/ {print $1}' /proc/mdstat); do
    echo "== $md"
    mdadm --detail "/dev/$md" | grep -E "State :|Devices :|faulty|removed|rebuilding|resync"
  done
  lvs -o lv_name,vg_name,lv_attr,lv_size
  findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS | grep "^/volume"
  for m in $(findmnt -rn -t btrfs -o TARGET | grep "^/volume"); do
    echo "== $m"
    btrfs device stats "$m"
  done
  docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}\t{{.Label "com.docker.compose.project"}}'
  command -v virsh && virsh list --all
  ```
  and the probe in
  `.agents/skills/hostwarden-housekeeping/references/smart.md`,
  over `smartctl --scan` (smartmontools is in UGREEN's manifest).
  `/proc/mdstat` and `findmnt` read the kernel's own tables and
  need no root; `lvs`, which needs LVM's lock and the physical
  volumes' metadata, `mdadm --detail`, `btrfs device stats`, SMART
  and the container lines do, and without it they are reported as
  skipped (`references/unprivileged.md`). The Docker checks
  of
  `.agents/skills/hostwarden-housekeeping/references/service-checks.md`
  → Docker read the `docker ps` line.
- Findings:
  - an md array degraded: an underscore anywhere in the member
    bitmap `/proc/mdstat` prints (`[U_]`, `[UU_]`, `[U_UU]`), or a
    `State :` with `degraded` or `FAILED`. Rebuilding or resyncing,
    and a member `faulty` or `removed`, count too. Name the pool
    and hand the repair to the Storage app;
  - a volume mounted read-only (`ro` in the options) or missing
    from `findmnt` while the Storage app lists it;
  - Btrfs device stats above 0;
  - the SMART findings in `smart.md`; the Hard Drive page's status
    test plan (article 314) not set up is worth one line;
  - no capacity warning set on a volume (article 313); how full
    it is comes from the baseline's Disk Usage;
  - a pending firmware update, or the update state unknown; a beta
    build (`OS_IS_BETA`); an update policy that does not install on
    its own. UGREEN's text does not say whether the two
    automatic-download policies also install (see Updates), so
    until the user confirms that one does, notify-only and both
    download policies are reported the same way: automatic security
    updates are not established;
  - a container app the App Center shows as needing repair;
  - an app with an update available in the App Center, and
    automatic app updates off (article 116). UGREEN documents no
    command for either, so both come from the App Center page the
    user reads, as the firmware update state does (see Updates);
    without that answer, app updates are named as unchecked, never
    as current;
  - no configuration backup: no `.ugb` download and no cloud
    backup of the configuration (article 110). Data backups are
    `references/backup-presence.md`'s.
- A security audit keeps the generic checks that read the system
  underneath — `references/user-accounts.md`,
  `references/listening-services.md`, `references/kernel-os.md` and
  `references/file-permissions.md` — and replaces only what the
  vendor owns: SSH, the firewall and intrusion prevention. In their
  place it reports: SSH on or off, its port, its
  automatic disable time and access restriction, the encryption
  level (Low is a finding), and with SSH on the effective settings
  from `sshd -T` read the way the security skill's SSH reference
  reads them; Telnet on; the UGOS firewall and its default action
  (see Firewall); DoS protection and automatic IP blocking off
  (article 225); two-factor sign-in off for administrators
  (article 510); UGREENlink remote access on, which reaches the NAS
  through UGREEN's relay servers (article 86); DDNS with a router
  port forward to the web UI, SSH or SMB, and UPnP port mapping,
  which UGREEN does not recommend (article 86); the number of
  administrator accounts; containers running privileged or with
  host networking, from
  ```
  docker ps -q | xargs -r docker inspect --format '{{.Name}} privileged={{.HostConfig.Privileged}} net={{.HostConfig.NetworkMode}}'
  ```
  and apps installed by manual `.upk` installation. UGREEN
  publishes its vulnerability process at
  <https://ai.ugreen.com/pages/vulnerability-disclosure>; a firmware
  release that fixes a vulnerability makes the pending update
  urgent.
- Fleet audit: compare UGOS Pro hosts only with each other, on the
  version and beta flag, the update policy, SSH state and port, and
  the firewall state and default action. A missing ufw or
  `unattended-upgrades` is not drift.
