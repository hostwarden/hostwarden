# Proxmox VE

Base: `rules/os/debian.md`
Hardware: any

A Proxmox VE node is a Debian host, and this file applies on top of
the base (`rules/os-detection.md` → Appliances). Every guest on the
node, and on a cluster every other node, depends on what you do
here.

Source for everything below unless noted: the admin guide,
<https://pve.proxmox.com/pve-docs/pve-admin-guide.html>.

## Add: Version Detection

- `pveversion` prints
  `pve-manager/<version>/<repoid> (running kernel: <uname -r>)`.
  `pveversion -v` lists every Proxmox package.
- `/etc/pve` exists on every node (it is the cluster filesystem,
  see below).
- Clustered or standalone: `pvecm status`. A cluster shows
  `Quorate:`, `Expected votes:` and a member list; `pvecm nodes`
  lists the nodes.
- Record in server memory: `Appliance: Proxmox VE <version>`, and
  the cluster name and node count, or `standalone`.
- PVE 9 is based on Debian 13 (Trixie), PVE 8 on Debian 12
  (Bookworm). Take end-of-life dates from the support table in the
  FAQ (<https://pve.proxmox.com/wiki/FAQ>), never from memory. A
  node on a release past its end of life is a finding.

## Remove: Package Manager > Dry-run before upgrading

## Add: Package Manager

- **Always `dist-upgrade` / `full-upgrade`, never plain
  `upgrade`.** Proxmox: `apt upgrade` "may result in a partially
  upgraded or broken package state", because only `full-upgrade`
  can remove packages to satisfy dependencies.
- Dry-run first and show the user what it would install and
  remove:
  ```
  apt-get update
  apt-get -s dist-upgrade
  ```
  If it wants to remove `proxmox-ve`, **stop** — that removes
  Proxmox itself.
- `pveupgrade` runs an interactive `apt-get dist-upgrade` and
  refuses when the package index is older than 3 days. It waits
  for input, so Hostwarden uses `apt-get` directly.
- Install only what the node needs: a desktop or other large extras
  are "not supported" and make upgrades hard.

## Remove: Common Pitfalls > Prefer `apt-get upgrade`

## Remove: Common Pitfalls > Before enabling `ufw`

## Remove: Common Pitfalls > `ufw` must be enabled

## Repositories

- Three Proxmox repositories:
  - `pve-enterprise` — needs a subscription; Proxmox's
    recommendation for production. Enabled by default.
  - `pve-no-subscription` — usable without a subscription, "not
    recommended" for production by Proxmox because it is less
    tested.
  - `pve-test` (PVE 8: `pvetest`) — developers and testing only.
    **Never enable it on a production node** (`AGENTS.md`: stable
    release tracks).
- PVE 9 uses deb822 files: `/etc/apt/sources.list.d/proxmox.sources`,
  `pve-enterprise.sources`, `ceph.sources`, `debian.sources`. A
  stanza is switched off with `Enabled: no`, not by deleting the
  file.
- PVE 8 uses one-line `.list` files. After the upgrade to 9,
  `apt modernize-sources` converts them.
- The enterprise repository without a subscription makes
  `apt-get update` fail. Ask the user which repository the node
  should use before changing anything; never switch silently.
- Do not touch the keyring
  (`/usr/share/keyrings/proxmox-archive-keyring.gpg`); the
  `proxmox-archive-keyring` package owns it.

## Replace: Automatic Security Updates

- **`unattended-upgrades` is not the default and not a finding.**
  A Proxmox staff member warned that by default it pulls updates
  from the Debian repositories only, which "might cause problems"
  (<https://forum.proxmox.com/threads/139808/>). Report pending
  updates instead of flagging the missing package. Setting it up
  is the user's decision.
- The node checks for updates daily and notifies `root@pam`.
  Whether that reaches anyone depends on the targets and matchers
  in `/etc/pve/notifications.cfg`, an email address on `root@pam`
  (`pveum user list`) and a working MTA.

## Updates

- **Reboot needed:** every kernel update needs one, and Proxmox
  does not write `/run/reboot-required`
  (<https://forum.proxmox.com/threads/156352/>). Compare `uname -r`
  with the newest installed `proxmox-kernel-*` package.
  `proxmox-boot-tool kernel list` shows which kernels are set up
  for booting.
- On a cluster, update one node at a time. Update
  `pve-ha-manager` "never all at once": without an active HA master
  a node can be reset by the watchdog.
- **Major upgrades** (e.g. 8 → 9) follow the official upgrade
  guide (<https://pve.proxmox.com/wiki/Upgrade_from_8_to_9>). Run
  the checker (`pve8to9 --full` for 8 → 9) first; it changes
  nothing. The guide wants console access and warns against doing
  it from the web console. Over SSH only inside `tmux` or `screen`,
  and only after asking the user.

## Replace: Firewall

- **Expected:** `pve-firewall`, not `ufw` or `firewalld`. Do not
  install either: they would manage the same netfilter tables.
- The firewall is **disabled by default** at the datacenter level.
  It is enabled with `enable: 1` under `[OPTIONS]` in
  `/etc/pve/firewall/cluster.fw`.
- Config files, on the cluster filesystem, so they replicate to
  every node:
  - `/etc/pve/firewall/cluster.fw` — datacenter
  - `/etc/pve/nodes/<node>/host.fw` — one node
  - `/etc/pve/firewall/<vmid>.fw` — one guest
- Default `policy_in` is `DROP`. Even so, the management ports stay
  open for the `management` IPSet and the local cluster network:
  22, 8006 (web UI), 5900–5999 (VNC), 3128 (SPICE), 60000–60050
  (migration), 5405–5412/udp (corosync).
- Read-only: `pve-firewall status`, `pve-firewall compile` (shows
  the generated rules without applying them),
  `pve-firewall localnet`, and `pve-firewall simulate` (`--from`,
  `--to`, `--source`, `--dport`) to test a packet against the rules
  before tightening them.
- **Before enabling or tightening:** keep a second SSH session
  open (the admin guide says so), check that the `management` IPSet
  contains the address you connect from, and ask the user. A wrong
  rule in `cluster.fw` locks you out of every node at once.
- `pve-firewall stop` removes all Proxmox rules and leaves the host
  unprotected. It is not a harmless test step.
- The nftables-based `proxmox-firewall` is a tech preview, "not
  suited for production use". Do not switch to it on your own.

## Cluster Filesystem (`/etc/pve`)

- `/etc/pve` is `pmxcfs`, a FUSE filesystem backed by an SQLite
  database (`/var/lib/pve-cluster/config.db`) and replicated to
  all nodes in real time. An edit on one node is an edit on every
  node.
- No symlinks, no `chmod`, 128 MiB total. It goes **read-only when
  the node loses quorum**.
- `rules/backups.md` still applies. Never leave a backup inside
  `/etc/pve`: it replicates to every node and counts against the
  128 MiB.
- **`corosync.conf`:** never edit `/etc/pve/corosync.conf` in
  place. Copy it to `corosync.conf.new`, edit the copy, increment
  `config_version`, keep a `.bak` (the one backup the admin guide
  keeps inside `/etc/pve`), then `mv` the new file into place. A
  broken corosync config splits the cluster.
- Use `pvecm` for membership changes, never hand edits.
- Changing the hostname or IP of a cluster node is not possible
  after the cluster exists. Refuse and explain.

## Quorum, HA and Reboots

- `pvecm status` shows quorum; `ha-manager status` shows HA
  services and the fencing state.
- **Fencing:** a node with active HA services that loses quorum is
  reset by the watchdog after about 60 seconds. Never kill or stop
  `pve-ha-crm`, `pve-ha-lrm` or `watchdog-mux`; the admin guide
  warns that killing them can reboot or reset the node immediately.
- Restarting `corosync` or `pve-cluster` risks quorum loss. Ask
  first, even when `memory/service-policy.md` allows restarts
  without asking. On PVE 9.2 and later, HA can be disarmed for the
  duration (`ha-manager crm-command disarm-ha freeze`, afterwards
  `ha-manager crm-command arm-ha`). Re-arm before leaving: the 9.2
  release notes list a package upgrade that stalls while HA is
  disarmed until `arm-ha` runs.
- `pvecm expected 1` forces quorum. Never use it unless the user
  explicitly asks and understands the split-brain risk.
- **Rebooting a node** (always ask first):
  1. `qm list`, `pct list`: what runs here. `ha: shutdown_policy`
     in `/etc/pve/datacenter.cfg` (default `conditional`) decides
     whether a reboot freezes or migrates HA guests.
  2. On a cluster: maintenance mode
     (`ha-manager crm-command node-maintenance enable <node>`)
     moves **HA-managed** guests away only. Move the others with
     `pvenode migrateall <target> --max-workers <n>`
     (`--max-workers` is required unless `datacenter.cfg` sets
     `max_workers`). It migrates offline by default; guests on
     local disks need `--with-local-disks`.
  3. Confirm with `ha-manager status`, `qm list` and `pct list`
     that nothing is left running on the node.
  4. Reboot, and wait for `pvecm status` to show the node back and
     quorate.
  5. `ha-manager crm-command node-maintenance disable <node>`.
     Maintenance mode survives the reboot; forgetting this step
     keeps the node empty.
- On a standalone node, a reboot stops every guest. The
  `pve-guests` service shuts them down cleanly (180 s per guest by
  default, then a hard stop). Say how many guests will stop and
  ask.

## Guests

- List: `qm list` (VMs), `pct list` (containers). Task logs of the
  web UI are under `/var/log/pve/tasks/`.
- Config: `qm config <vmid>`, `pct config <vmid>`.
- Migrate: `qm migrate <vmid> <target> --online` (VM, live),
  `pct migrate <vmid> <target> --restart` (containers have no live
  migration; the restart is a reboot of that guest, so ask first).
- **Stopping or deleting a guest** powers off or destroys a
  server: `rules/system-containers.md` → Changes. The clean stop is
  the `shutdown` subcommand of `qm` or `pct`; `qm stop` /
  `pct stop` is a hard power cut.
- Reaching a guest through `pct exec` or `qm guest exec`, and
  snapshots before a risky change: `rules/system-containers.md`.
- Guests with `onboot: 1` start when the node boots. HA-managed
  guests ignore `onboot` and start order.
- **Inventory** (`rules/hypervisors.md`): record
  `Hypervisor: Proxmox VE (qm, pct)`. The full inventory is one
  call: `pvesh get /cluster/resources --type vm --output-format
  json`, filtered to this node's `node` (it carries `status` and
  `template`), and the head of every guest config on this node up
  to its first snapshot section:

  ```bash
  for f in /etc/pve/qemu-server/*.conf /etc/pve/lxc/*.conf; do
    echo "@conf $f"
    sed -n '/^\[/q; /^net[0-9]*:/p; /^smbios1:/p;
      /^onboot:/p; /^agent:/p' "$f"
  done
  cat /etc/pve/ha/resources.cfg
  ```

  A VM's MAC is the value after its model (`virtio=`, `e1000=`)
  in `netN:`, a container's the `hwaddr=` value; the UUID is
  `uuid=` in `smbios1:`. `resources.cfg` names the HA-managed
  guests (`vm: 101`, `ct: 102`); their entry says `HA` instead of
  autostart, since HA ignores `onboot`. The light listing is
  `qm list; pct list`.
- **Guest tools:** only for a VM whose `agent:` line enables it,
  `qm guest cmd <vmid> get-host-name`, `get-osinfo` and
  `network-get-interfaces`.

## Replace: Networking

- `/etc/network/interfaces` with `ifupdown2`. Guests hang off
  bridges (`vmbr0`, …); the node's own IP usually sits on a bridge
  too.
- Apply changes with `ifreload -a`. Never `ifdown`/`ifup` a bridge:
  `ifdown vmbrX` cuts every guest on it, and `ifup` does not
  reconnect them.
- The web UI stages changes in `/etc/network/interfaces.new`.
  "Apply Configuration" applies them live; otherwise `pvenetcommit`
  activates the file at the next boot and overwrites hand edits
  made in the meantime. Check for a pending `.new` file before
  editing by hand, and compare the two.
- Network changes can cut SSH to the node. Ask the user first, and
  make sure they have console access (IPMI, physical) before
  `ifreload -a`.
- SDN config lives in `/etc/pve/sdn`. Changes stay pending until
  applied in the SDN panel, then apply cluster-wide.

## Storage

- `pvesm status` for all storages; `/etc/pve/storage.cfg` is shared
  by all nodes.
- ZFS: `zpool status`, `zfs list`. LVM-thin: `lvs` (watch `Data%`
  and `Meta%`: a full thin pool stops guest writes).
- Ceph: `pveceph status` or `ceph -s`. Anything that is not
  `HEALTH_OK` goes to the user before any reboot.

## Add: Service Manager

- `pveproxy` serves the web UI on port 8006. **Reload, don't
  restart:** a restart cuts running consoles and shells.
- `pvedaemon`, `pvestatd`, `pvescheduler` and `spiceproxy` are the
  other API and job daemons.
- `pve-cluster`, `corosync`, `pve-ha-crm`, `pve-ha-lrm`: see
  Quorum, HA and Reboots.

## Backups

- Guest backups: `vzdump`. Default target `/var/lib/vz/dump/`,
  defaults in `/etc/vzdump.conf`, schedules in `/etc/pve/jobs.cfg`.
  Proxmox recommends Proxmox Backup Server on a separate host.


## Housekeeping and Audits

- Check quorum (`pvecm status`) and a pending reboot (see
  Updates).
- A missing backup job for running guests is a finding.
- USB passthrough for the USB inventory
  (`.agents/skills/hostwarden-housekeeping/references/usb-devices.md`),
  in the same call as its probe. A VM's line reads
  `host=<vendor>:<product>` or a bus port:

  ```sh
  grep -H '^usb[0-9]*:' /etc/pve/qemu-server/*.conf
  grep -HE '^dev[0-9]*:|lxc.mount.entry.*(ttyUSB|ttyACM|serial)' /etc/pve/lxc/*.conf
  ```
- Fleet audit: compare Proxmox VE nodes only with each other. Show
  `pve-firewall` in the firewall rows; a missing
  `unattended-upgrades` is not drift.

## Add: Common Pitfalls

- A missing Debian stock kernel is expected (Proxmox ships its own
  `proxmox-kernel-*`, and installs on top of Debian remove the
  stock one); do not reinstall `linux-image-amd64`.
- The "no valid subscription" notice in the web UI is not a fault.
  Do not patch it away.
