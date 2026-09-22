# TrueNAS

Base: `rules/os/debian.md`
Hardware: any

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
    only what their role allows. Never pass `-U`/`-P` or an API key
    on the command line (`rules/secrets.md`); how a key is used is
    under API.
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

## API

Everything the web UI does goes through the middleware's API:
JSON-RPC 2.0 over a WebSocket, which `midclt` reaches over the
local socket and a remote client at `wss://<host>/api/current`
(25.04 and later; 24.10 has only the older protocol at
`/websocket`). The REST API under `/api/v2.0` is deprecated since
25.04 and is never used
(<https://www.truenas.com/docs/scale/25.10/api/>). The procedure is
`rules/appliance-api.md`; this section adds what is TrueNAS's own,
and names where it differs.

The middleware enforces roles on every call, the local socket
included: a `midclt` run by a user other than root gets that user's
roles, which come from the privileges of the user's groups
(`truenas/middleware`, `src/middlewared/middlewared/plugins/auth.py`,
`check_permission`, 25.10.7). `sudo midclt` runs as root and reaches
everything, so read access never uses `sudo`. The **Readonly Admin**
role (`READONLY_ADMIN`) expands into every `*_READ` role: it calls
any query and read-only method and none that creates, updates or
deletes (<https://api.truenas.com/v25.10/rbac.html>). A method
outside the caller's role answers `Not authorized`.

### Setting up access

- **Read access: a user `api-read` with the Readonly Admin role and
  SSH access.** The user creates it under Credentials > Users > Add:
  TrueNAS Access with the role **Readonly Admin**, SSH Access on,
  the workstation's public key in Public SSH Key, "Allow SSH Login
  with Password" off, a home directory and a login shell (SSH needs
  both), and no sudo of any kind; the docs say "Do not allow sudo
  permissions for read-only administrators"
  (<https://www.truenas.com/docs/scale/25.10/scaleuireference/credentials/usersscreen/>,
  <https://www.truenas.com/docs/scale/25.10/scaletutorials/credentials/adminroles/>).
  Nothing is stored on the workstation but the SSH key it already
  has: the login is the credential, and the role that the
  middleware enforces keeps it from writing.
- **Write access: the account that makes changes today**, the admin
  user the session connects as (Access and Shell), usually with Full
  Admin. Where the user wants less, a user whose role covers only
  what Hostwarden is meant to change, such as Sharing Admin for
  shares. With `API write: none` Hostwarden makes no change through
  the API: every change goes to the user as web UI steps, even where
  the session's SSH user could make it.
- **API keys, for the workstation path only** (see How a call
  reaches the API). The user creates each key for the account it
  belongs to, signed in as that account under the user menu in the
  top toolbar > My API Keys > Add API Key, or under Credentials >
  Users > the user > View API Keys, and sets an expiry date rather
  than the default of none. A key has exactly its user's roles, so
  the read key belongs to `api-read` and the write key to the write
  account. TrueNAS shows the key once; a lost key is reset. **A key
  is not subject to its user's two-factor authentication, and
  TrueNAS revokes a key that arrives over plain HTTP**
  (<https://www.truenas.com/docs/scale/25.10/scaletutorials/toptoolbar/managingapikeys/>).
  Each key file holds one line, the key exactly as shown
  (`<id>-<key>`): `truenas-ro.key` for the read key,
  `truenas-rw.key` for the write key.
- The first read confirms the access: `midclt call auth.me` as the
  read user names the user and its privilege.
- Server memory records `API read: api-read (Readonly Admin)`,
  with the key file after the role on the workstation path only.
  `api-read` is an account on the appliance, recorded there, never
  in `memory/user.md` (`rules/ssh-user.md`): it serves API reads
  and never replaces the session's SSH user.

### How a call reaches the API

- **Over SSH, the default**, on every release this file covers.
  `midclt` runs on the host as the SSH user against the local
  socket, so no key exists anywhere and the web UI's port does not
  have to be reachable. The `midclt` that 25.10 ships takes a key
  only as an argument, which `rules/secrets.md` forbids.
- **From the workstation**, only where SSH stays off or the user
  prefers it, and only against 25.04 and later, recorded as
  `API path: workstation`. The client is `midclt` from TrueNAS's
  own `truenas_api_client` (<https://github.com/truenas/api_client>),
  installed on the workstation into its own virtual environment
  (`pipx`) from a release tag. Only the 26.0 tags (`TS-26.0.0…`)
  and later read the key from a file, `-K` followed by an absolute
  path; an older tag takes the key only as an argument and is not
  used. Look
  up the tag to install as `rules/version-check.md` says, and read
  the installed client's `midclt -h` before the first call. A call:

  ```
  midclt -u wss://<host>/api/current -U api-read \
    -K ~/hostwarden-keys/<host>/truenas-ro.key --plain call system.info
  ```

  `--plain` sends the key inside TLS, which a server before 26
  needs; against 26 and later leave it off, and the client uses
  SCRAM, which never sends the key. The client checks the
  certificate's chain and name against the workstation's trust
  store; unlike `rules/appliance-api.md` → Reaching the API,
  `rules/tls-pinning.md` cannot apply, because `midclt` has no pin
  option. TrueNAS's own self-signed certificate names only
  `localhost` and fails that check, so this path needs a certificate
  for the name the workstation uses, from a CA it trusts, selected
  under System > General Settings > GUI > Settings > GUI SSL
  Certificate
  (<https://www.truenas.com/docs/scale/25.10/scaletutorials/systemsettings/general/>).
  Never `--insecure`, and never `ws://`.

### Reading

- **Over SSH no credential travels on stdin**, so unlike
  `rules/appliance-api.md` → Reaching the API, a task's reads go
  into one `sh -s` bundle run as the read user
  (`rules/ssh-connections.md` → Bundle commands):

  ```
  ssh … api-read@<host> sh -s <<'EOF' | jq …
  o=$(midclt call alert.list); r=$?
  printf '%s' "$o" | tr -d '\n'; echo
  echo "{\"@\": \"alert.list\", \"rc\": $r}"
  o=$(midclt call update.status); r=$?
  printf '%s' "$o" | tr -d '\n'; echo
  echo "{\"@\": \"update.status\", \"rc\": $r}"
  EOF
  ```

  The line-by-line filter of `rules/appliance-api.md` → Reading
  reads each line as one document, and `midclt`'s output format is
  not documented: a pretty-printed answer would span lines and be
  dropped. `tr -d '\n'` puts each answer on one line of its own
  before it leaves the host, whatever the client does; a `midclt`
  that already answers on one line is unchanged by it.
  **The marker follows its answer and carries `midclt`'s exit
  status**, which `tr` and `echo` would otherwise hide: a marker
  printed first would count a method that failed — unavailable on
  that release, or refused to the read role — as a completed read.
  An `rc` other than 0, or a missing marker, is a check that did
  not run.

  On the workstation path, unlike `rules/appliance-api.md` →
  Reading, each method is its own `midclt` call and its own login,
  because the client takes one method per call; call only what the
  task needs.
- The filter's pattern gains:
  ```
  passwd|pass_$|bindpw|key$|key_id|hash$|salt|credentials|attributes|compose_config
  ```
  These cover the fields that 25.10's API marks as secret beyond
  the pattern's own words: `unixhash`, `smbhash`, `keyhash`, the
  cloud credentials' `attributes`, a cloud sync task's
  `credentials`, a custom app's compose config, and the SNMP, iSCSI
  and NVMe keys (`truenas/middleware`,
  `src/middlewared/middlewared/api/v25_10_0/`). A `select` in the
  query options (Housekeeping and Audits) keeps the host from
  sending the rest.

### Writing

- Pools and Datasets names what to show before a dataset change. A
  method that runs as a job gets `-j`.
- The backup is the `…config` or `…get_instance` of what changes,
  read as the read user straight into the backup file.
- **The body is a file on the workstation**, and unlike
  `rules/appliance-api.md` → Writing it is not copied to the host:
  a `midclt` from 26.0 on reads it from stdin when the last argument
  is `-`: over SSH
  `ssh … <write-user>@<host> "midclt call <method> <id> -" < body.json`,
  from the workstation `midclt … call <method> <id> - < body.json`.
  The `midclt` of 24.10 to 25.10 has no `-`, so there, unlike
  `rules/appliance-api.md` → Writing, the body goes as an argument,
  and a body that carries a secret — a password, a cloud key, a
  private key — is entered by the user in the web UI instead.
- The API has no dry-run; a wrong body comes back as a validation
  error.
- Replace: Networking names the one revert the middleware arms by
  itself for a change that can cut the way in.

### What stays on SSH

The API does not stand in for the session's own SSH user (Access
and Shell) for the journal, `/var/log/middlewared.log`,
`zpool status` in full, `smartctl`, `docker logs` and the
Hostwarden journal line: they are read or written as that user, as
the rest of this file describes. The read user has no sudo and
never replaces it.

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
- Software that TrueNAS does not ship runs as an app (see Apps),
  not on the host.

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
  is `AVAILABLE`, `UNAVAILABLE`, `REBOOT_REQUIRED` once an update is
  applied and awaits the reboot, or `HA_UNAVAILABLE` when HA is
  down and nothing was checked (`truenas/middleware`,
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

## Apps

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

## Virtual Machines and Containers

- Which managers a release has comes from the middleware's
  plugins at each release tag (`truenas/middleware`,
  `src/middlewared/middlewared/plugins/`):

  | Release          | VMs  | Containers      |
  | ---------------- | ---- | --------------- |
  | 24.10            | `vm` | none            |
  | 25.04.0, 25.04.1 | none | `virt.instance` |
  | 25.04.2 to 25.10 | `vm` | `virt.instance` |
  | 26               | `vm` | `container`     |

  `vm` is the Virtual Machines screen (Virtualization on 24.10).
  `virt.instance` is Incus, on the Containers screen (Instances
  on 25.04.0 and 25.04.1), and holds VMs as well as containers:
  `type` says which. A VM created under Instances stays there
  after an update
  (<https://www.truenas.com/docs/scale/25.04/gettingstarted/scalereleasenotes/>).
  26's `container` is LXC through libvirt.
- **Every change to a guest is the user's, in the web UI**:
  creating, changing, starting, stopping, deleting. Stopping or
  deleting one powers off or destroys a server
  (`rules/system-containers.md` → Changes). Never `virsh`,
  `incus` or `lxc-*`: the middleware keeps its own record of every
  guest, and those tools go around it.
- **Inventory** (`rules/hypervisors.md`): record
  `Hypervisor: TrueNAS (<managers>)` with the managers the table
  gives the release and a listing shows guests in, `vm`,
  `virt.instance` or `container`; each entry in `guests.md` starts
  with its manager (`vm: 3 web1`). The reads run the way
  Housekeeping and Audits runs its reads, as the `API read:` user
  where one is recorded, and only the calls the release has:

  ```
  midclt call vm.query '[]' '{"select": ["id", "name", "uuid", "autostart", "status.state"]}'
  midclt call vm.device.query '[["attributes.dtype", "=", "NIC"]]' '{"select": ["vm", ["attributes.mac", "mac"]]}'
  midclt call virt.global.config
  midclt call virt.instance.query '[]' '{"select": ["id", "type", "status", "autostart", "aliases"]}'
  midclt call container.query '[]' '{"select": ["id", "name", "autostart", "status.state"]}'
  midclt call container.device.query '[["attributes.dtype", "=", "NIC"]]' '{"select": ["container", ["attributes.mac", "mac"]]}'
  ```

  The MAC is selected as `mac` because API → Reading's filter
  drops every `attributes` key. On 24.10 `dtype` is a field of the
  device itself: the filter there is `[["dtype", "=", "NIC"]]`
  (`plugins/vm/vm_devices.py` on the 24.10 branch).
  - A VM's `uuid` is its libvirt domain UUID
    (`plugins/vm/supervisor/domain_xml.py`) and is recorded.
  - `virt.instance.query` answers `[]` while `virt.global.config`
    has a `state` other than `INITIALIZED`: that is Containers not
    set up, never proof that none exist
    (`plugins/virt/instance.py`, TS-25.10.7). Its instances are
    then unreadable, not gone. Their MACs come from
    `midclt call virt.instance.device_list <id>`, one per instance
    in a second call, which shows a NIC's `mac` only where one was
    set by hand; Incus generates the rest into the instance's
    `raw` config, which carries its environment too and is never
    read. An instance without one is recorded `mac unknown`.
  - No release up to 26 has templates.
  - The light listing is `vm.query`, `virt.global.config`,
    `virt.instance.query` and `container.query`, with `"select"`
    narrowed to `id` and the state field.
  - A guest is gone once `vm.get_instance <id>`,
    `virt.instance.get_instance <id>` or
    `container.get_instance <id>` answers that it does not exist
    (`service/crud_service.py`), all of them in one call with
    `virt.global.config`; for `virt.instance`, only while that
    says `INITIALIZED`.
- **Guest tools:** none. No release up to 26 has a read-only
  method for a VM's guest agent. A `virt.instance` lists its
  global addresses in `aliases`; a `container` from 26 on lists
  none.
- **Registering:** none. TrueNAS enters a guest only through the
  web UI's shell (`virt.instance.get_shell` and `container.nsenter`
  are private methods), so every guest stays in `guests.md` alone
  until it is connected to by name.

## Logs

- The journal is persistent: `/var/log/journal` is its own dataset.
  `logger -t hostwarden` reaches it and, through syslog-ng,
  `/var/log/syslog`. The activity check's journal read-back from
  `rules/activity-check.md` applies unchanged.
- The middleware logs to `/var/log/middlewared.log`; app and job
  output shows in the web UI's Jobs panel.

## Housekeeping and Audits

- Read, in one call; `select` keeps the JSON to the fields the
  findings need. Where server memory records `API read:`, the call
  runs as that user with the markers and the filter from API >
  Reading, otherwise as the session's SSH user. Before 25.10 the
  update and reboot calls differ (see Updates):
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
- A security audit also reports, read through the API as above:
  the SSH service's settings (`midclt call ssh.config`: root login,
  password login), users with SSH access and "no password" sudo, the
  web UI's `ui_allowlist`, and the API keys:
  ```
  midclt call api_key.query '[]' '{"select": ["name", "username", "created_at", "expires_at", "revoked", "revoked_reason"]}'
  ```
  and, in the same call, every user's roles, matched to the keys
  afterwards:
  ```
  midclt call user.query '[]' '{"select": ["username", "roles"]}'
  ```
  Never the key, and `keyhash` is not selected. A key without an
  expiry whose user has Full Admin is WARN (see API → Setting up
  access for why). A revoked key is INFO with its
  `revoked_reason`; a key whose user no longer exists comes back
  revoked, with that as the reason.
- Fleet audit: a missing `unattended-upgrades` or host firewall is
  not drift.
