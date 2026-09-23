# XCP-ng

Base: `rules/os/rhel.md`
Hardware: any

An XCP-ng host is a Xen hypervisor, and the shell you reach over
SSH is its control domain, dom0: a CentOS 7 userland with security
fixes backported by the XCP-ng team, a patched 4.19 kernel, and the
XAPI toolstack (<https://docs.xcp-ng.org/releases/release-8-3/>).
This file applies on top of the base (`rules/os-detection.md` →
Layers). Dom0 is not a general-purpose server: every VM on the
host, and in a pool every other host, depends on it.

XCP-ng: "day to day, nobody should log into a host directly"
(<https://docs.xcp-ng.org/management/users-permissions/>). The
management plane is XAPI, reached through Xen Orchestra, XO Lite or
the `xe` CLI. Hostwarden on dom0 reads state, runs `xe`, and
follows XCP-ng's own update procedure.

Source for everything below unless noted: the XCP-ng documentation,
<https://docs.xcp-ng.org/>.

## Add: Version Detection

- `/etc/os-release` has `ID="xcp-ng"`, and `VERSION_ID` is the
  XCP-ng version
  (<https://github.com/xcp-ng/xcp-ng-release/blob/8.3/src/xenserver/etc/os-release>).
- Pool role, in one call — this host's UUID, the master's UUID and
  every host's UUID:
  ```
  grep '^INSTALLATION_UUID=' /etc/xensource-inventory
  xe pool-list params=name-label,master
  xe host-list --minimal
  ```
  This host is the pool master (the docs also say coordinator)
  when its UUID is the pool's `master`; a pool of one host is
  standalone.
- Record in server memory: `Appliance: XCP-ng <version>`, and
  `standalone` or, for a pool of more than one host, the
  `Cluster:` line of `rules/hypervisors.md` → Clusters and Pools,
  named by the pool's `name-label`. A fresh host is in its own
  unnamed pool, so an empty `name-label` is normal. The pool's
  `cluster.md` adds `- Master: <member>` (Housekeeping and
  Audits).
- Take support dates from the releases page
  (<https://docs.xcp-ng.org/releases/>), never from memory. A host
  on a release past its end of support is a finding: releases
  below the current LTS get no bug or security fixes.

## Replace: Package Manager

- **Install nothing in dom0 unless the user asks for it, and then
  only with `yum` from XCP-ng's own repositories.** The supported
  list for 8.3 is
  <http://reports.xcp-ng.org/8.3/extra_installable.txt>; show the
  user that the package is on it before installing. The project
  gives best-effort support for its own additional packages and
  none for anything else
  (<https://docs.xcp-ng.org/management/additional-packages/>).
  A package XCP-ng does not carry goes into a VM.
- **Never enable another repository**, not even for one command
  with `--enablerepo`. The CentOS and EPEL repositories ship
  pre-installed but disabled; the docs warn that updates "may get
  pulled from there and overwrite XCP-ng packages and thus break
  your system". If a third-party repository is already enabled
  under `/etc/yum.repos.d/`, report it; turning it off
  (`enabled=0`) is a config edit (`rules/backups.md`) and the
  user's decision.
- Dry-run: `yum --assumeno update`. Installing anything follows
  Updates below.
- Never `pip install`, `curl | sh`, or a binary dropped into
  `/usr/local` on dom0. Monitoring agents are the documented
  exception, and only the ones the repositories carry: `net-snmp`
  and `netdata`
  (<https://docs.xcp-ng.org/management/monitoring/>).

## Replace: Automatic Security Updates

- **Not expected, and not a finding.** Dom0 updates follow Updates
  below; nothing installs them on its own. Do not install
  `yum-cron` or `dnf-automatic`. Pending updates are reported
  instead (Housekeeping and Audits).

## Updates

Source: <https://docs.xcp-ng.org/management/updates/>.

- **Xen Orchestra's Rolling Pool Update is the advised way** to
  update a pool: it migrates VMs away, updates and reboots one host
  after another, and disables HA, the load balancer and backup jobs
  for the duration. It needs every VM disk on shared storage. When
  the pool has Xen Orchestra, tell the user that is the route and
  update from dom0 only when they ask for it.
- **Always the pool master first.** "Other pool members must never
  run a higher version than the master"; a member updated first
  loses its connection to the pool. Never update one member on its
  own either; only a host alone in its pool is updated by itself.
- Before updating, as the docs list them: disable HA (see High
  Availability), check that no XAPI task runs (`xe task-list`),
  eject the guest-tools ISO from running VMs, disconnect
  passed-through devices, and do not run the update from an
  interactive console shell.
- Per host, starting with the master:
  1. Dry-run and show the user the list (`yum --assumeno update`).
  2. `xe host-disable uuid=<uuid>`: no new VMs start here.
  3. Reboot needed: `xe host-evacuate uuid=<uuid>` live-migrates
     every running VM to another host. Confirm with
     `xe vm-list resident-on=<uuid> is-control-domain=false
     params=name-label,power-state` that nothing is left running.
  4. `yum update -y`.
  5. Reboot, or for a control-plane-only update
     `xe-toolstack-restart` (never with HA on: see High
     Availability).
  6. `xe host-enable uuid=<uuid>` once the host is back, then the
     next host.
  7. After the last host, re-enable HA if it was on (High
     Availability).
- **Rebooting and evacuating are the user's decision**, every
  time: ask, and say how many VMs will move or stop. A host that
  cannot be evacuated (local storage, no room elsewhere) stops its
  VMs on reboot.
- **Reboot or restart?** There is no automatic answer; the docs
  call a reboot after every update safest. A kernel, Xen or
  low-level library such as `glibc` needs a reboot; anything else a
  toolstack restart. Read the updated packages from the `yum`
  output or `/var/log/yum.log`, and the announcement of the update
  on the XCP-ng blog (<https://xcp-ng.org/blog/tag/update/>),
  which says which one it needs.
- On a host with a LINSTOR (XOSTOR) SR, the docs update
  `linstor-satellite` and `linstor-controller` first, on their own;
  follow the updates page for the exact steps.
- **Upgrading to a new release** (e.g. 8.2 → 8.3) is done from the
  installation ISO at the console, which backs up the system and
  reinstalls it while keeping VMs and SRs; the `yum` path "is
  **not** supported to upgrade to XCP-ng 8.3"
  (<https://docs.xcp-ng.org/installation/upgrade/>). Refer the
  user to that page; it is not a job for Hostwarden over SSH.

## Management Plane: `xe`, Xen Orchestra, XO Lite

- `xe` runs locally on every host and acts on the whole pool
  (<https://docs.xcp-ng.org/management/manage-locally/cli/>).
  Command reference:
  <https://docs.xcp-ng.org/appendix/cli_reference/>; on the host,
  `xe help <command>` prints the syntax (`AGENTS.md` → Verify
  Before Running).
- Select what a listing prints with `params=`, and filter with
  `<param>=<value>`; `--minimal` prints only a comma-separated
  list of values. Filter for the problem rows instead of listing
  everything.
- `<uuid>` below is a host, VM or SR UUID. This host's comes from
  `INSTALLATION_UUID` in `/etc/xensource-inventory`; read it in the
  same `sh -s` bundle that uses it rather than in a call of its
  own:
  ```
  uuid=$(sed -n "s/^INSTALLATION_UUID='\(.*\)'/\1/p" /etc/xensource-inventory)
  ```
- Name the object an `xe` command acts on by `uuid=`. A selector
  that matches several objects acts on all of them once
  `--multiple` is given; never pass it unless the user asked for
  every match.
- **Xen Orchestra** (a VM or a separate host, not part of dom0)
  holds backup jobs, Rolling Pool Update, and the pool's history.
  It is managed as its own server when Hostwarden manages it at
  all. **XO Lite** is bundled with 8.3 and served by the host
  itself over HTTPS.
- **VMs, storage repositories and networks change through `xe` or
  Xen Orchestra, never by hand.** Never edit the XAPI database or
  `/etc/sysconfig/network-scripts/`, run `lvcreate`/`lvremove` on
  an SR's volume group, create files in an SR's mount point, or
  bring interfaces up and down with `ip`/`ifconfig`. XAPI keeps its
  own record of these objects, and a change it did not make leaves
  that record wrong.
- Hardware health comes through XAPI plugins, read-only; run the
  three in one call:
  ```
  xe host-call-plugin host-uuid=$uuid plugin=raid.py fn=check_raid_pool
  xe host-call-plugin host-uuid=$uuid plugin=smartctl.py fn=health
  xe host-call-plugin host-uuid=$uuid plugin=ipmitool.py fn=get_all_sensors
  ```
  (<https://github.com/xcp-ng/xcp-ng-xapi-plugins>).

## VMs

- List: `xe vm-list is-control-domain=false
  params=uuid,name-label,power-state,resident-on`. Dom0 itself
  appears as a VM with `is-control-domain=true`; never act on it.
- **Devices passed through:** `xe pci-list params=all` names each
  PCI device with every field this version has, dom0's access
  among them, and the `pci` key of each VM's `other-config` the
  ones it holds; both come from the Inventory call below. Read
  them with
  `.agents/skills/hostwarden-housekeeping/references/passthrough.md`;
  a dom0 that no longer reaches a device is that file's reserved
  device.
- **Stopping, destroying or uninstalling a VM** powers off or
  deletes a server: `rules/system-containers.md` → Changes. Its
  disks come from `xe vm-disk-list vm=<uuid>`, the newest backup
  from Xen Orchestra if the user can name it.
  `xe vm-shutdown uuid=<uuid>` is the clean shutdown;
  `force=true` is a hard power cut. `vm-uninstall` and
  `vdi-destroy` delete disks.
- With HA on, a VM shut down from inside the guest is restarted by
  default (`ha-reboot-vm-on-internal-shutdown`).
- **Inventory** (`rules/hypervisors.md`): record
  `Hypervisor: XCP-ng (xe)`. The full inventory is one call, the
  pool's in a pool (`rules/hypervisors.md` → Clusters and
  Pools):

  ```sh
  xe vm-list is-control-domain=false \
    params=uuid,name-label,power-state,resident-on,is-a-template,other-config,ha-restart-priority,os-version,networks
  xe vif-list params=vm-uuid,MAC
  xe host-list params=uuid,name-label,hostname
  xe pool-list params=ha-enabled
  xe pci-list params=all
  ```

  The host list names each VM's `resident-on` host. A halted VM
  shows `<not in database>` there: it resides on no host. A
  template with
  `default_template: true` in `other-config` ships with XCP-ng
  and is left out; `auto_poweron: true` there is autostart. A
  `ha-restart-priority` of `restart` or `best-effort` makes the
  entry `HA` instead of autostart only while the pool's
  `ha-enabled` is `true`: with HA off, the priority protects
  nothing, and the entry records autostart as for any VM. The
  light listing is `xe vm-list is-control-domain=false
  params=uuid,power-state,resident-on` with
  `xe host-list params=uuid,name-label` in the same call.
- **Guest tools:** `os-version` and `networks` in the inventory,
  which the guest tools fill; `<not in database>` means no
  agent.

## Storage Repositories

- List, sizes in bytes, and the connections that are down:
  ```
  xe sr-list params=uuid,name-label,type,shared,physical-size,physical-utilisation
  xe pbd-list currently-attached=false params=sr-uuid,host-uuid
  ```
  An unplugged PBD on a shared SR is a finding.
- `xe sr-scan uuid=<uuid>` rescans an SR and is safe.
- `sr-destroy` deletes the SR and every disk on it; `sr-forget`
  drops it from the pool; `sr-create` over a device
  (`device-config:device=…`) erases that device. All three only on
  the user's explicit request, after showing what is on the SR or
  device. Read disks with `lsblk` or the `lsblk.py` plugin
  (`fn=list_block_devices`), never by writing to them.
- `xe pool-eject` "reinstalls its XAPI state": the host reboots as
  a fresh standalone host, and "the contents of its local SRs are
  destroyed" (<https://docs.xcp-ng.org/management/hosts-pools/>).
  Only on explicit request, after saying so.

## Networking

- Networks, PIFs, bonds and VLANs: `xe network-list`,
  `xe pif-list params=uuid,device,IP,management,currently-attached`.
  Change them with `xe pif-reconfigure-ip` or
  `xe host-management-reconfigure`, or in Xen Orchestra.
- Changing the management interface or its address cuts SSH and
  the pool's connection to the host. The docs: do it "from a
  console that won't be cut". There is no revert Hostwarden can
  arm for it (`rules/ssh-safety-net.md`): the user makes the
  change with the console its `Management:` line records
  (`rules/management-controller.md` → The rescue path) ready.

## High Availability

Source: <https://docs.xcp-ng.org/management/ha/>.

- State: `xe pool-list
  params=ha-enabled,ha-host-failures-to-tolerate,ha-plan-exists-for`.
  `ha-plan-exists-for` below `ha-host-failures-to-tolerate` means
  the pool cannot survive the failures it promises: a finding.
- A host with HA on that loses its heartbeat fences itself
  (reboots). **Never restart the toolstack while HA is on**:
  "Attempting this will cause immediate host fencing". Disable HA
  first (`xe pool-ha-disable`) — a change, so ask — and re-enable
  it afterwards with the SR it had
  (`xe pool-ha-enable heartbeat-sr-uuids=<sr-uuid>`).
- `xe host-declare-dead`, `xe host-forget` and
  `xe pool-emergency-transition-to-master` are recovery tools for
  a dead host or master. The reference warns that declaring a host
  dead "is dangerous and can cause data loss if the host is not
  actually dead". Only on explicit request.

## Replace: Firewall

- **Expected:** the `iptables` service with its rules in
  `/etc/sysconfig/iptables`, as XCP-ng ships it. Not `firewalld`;
  do not install or enable it.
- Read-only: `iptables -S; ip6tables -S`; `iptables -L -n -v` only
  when the packet counters matter.
- XAPI listens on 443 (HTTPS), and on 80 unless the pool sets
  `https-only=true` (8.3), which closes it on the management
  interface (<https://docs.xcp-ng.org/releases/release-8-3/>).
  Closing a port XAPI expects can break pool traffic.
- **Opening or closing a port:** only when the user asks, as a
  firewall change (`AGENTS.md` → Critical Safety Rules, including
  the sshd ports) and a config edit (`rules/backups.md`). The docs
  add the rule to `/etc/sysconfig/iptables` and restart `iptables`
  (<https://docs.xcp-ng.org/management/monitoring/>); XCP-ng staff
  name `/etc/xapi.d/plugins/firewall-port {open|close} <port>
  <protocol>` and advise against changing the dom0 firewall at all
  (<https://xcp-ng.org/forum/topic/9823/xcp-ng-firewall>).
- Over SSH the change goes through `rules/ssh-safety-net.md`.
  Check: `iptables-restore --test < /etc/sysconfig/iptables`
  (<https://man7.org/linux/man-pages/man8/iptables-restore.8.html>);
  apply: `systemctl restart iptables`; revert: the backed-up file
  restored, then `systemctl restart iptables` where the service ran
  before, or `systemctl stop iptables` where it did not. Loaded
  rules against the file: `iptables-save` and
  `/etc/sysconfig/iptables`. An IPv6 rule goes
  the same way with `ip6tables-restore --test`,
  `/etc/sysconfig/ip6tables` and the `ip6tables` service.

## SSH

- On 8.3 `sshd_config` belongs to Vates and local settings go into
  `sshd_config.d/`
  (<https://docs.xcp-ng.org/releases/release-8-3/>); the sshd
  taboo in `AGENTS.md` covers both.
- Root's password is shared by every host in the pool; changing it
  is a credential rotation. `xe user-password-change` takes the new
  password as an argument, which `rules/secrets.md` forbids: the
  user changes it in `xsconsole` or Xen Orchestra.
- SSH can be switched off in `xsconsole` (Remote Service
  Configuration). A pool with SSH off is managed through Xen
  Orchestra; that is a policy, not a fault.

## Replace: SELinux

- Dom0's SELinux state is XCP-ng's. Report `getenforce` when an
  audit asks for it; never change it.

## Remove: Service Manager > Logs: `journalctl -u <service>`

## Add: Service Manager

- `xapi` is the toolstack. The docs restart it with
  `xe-toolstack-restart`, not `systemctl`; see Updates for when,
  and High Availability for when never. Ask first, even when
  `memory/service-policy.md` allows restarts without asking.

## Remove: Directory Conventions

## Replace: Notes

- Dom0 is CentOS 7, which is end-of-life upstream
  (<https://docs.xcp-ng.org/management/additional-packages/>);
  XCP-ng backports security fixes into its own packages, so a
  CentOS advisory's fixed version may not match. Judge a package
  by XCP-ng's update announcements.

## Remove: Common Pitfalls

## Logs

- XCP-ng "does not use journald for logs"; everything is in
  `/var/log`, written by `rsyslog`
  (<https://docs.xcp-ng.org/troubleshooting/log-files/>):
  - `/var/log/xensource.log` — XAPI and `xenopsd`
  - `/var/log/SMlog` — the storage manager
  - `/var/log/daemon.log`, `/var/log/kern.log`, `/var/log/audit.log`
    (XAPI's RBAC audit), `/var/log/yum.log`
- `logger -t hostwarden` uses facility `user`, which
  `/etc/rsyslog.d/xenserver.conf` routes to `/var/log/user.log`
  (<https://github.com/xcp-ng/xcp-ng-release/blob/8.3/src/common/etc/rsyslog.d/xenserver.conf>).
  Keep `logger`'s default facility. The activity check reads it
  back, oldest file first so the last matches are the newest:
  ```
  zcat -f $(ls -tr /var/log/user.log*) | grep -E "hostwarden|heinzel" | tail -20
  zcat -f $(ls -tr /var/log/user.log* | head -1) | head -1
  date
  ```
- On some Dell servers the installer creates no separate `/var/log`
  partition, and log rotation then deletes old logs the same day
  (<https://docs.xcp-ng.org/troubleshooting/installation-upgrade/>).
  Missing old logs there are not evidence of tampering
  (`rules/verify-before-reporting.md`).
- `xen-bugtool --yestoall` collects every log and the config for
  a support case. It writes a large archive into dom0; only on
  request.

## Backups

Source: <https://docs.xcp-ng.org/management/backup/>.

- VM backups are Xen Orchestra backup jobs to a remote repository
  (NFS, SMB, S3); dom0 holds none of them.
- Pool metadata: Xen Orchestra's metadata backup, or by hand
  `xe pool-dump-database file-name=<file>`. Write that file outside
  the SRs, and treat it as a secret (`rules/secrets.md`): it holds
  the pool configuration.

## Housekeeping and Audits

- **Pending updates:** `yum check-update -q`; they are the finding.
  It exits 100 when updates are pending and 0 when none are; only
  another code is a failed check.
  Xen Orchestra reads the same list through the `updater.py`
  plugin (`plugin=updater.py fn=check_update`,
  <https://github.com/xcp-ng/xcp-ng-xapi-plugins>).
- **Pool, hosts and HA,** once per pool
  (`rules/hypervisors.md` → Clusters and Pools → Once per
  cluster):
  ```
  xe pool-list params=name-label,master,ha-enabled,ha-host-failures-to-tolerate,ha-plan-exists-for
  xe host-list params=uuid,name-label,enabled,host-metrics-live,memory-total,memory-free
  xe task-list params=uuid,name-label,status,progress
  ```
  A host with `enabled=false` left behind by maintenance, or
  `host-metrics-live=false`, is a finding; HA as in High
  Availability. A member on a newer version than its master is a
  critical one: compare
  `xe host-param-get uuid=<uuid> param-name=software-version
  param-key=product_version` across the hosts. Record the master
  as the cluster's `Master:` line and the HA state as its `HA:`
  line.
- **SR usage:** from `xe sr-list` and `xe pbd-list` (Storage
  Repositories), with the filesystem thresholds of the housekeeping
  baseline applied to `physical-utilisation` over `physical-size`.
- **Dom0 disk:** the baseline's `df` covers it; a full `/var/log`
  also stops logging.
- **Backups:** the backup-presence check records the Xen
  Orchestra jobs and the metadata backup as the host's `Backup:`
  line; dom0 cannot show them.
- **Hardware:** the RAID, SMART and IPMI plugins (Management
  Plane).
- **Security audit:** report `https-only` and whether SSH is on.
- **Fleet audit:** compare XCP-ng hosts only with each other. Show
  `iptables` in the firewall rows; a missing automatic-update tool
  is not drift.
