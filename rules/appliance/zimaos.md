# ZimaOS

Base: none
Hardware: any

ZimaOS is IceWhale's NAS OS for its ZimaCube, ZimaBoard and
ZimaBlade hardware and for generic x86-64 machines with UEFI. It is
built with Buildroot, grew out of CasaOS, and updates over the air
(`IceWhaleTech/ZimaOS`, `README.md`). No family file applies: there
is no package manager, the root file system is read-only, and the
web UI owns apps, storage and the network. **The OS sits in two A/B
slots that updates replace; user and app data live on a separate
partition mounted at `/DATA`.** Where `AGENTS.md` or a baseline
expects something a Linux server has (a package manager, a firewall,
automatic updates), this file says what to check instead.

The OS's own source is not public: the `IceWhaleTech/ZimaOS`
repository publishes images and release notes only. Sources unless
noted: the ZimaOS documentation, <https://www.zimaspace.com/docs/>
(its source is `IceWhaleTech/ZimaDocs`), the releases at
<https://github.com/IceWhaleTech/ZimaOS/releases>, and
`IceWhaleTech/CasaOS-AppManagement`, the public ancestor of ZimaOS's
app service, where the docs are silent. A fact that comes from a
third party says so; check it on the live host before relying on it.

## Version Detection

- `/etc/os-release` carries `ID=zimaos` and the version in
  `VERSION_ID`, e.g. `VERSION_ID=1.6.1`. The vendor documents
  neither; both come from a third-party project that read them on a
  ZimaCube (`chicohaager/zimaos-mergerfs-snapraid-sysext`, the
  table of verified facts in its README). Step 1 of
  `rules/first-detection.md` prints them; later connections read them
  with
  `grep -E "^(ID|VERSION_ID)=" /etc/os-release`, in double quotes
  because the step-1 shape wraps each piece in single ones.
- `rauc status`, as root, names the slots and marks the one that
  booted
  (<https://www.zimaspace.com/docs/zimaos/system-recovery>).
- Releases are tagged `<major>.<minor>.<patch>` for stable and
  `-beta<n>` for betas. GitHub does not mark the betas as
  pre-releases: read the tag, not the label. Settings → General →
  Developer mode has a Beta switch that moves the host to beta
  builds
  (<https://www.zimaspace.com/docs/developer/v-1-4-0>).
- **This file covers ZimaOS 1.x.** When `VERSION_ID` is 2 or later,
  stop (`rules/os-detection.md` → Layers).
- Record in server memory: `Appliance: ZimaOS <version>`, and `beta`
  after it when the version carries a `-beta` suffix.

## Access and Privileges

- **SSH is switched on in the web UI**, under Settings → General →
  Developer mode → SSH Access; the same page switches on a
  web-based terminal
  (<https://www.zimaspace.com/docs/developer/how-to-open-ssh-in-zimaos>).
  The docs name no setting for the port and no default for the
  switch: take the port from the connection that works, and change
  neither.
- **ZimaOS user accounts and root can log in**
  (<https://www.zimaspace.com/docs/developer/ssh-setup>). A user
  account reaches root with `sudo -i`, which asks for the user's
  password
  (<https://www.zimaspace.com/docs/zimaos/app-store/azuracast-install>),
  so the `sudo -n true` probe of `rules/privilege-escalation.md`
  records `Sudo: requires password (unusable)`. Root's password is
  set at the console; older docs name the `passwd-root` tool for it
  (<https://www.zimaspace.com/docs/zimaos/app-store/cli-guide>).
  Setting or changing it is a credential rotation: ask first.
- The root SSH fallback of `rules/privilege-escalation.md` then
  decides. Root SSH works only with a key the user installed for
  root, and the docs do not say whether root's home survives an OS
  update: ask the user rather than assume either way. Without it,
  unprivileged mode applies — and a user account cannot run
  `docker`: the docs switch to root for it
  (<https://www.zimaspace.com/docs/zimaos/app-store/hermes-agent-setup>).
- `PATH` is `/usr/bin:/usr/sbin`, and `/sbin` and `/bin` are
  symlinks into `/usr` (third party: the project named under
  Version Detection). `/usr/local/bin` does not exist.
- **The SSH taboo in `AGENTS.md` covers sshd's configuration and
  host keys, root's `.ssh`, and the overlay that stores changes to
  `/etc`** (see Configuration): a write under `/mnt/overlay/etc`
  is a write to `/etc`. The docs do not name sshd's files; find
  them with `sshd -T` and `ls`, as root, and only read them. A user
  who wants SSH changed does it in the web UI.

## What Does Not Apply

- **Packages.** There is no package manager, and "most system
  folders are read-only even if you log in as root"
  (<https://www.zimaspace.com/docs/zimaos/app-store/cli-guide>).
  The runtimes skill does not belong here. Tools come as an app
  from the App Store or run in a container. Some hosts carry
  `systemd-sysext` images under `/var/lib/extensions` (third
  party, as above); `systemd-sysext list` shows them. Each one is
  third-party code with root on the NAS: ask before adding or
  removing one.
- **Firewall.** ZimaOS ships no host firewall, and the forum
  reports that the `nft` binary is missing; a community module
  ("ZFW") fills the gap
  (<https://community.zimaspace.com/t/is-there-a-firewall-setting-so-i-can-create-some-firewall-rules-in-zimaos/6027>,
  a forum thread: the vendor docs say nothing about a firewall). A
  missing firewall is not a finding. Do not write `iptables` rules
  by hand: Docker manages its own chains on the same host, and
  nothing here says such rules survive a reboot. Exposure is the
  finding: a port forward to the web UI or SSH, and remote access
  (see Housekeeping and Audits).
- **Network changes over SSH.** Addresses are set in the web UI
  (no revert: `rules/ssh-safety-net.md`), and a static address that
  no longer fits is reset with an empty `_ResetNetwork` file on a
  USB stick
  (<https://www.zimaspace.com/docs/zimaos/reset-network-settings>).
- **Automatic security updates.** There is no `unattended-upgrades`.
  OS updates are offered in the web UI (see Updates). Pending
  updates are the finding.

## Configuration

- **The web UI owns the configuration**: users, apps, storage,
  shares, network, remote access. Give the user the menu path and
  the values.
- **`/etc` is writable and persistent through an overlay whose
  upper directory is `/mnt/overlay/etc`** (`IceWhaleTech/ZimaOS`,
  `zimaos-fix.sh`, which repairs empty files there from the
  read-only root). A file edited in `/etc` stays in the overlay
  and hides the version a later OS update ships. The docs edit
  `/etc/exports` for NFS this way
  (<https://www.zimaspace.com/docs/developer/nfs-on-zimaos>); for
  anything the web UI also manages, change it in the UI instead.
- Where the rest persists is not documented beyond `/DATA`. Before
  writing anywhere else, read the mounts:
  `findmnt -n -o TARGET,SOURCE,FSTYPE -T <path>`. A third party
  reports `/var` as a tmpfs (the project under Version Detection);
  `/var/lib/casaos` survives a reboot, because the docs reset the
  web UI's users by deleting a file there and rebooting
  (<https://www.zimaspace.com/docs/zimaos/password-recovery>).
- `rules/backups.md` applies. The backup directory is
  `/DATA/.hostwarden-backups/`, root-owned with mode 0700, after
  `findmnt -T /DATA` has shown a persistent disk mount.
- **Secrets** (`rules/secrets.md`): `/var/lib/casaos/db/user.db`
  holds the web UI's users, each app's compose file under the apps
  directory (see Apps and Containers) can carry credentials in its
  environment, and the Remote ID works like a password for shared
  folders
  (<https://www.zimaspace.com/docs/zimaos/remote-access>). Never
  print them.

## Apps and Containers

- Apps come from the App Store in the web UI. The documentation
  lists community stores that the user can import beside the
  official one
  (<https://www.zimaspace.com/docs/zimaos/app-store/awesome-third-party-stores>);
  each is a third-party source (`AGENTS.md`: official repos only).
  Ask before installing, updating or removing an app, and name the
  store it comes from.
- Settings → Apps sets the App data location, `/DATA/AppData/<app>`
  by default, and shows each app's disk use
  (<https://www.zimaspace.com/docs/zimaos/docker-app-paths>).
- **Every App Store app is a Docker Compose project that the web UI
  owns.** Its compose file sits in the apps directory, one
  directory per app: `/var/lib/casaos/apps/<name>` on ZimaOS 1.5.0
  (`IceWhaleTech/ZimaOS` issue #328), the `AppsPath` default of
  `CasaOS-AppManagement`
  (`build/sysroot/etc/casaos/app-management.conf.sample`). The
  housekeeping `docker ps` line reads the directory in use.
- The Docker engine is part of the OS. Where images and container
  data live is read with `docker info --format '{{.DockerRootDir}}'`;
  Settings → Data Migration moves Docker images and app data to
  another storage space
  (<https://www.zimaspace.com/docs/zimaos/data-migration>).
- Read, as root, one container's image, state, mounts and ports
  with
  ```
  docker inspect --format '{{.Config.Image}} {{.State.Status}} {{json .Mounts}} {{json .HostConfig.PortBindings}}' <name>
  ```
  never a bare `docker inspect`: it prints `Config.Env`, where apps
  keep their credentials (`rules/secrets.md`).
  `docker stats --no-stream` only when resource use is the
  question.
- **Do not create, change or remove an app's container with
  `docker` or `docker compose`.** The app service lists apps from
  the compose projects Docker reports, and an update from the web
  UI takes the store's compose file, merges the local settings into
  it and applies it again, which recreates the containers
  (`CasaOS-AppManagement`, `service/compose_service.go` → `List`,
  `service/compose_app.go` → `Update`, `Apply`): a change made
  beside the UI is lost or shown wrongly. On ZimaOS 1.5.0,
  containers added outside the store shared one project name, and
  removing one in the UI removed them all
  (`IceWhaleTech/ZimaOS` issue #328). Hand the change to the user
  as web UI steps: the app's settings, or its compose YAML in the
  UI.
- **VMs** run in ZVM, ZimaOS's VM service on libvirt
  (<https://www.zimaspace.com/docs/zimaos/zvm-next-virtual-machines-community-preview>).
  Create, change and remove VMs in the web UI.
- **Inventory** (`rules/hypervisors.md`): record
  `Hypervisor: ZimaOS ZVM (virsh, read-only)` where `virsh`
  exists. The listing is `virsh list --all`, the rest as
  `rules/hypervisors.md` gives it for libvirt, reads only.

## Storage

- Disks are combined under Settings → Storage → Combine into RAID
  0, 1, 5, 6 or JBOD, and a failed disk is replaced and rebuilt
  there (<https://www.zimaspace.com/docs/zimaos/raid-options>,
  <https://www.zimaspace.com/docs/zimaos/storage-setup>). The
  arrays are Linux md RAID: the RAID 6 guide from before the UI
  offered it builds one with `mdadm` and `--homehost=zimaos`
  (<https://www.zimaspace.com/docs/developer/raid6-setup>). The
  docs do not name the file system the UI puts on them; read it
  with `lsblk -f`.
- The system drive holds the A/B slots and the `/DATA` partition;
  storage spaces and other disks mount under `/media`, and ZFS
  pools exist only where someone built them by hand on the command
  line (<https://www.zimaspace.com/docs/developer/zfs-setup>).
- The disk taboos in `AGENTS.md` cover every system, data, array
  and USB disk. The docs' command-line guides for RAID 6 and ZFS
  erase and partition disks: never run their steps.
- **Storage operations belong to the user**, in Settings →
  Storage: creating, expanding or repairing an array, replacing a
  disk. Hostwarden reads `/proc/mdstat`, `mdadm --detail` on one
  array, and `lsblk`, and names the step.

## Updates

- **Only through ZimaOS's updater.** The web UI offers a new
  release with a red dot on the update button; releases roll out
  in batches, so a host may see one days after another. Offline,
  the user places the `.raucb` bundle from the GitHub release in
  `/ZimaOS-HD/.ota/offline/` in the Files app (from 1.4.1 on) and
  starts the update from the same button
  (<https://www.zimaspace.com/docs/zimaos/offline-install>). The
  update writes the other slot and takes effect at the next boot.
- Pending updates: compare `VERSION_ID` with the newest tag without
  a `-beta` suffix at
  <https://github.com/IceWhaleTech/ZimaOS/releases>, from a live
  lookup (`rules/version-check.md`). The release notes are on the
  same page.
- When a slot does not boot, the user picks the other one in the
  GRUB menu at the console
  (<https://www.zimaspace.com/docs/zimaos/system-recovery>).

## Reboots

- Name what stops: every app, every VM, every share, remote access.
- Reboot through the web UI or with `systemctl reboot`, and never
  set the web UI's scheduled shutdown.

## Logs

- **systemd and the journal apply.** The docs use `systemctl` and
  `journalctl -u` on ZimaOS
  (<https://www.zimaspace.com/docs/developer/nfs-on-zimaos>,
  <https://www.zimaspace.com/docs/zimaos/app-store/enable-ai>).
  Read unit names from the host with
  `systemctl list-units --type=service --no-legend`; do not assume
  them.
- The journal read-back of `rules/activity-check.md` and the
  `logger -t hostwarden` line of `rules/changelog.md` apply
  unchanged.

## Housekeeping and Audits

- The Linux baseline runs, except Pending Security Updates,
  Automatic Security Updates, Firewall Status, Kernel: Running vs
  Installed, Ubuntu Release and Support, and Critical Services:
  Running Binary vs Installed Package, which do not apply (see
  What Does Not Apply and Updates). Disk Usage runs with
  `-x squashfs` added: a read-only root image is always full, and
  its 100 % is no finding. Housekeeping adds, as root, in one
  call:
  ```
  rauc status
  for p in / /etc /var /var/log /var/lib/casaos /DATA; do
    findmnt -n -o TARGET,SOURCE,FSTYPE -T "$p"
  done
  cat /proc/mdstat
  command -v smartctl || echo "smartctl missing"
  command -v zpool && zpool status -x
  command -v virsh && virsh list --all
  docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.project.working_dir"}}'
  ```
  Where `smartctl` exists, SMART runs with the probe in
  `.agents/skills/hostwarden-housekeeping/references/smart.md`; a
  missing `smartctl` is named, never read as healthy disks. The
  last column of the `docker ps` line is the apps directory in
  use. In unprivileged mode (see Access and Privileges) the call
  runs as the user: `rauc status` and `docker ps` then fail, and
  the report names them as not checked, never as clean.
- Findings:
  - a pending OS update, or a host on a beta;
  - a slot that `rauc status` reports as bad;
  - an md array degraded, resyncing or with a failed member, and
    the SMART findings of `smart.md`;
  - the system drive or `/DATA` past the baseline's Disk Usage
    limits: the docs warn that a full system drive makes updates
    fail
    (<https://www.zimaspace.com/docs/zimaos/docker-app-paths>);
    an App data location left on the system drive is worth one
    line;
  - a published port (`->`) not bound to `127.0.0.1` or `[::1]`,
    as the Docker part of the baseline's Firewall Status rates it:
    with no host firewall, it answers on every network the NAS is
    on, unless server memory records it as meant to be reachable;
  - a container not `Up` that the user expects to run, and an app
    from a third-party store.
- A security audit reports instead: with SSH on, the effective
  settings from `sshd -T`, read the way the security skill's SSH
  reference reads them; whether the web-based terminal and the Beta
  switch are on, which the user reads under Developer mode; remote
  access, on by default after the first sign-in and switched off
  under Settings → Network
  (<https://www.zimaspace.com/docs/zimaos/remote-access>); port
  forwards the user describes; the listening services; the App
  Store sources; containers running privileged, with host
  networking or with the Docker socket mounted; and the
  `systemd-sysext` images.
- Fleet audit: compare ZimaOS hosts only with each other, on the
  version and the beta suffix, password and root login from
  `sshd -T`, and the md array state. A missing firewall or
  `unattended-upgrades` is not drift.

## Never

- `rauc install`, or `rauc status mark-good`, `mark-bad` or
  `mark-active`: they write or switch the boot slots behind the
  updater.
- Deleting `/var/lib/casaos/db/user.db`: the docs' password reset,
  which removes every web UI user.
- Running `zimaos-fix.sh` from the ZimaOS repository: it rewrites
  files in the `/etc` overlay and grows the `/DATA` file system.
