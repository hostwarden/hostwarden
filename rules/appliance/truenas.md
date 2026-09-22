# TrueNAS

Base: `rules/os/debian.md`

For TrueNAS Community Edition and TrueNAS Enterprise, the
Linux-based releases (24.10 and later, called SCALE before 25.04),
built on Debian. TrueNAS CORE, the FreeBSD edition, has its own
file, `rules/appliance/truenas-core.md`. The base file supplies the
vocabulary (`systemctl`, `journalctl`), but most of its
instructions for changing the system are **wrong here**: the
TrueNAS middleware owns the configuration and renders the system
files from its database. This file applies on top of the base
(`rules/os-detection.md` → Appliances).

The host usually holds data that exists nowhere else. A wrong move
on a pool is not undone by a reinstall.

Source for everything below unless noted: the TrueNAS
documentation, <https://www.truenas.com/docs/>, the API reference,
<https://api.truenas.com/>, and the `truenas/middleware` source
(<https://github.com/truenas/middleware>) where the docs are
silent.

## Add: Version Detection

- `midclt call system.version` prints e.g. `TrueNAS-25.10.7` and
  needs no privileges. It is the version command on every
  connection.
- Record in server memory: `Appliance: TrueNAS <version>`, and on
  the first connection `Community Edition` or `Enterprise` from
  `midclt call system.product_type`.
- Releases are named `YY.MM` with a codename (25.04 Fangtooth,
  25.10 Goldeye). Whether the release is still supported
  (`rules/version-check.md` → Tier 1) comes from the software
  status page, <https://www.truenas.com/docs/softwarestatus/>.

## Access and Shell

- SSH is off by default: System > Services > SSH starts it and
  sets "Start Automatically". The SSH taboo in `AGENTS.md` covers
  `/etc/ssh/sshd_config` and the host keys: read only. The page's
  "Auxiliary Parameters" are, in the docs' words, "an unsupported
  configuration"; never suggest them.
- **Keys and users are managed in the web UI** under Credentials >
  Users (the user's "Authorized Keys" field), never by editing
  `authorized_keys` from the shell.
- The first admin account is `truenas_admin` on installs from 24.10
  on; upgraded systems may keep `admin`. The docs call root SSH
  logins "never recommended". Connect as the admin user and use
  `sudo`; do not ask the user to enable root login.
- **sudo** is set per user under Credentials > Users: "Allow all
  sudo commands", the same "with no password", or a list of
  allowed commands. Only the no-password variant lets `sudo -n`
  succeed. Probe as usual (`rules/privilege-escalation.md`).

## Configuration Model

- **The middleware (`middlewared`) owns the configuration.** It
  keeps it in its own database and renders the files under `/etc`
  from it, among others `sshd_config`, `sudoers`, the nginx and
  Samba configs. A hand edit is overwritten the next time the
  middleware renders that file, and an update installs a new boot
  environment whose `/etc` never had the edit.
- **Change settings through the web UI** or the API. Give the user
  the exact menu path and values, or make the change with `midclt`:
  - `midclt call <method> [args …]` calls one API method over the
    local socket. Each argument is parsed as JSON, and falls back to
    a plain string. `-j` waits for a method that runs as a job.
  - It authenticates as the user who runs it: a user with the Full
    Admin role reaches the whole API without `sudo`, other users
    only what their role allows. Never pass `-u`/`-p` or an API key
    on the command line (`rules/secrets.md`).
  - Method names, arguments and which methods are jobs come from
    the API reference of the installed release
    (<https://api.truenas.com/>), which changes between releases.
    Look the method up before a write; `AGENTS.md` → Verify Before
    Running applies.
- Read everything you like with `…query` and `…config` methods
  (`midclt call ssh.config`, `midclt call service.query`).
- `rules/backups.md` applies to the configuration as a whole:
  before a larger change, have the user download the configuration
  file (System > Advanced Settings > Manage Configuration >
  Download File), with "Export Password Secret Seed" if encrypted
  fields such as service passwords are to survive a restore. The
  file holds secrets; it stays with the user and never passes
  through the session.
- Documented places for persistent custom additions: System >
  Advanced Settings > Sysctl, Init/Shutdown Scripts and Cron Jobs
  (`tunable.*`, `initshutdownscript.*`, `cronjob.*`). A script they
  call lives on a pool, not on the boot pool.
- `config.reset` (factory defaults) and `config.upload` (restore a
  configuration file) exist. Never, unless the user explicitly
  asks.

## Replace: Package Manager

- **Package management is disabled.** `apt`, `apt-get` and `dpkg`
  are wrappers that print a refusal and exit; every binary whose
  name starts with `apt` or `dpkg` has lost its execute bit,
  `dpkg-query` included, and `/usr` is a read-only dataset. The
  installed release is what `system.version` reports.
- **Never re-enable it.** `install-dev-tools` (developer mode) and
  `/usr/local/libexec/disable-rootfs-protection`, which it calls,
  make `/usr` writable and restore apt. Whatever apt installs is
  lost at the next update, which replaces the root filesystem. Do
  not run either, and do not suggest them to the user.
- Software that TrueNAS does not ship, language runtimes included
  (the `hostwarden-runtimes` skill), runs as an app (see Apps), not
  on the host.

## Remove: Stable Branch Only

## Remove: Package Sources

## Remove: cloud-init

## Remove: Ubuntu

## Replace: Automatic Security Updates

- **There is no `unattended-upgrades`, and its absence is not a
  finding.** TrueNAS updates as a whole image through its own
  updater; pending updates are the finding.
- The updater checks for updates on its own and the web UI shows
  them. `autocheck` in `midclt call update.config` downloads them
  as well; installing is always a separate step.

## Updates

- Check without installing (25.10 and later):
  ```
  midclt call update.status
  ```
  `status.new_version` is `null` when the system is current, and
  `code` is `ERROR` with a reason when the check failed. 24.10 and
  25.04 have `midclt call update.check_available` instead: `status`
  is `AVAILABLE`, `UNAVAILABLE`, or `REBOOT_REQUIRED` once an update
  is applied and awaits the reboot (`truenas/middleware`,
  `plugins/update.py`).
- Since 25.10 the user chooses an update profile (a risk tolerance)
  instead of a train. Keep it on a profile meant for production.
  Never switch to a newer major release or a BETA on your own
  (`AGENTS.md`: stable release tracks).
- **An update installs into a new boot environment and takes effect
  at the reboot.** Apply updates in the web UI (System > Update)
  or with `midclt call -j update.run '{"reboot": false}'`, only
  after asking, with the release notes of the target version read
  and the configuration file downloaded (Configuration Model).
  The reboot is a separate question (`AGENTS.md`: ask before
  reboots); a reboot interrupts every share, app and VM.
- `midclt call system.reboot.info` lists the reasons a reboot is
  pending (25.04 and later; 24.10 has only the `REBOOT_REQUIRED`
  above).
- **Boot environments** are the rollback path: System > Boot lists
  them; `midclt call boot.environment.query` reads them. Activating
  an older one (`boot.environment.activate`) and rebooting rolls the
  system back. Destroying one removes that path; ask first, and
  never destroy the active one or the one marked to keep.
- Major upgrades (e.g. 25.04 → 25.10) follow the version notes of
  the target release, which list removed features. Hand the
  decision to the user.

## Replace: Firewall

- **TrueNAS has no host firewall.** The docs recommend keeping
  the web UI and other management interfaces on private subnets
  and reaching the host over a VPN
  (<https://www.truenas.com/docs/solutions/optimizations/security/>).
  A missing ufw, firewalld or nftables ruleset is not a finding.
  Do not install or enable one: apt is disabled, a hand-made
  ruleset is not managed by the middleware, and Docker (Apps) and
  Enterprise HA write their own netfilter rules.
- Report instead:
  - `ui_allowlist` in `midclt call system.general.config`: the
    addresses allowed to reach the web UI and the API. An empty list
    allows everyone. It is not a firewall; shares and SSH are not
    covered by it.
  - Which services run (`midclt call service.query`) and which ports
    the apps publish (see Apps).
  - Whether the host is reachable from the internet, if the user
    knows. Exposure belongs to the router or firewall in front of it.

## Replace: Service Manager

- `systemctl status`, `journalctl -u` and `systemctl is-active` are
  fine for reading.
- **Start, stop, reload and restart services through the
  middleware**, which renders their config first:
  `midclt call service.query` lists them with `enable` and `state`;
  `midclt call -j service.control RELOAD <service>` (verbs `START`,
  `STOP`, `RESTART`, `RELOAD`) controls one; 25.04 has
  `service.reload <service>` and its siblings instead. Starting at
  boot is the "Start Automatically" setting in System > Services.
  A service restarted with `systemctl` runs on a config that the
  middleware may render differently on its next pass.
- `rules/service-reload.md` still decides when to ask. Stopping or
  restarting `cifs` or `nfs` interrupts every client of the shares.
- Never restart `middlewared` on your own: the web UI, the API and
  every task depend on it.

## Replace: Networking

- **The middleware owns the network.** Interfaces, addresses,
  VLANs, bonds and bridges are set under Network in the web UI or
  with `interface.*` methods; the default gateway, DNS servers and
  the hostname with `network.configuration.update`; static routes
  with `staticroute.*`. Never edit `/etc/network/interfaces`,
  netplan or `resolv.conf`, and never run `ip addr`/`ip route`
  changes by hand: the middleware replaces them on its next sync.
- `ip addr`, `ip route` and `midclt call interface.query` are fine
  for reading.
- Interface changes are staged, and the middleware arms its own
  revert when it applies them (`rules/ssh-safety-net.md`):
  - Check: `midclt call interface.has_pending_changes`, and the
    staged interfaces in `midclt call interface.query`.
  - Apply and arm:
    `midclt call interface.commit '{"rollback": true, "checkin_timeout": 300}'`.
    The middleware rolls the change back after 300 seconds unless
    it is checked in. `interface.checkin_waiting` shows the seconds
    left.
  - Confirm: `midclt call interface.checkin` keeps the change.
  - Revert by hand: `midclt call interface.rollback`.
- Gateway, DNS, hostname and static route changes apply at once and
  have no revert (`rules/ssh-safety-net.md`).

## Replace: Directory Conventions

- `/mnt/<pool>/…`: pools and datasets. Everything the user keeps
  lives here.
- `/mnt/.ix-apps`: the apps' dataset, owned by the middleware.
- `/etc`: rendered by the middleware, see Configuration Model.
- `/usr`, `/opt` and `/conf` are read-only datasets on the boot
  pool; `/home` is mounted `noexec`. Put a script the user wants to
  keep on a pool.
- `/var/log`: its own dataset on the boot pool, see Logs.

## Remove: Notes

## Remove: Common Pitfalls

## Pools and Datasets

- **Everything ZFS goes through the middleware**: Storage and
  Datasets in the web UI, or `pool.*` and `pool.dataset.*` methods.
  Never `zpool` or `zfs` commands that write (`create`, `destroy`,
  `set`, `import`, `export`, `replace`, `offline`, `attach`,
  `detach`, `rollback`) by hand. The middleware keeps its own
  record of pools, datasets, shares and tasks, and a hand change
  leaves it disagreeing with ZFS.
- Reading with `zpool status`, `zpool list`, `zfs list` and
  `zfs get` is fine.
- The disk taboos in `AGENTS.md` hold unchanged. Wiping a disk
  (Storage > Disks > Wipe, `disk.wipe`), creating, extending or
  exporting a pool, replacing a disk, and destroying a dataset or
  snapshot all end in destroyed data or a changed partition table.
  They happen only on the user's explicit request, and a wipe or a
  pool change is theirs to run in the web UI.
- A degraded pool is not repaired by commands in a hurry. Report
  `zpool status` in full and let the user decide; a disk
  replacement goes through Storage > Manage Devices.
- Before any destructive dataset change, show from the live host
  and in one call what it hits: the dataset, its children, their
  snapshots, the shares and the apps that use it
  (`midclt call pool.dataset.query '[["id","=","<dataset>"]]'`,
  `midclt call pool.dataset.attachments <dataset>`).

## Apps and Virtual Machines

- **Apps are managed by TrueNAS** (Docker since 24.10), through
  Apps in the web UI or `app.*` methods. `midclt call app.query`
  lists them; `upgrade_available` marks an update of the app,
  `image_updates_available` a newer image. Updating is
  `app.upgrade`, a job; ask first.
- Never manage the apps' containers with `docker` or
  `docker compose`, and never edit files under `/mnt/.ix-apps`:
  the middleware renders them and overwrites the change. `docker ps`
  and `docker logs` are fine for reading.
- A catalog app is maintained by the TrueNAS apps catalog; a custom
  app (Install via YAML) is the user's. Report which one an app is
  before recommending an update.
- `rules/service-class-check.md` still applies: TrueNAS already
  brings Samba, NFS, an nginx for its UI and more.
- Virtual machines are managed under Virtualization. Stopping or
  deleting one powers off or destroys a server: only on the user's
  explicit request.

## Logs

- The journal is persistent: `/var/log/journal` is its own dataset.
  `logger -t hostwarden` reaches it and, through syslog-ng,
  `/var/log/syslog`. The activity check's journal read-back from
  `rules/activity-check.md` applies unchanged.
- The middleware logs to `/var/log/middlewared.log`; app and job
  output shows in the web UI's Jobs panel.

## Housekeeping and Audits

- Read, in one call; `select` keeps the JSON to the fields the
  findings need. Before 25.10, `update.check_available` takes the
  place of `update.status`, and on 24.10 `system.reboot.info` is
  left out (see Updates):
  ```
  midclt call alert.list
  midclt call update.status
  midclt call system.reboot.info
  midclt call pool.query '[]' '{"select": ["name", "status", "healthy", "scan"]}'
  midclt call pool.scrub.query '[]' '{"select": ["pool_name", "threshold", "enabled"]}'
  midclt call pool.snapshottask.query '[]' '{"select": ["dataset", "enabled", "state"]}'
  midclt call replication.query '[]' '{"select": ["name", "enabled", "state"]}'
  midclt call app.query '[]' '{"select": ["name", "state", "upgrade_available", "image_updates_available", "custom_app"]}'
  ```
- Findings:
  - **Alerts**: every entry of `alert.list` that is not dismissed,
    with its level. TrueNAS raises its own alerts for pool state,
    capacity, SMART errors, failed tasks and pending updates.
  - **Pool status**: `status` other than `ONLINE` or `healthy`
    false is CRIT; then read `zpool status` in full (Pools and
    Datasets).
  - **Scrub age**: `scan.end_time`, when `scan.function` is
    `SCRUB`; after a resilver `scan` describes that instead, and
    the scrub age is unknown until the next scrub. A scrub task
    scrubs once the last scrub is `threshold` days old (35 by
    default). A last scrub older than that plus a week, or a pool
    without an enabled scrub task, is WARN.
  - **SMART**: TrueNAS polls SMART itself and reports trouble
    through alerts. Read `smartctl -a /dev/<disk>` only when an
    alert names a disk.
  - **Pending update** and a pending reboot (see Updates).
  - **Snapshot and replication tasks**: `state` is an object; a
    task whose `state.state` is `ERROR` is WARN, reported with
    `state.error` and `state.datetime`. Pools with data and no
    snapshot task are a finding to report, not to fix.
  - **Apps** with an update available.
- A security audit also reports: the SSH service's settings
  (`midclt call ssh.config`: root login, password login), users with
  SSH access and "no password" sudo, the web UI's `ui_allowlist`,
  and API keys (`midclt call api_key.query`, names and expiry only,
  never the key).
- Fleet audit: a missing `unattended-upgrades` or host firewall is
  not drift.
