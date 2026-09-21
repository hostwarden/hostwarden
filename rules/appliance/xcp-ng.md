# XCP-ng

Base: `rules/os/rhel.md`

An XCP-ng host is a Xen hypervisor, and the shell you reach over
SSH is its control domain, dom0: a CentOS 7 userland with security
fixes backported by the XCP-ng team, a patched 4.19 kernel, and the
XAPI toolstack (<https://docs.xcp-ng.org/releases/release-8-3/>).
This file applies on top of the base (`rules/os-detection.md` →
Appliances). Dom0 is not a general-purpose server: every VM on the
host, and in a pool every other host, depends on it.

XCP-ng itself says "day to day, nobody should log into a host
directly"; the management plane is XAPI, reached through Xen
Orchestra, XO Lite or the `xe` CLI
(<https://docs.xcp-ng.org/management/users-permissions/>).
Hostwarden on dom0 reads state, runs `xe`, and follows XCP-ng's own
update procedure. It changes nothing by hand that XAPI owns.

Source for everything below unless noted: the XCP-ng documentation,
<https://docs.xcp-ng.org/>.

## Add: Version Detection

- `/etc/os-release` has `ID="xcp-ng"` and
  `ID_LIKE="centos rhel fedora"`, which maps it to the RHEL family;
  `VERSION_ID` is the XCP-ng version
  (<https://github.com/xcp-ng/xcp-ng-release/blob/8.3/src/xenserver/etc/os-release>).
  `/etc/redhat-release` names XCP-ng, not CentOS.
- `/etc/xensource-inventory` exists on every host. Its
  `PRODUCT_VERSION` repeats the version; `INSTALLATION_UUID` is the
  host's UUID for `xe`. Read single keys with `grep`; the file names
  the boot disk and management interface as well.
- Pool role:
  ```
  xe pool-list params=name-label,master
  xe host-list params=uuid,name-label,enabled
  ```
  The host whose UUID is the pool's `master` is the pool master
  (the docs also call it the coordinator). A pool of one host is
  standalone.
- Record in server memory:
  `Appliance: XCP-ng <version>`, the pool name, and `master` or
  `member`, or `standalone`.
- Take support dates from the releases page
  (<https://docs.xcp-ng.org/releases/>), never from memory. A host
  on a release past its end of support is a finding: the page says
  hosts below the current LTS no longer get bug or security fixes.
- `xe` on a host whose `ID` is not `xcp-ng` (Citrix XenServer uses
  the same toolstack) is not covered by this file. Tell the user
  and proceed as the base alone describes, reading more than you
  change.

## Replace: Package Manager

- **`yum`**, from the XCP-ng repositories only.
- **Install nothing in dom0 unless the user asks for it, and then
  only a package from XCP-ng's own repositories.** The supported
  list for 8.3 is
  <http://reports.xcp-ng.org/8.3/extra_installable.txt>; show the
  user that the package is on it before installing. "Best effort
  support is provided for additional packages provided by the
  XCP-ng project. No support is provided for other additional
  packages, even if installed from our repositories"
  (<https://docs.xcp-ng.org/management/additional-packages/>).
- **Never enable another repository**, not even for one command
  with `--enablerepo`. The CentOS and EPEL repositories ship
  pre-installed but disabled. The docs: "The update process for
  XCP-ng assumes that only XCP-ng repositories are enabled. If you
  enable more repositories, updates may get pulled from there and
  overwrite XCP-ng packages and thus break your system." A package
  that is not in XCP-ng's repositories goes into a VM, never into
  dom0. If a third-party repository is already enabled under
  `/etc/yum.repos.d/`, report it; turning it off (`enabled=0`) is
  a config edit (`rules/backups.md`) and the user's decision.
- Dry-run: `yum --assumeno update` shows what would change without
  installing; `yum check-update` lists pending updates. Installing
  anything follows Updates below.
- Never `pip install`, `curl | sh`, or a binary dropped into
  `/usr/local` on dom0. Monitoring agents are the documented
  exception, and only the ones the repositories carry: `net-snmp`
  and `netdata`
  (<https://docs.xcp-ng.org/management/monitoring/>).

## Replace: Automatic Security Updates

- **Not expected, and not a finding.** Dom0 updates follow the
  pool procedure below, pool master first, with reboots or a
  toolstack restart in between; nothing may install them on its
  own. Do not install `yum-cron` or `dnf-automatic`.
- Report pending updates instead. The `updater.py` XAPI plugin
  returns them as a list:
  ```
  xe host-call-plugin host-uuid=<uuid> plugin=updater.py fn=check_update
  ```
  (<https://github.com/xcp-ng/xcp-ng-xapi-plugins>). `yum
  check-update` gives the same from the host itself.
- Update announcements are on the XCP-ng blog
  (<https://xcp-ng.org/blog/tag/update/>); each says whether a
  reboot or only a toolstack restart is needed.

## Updates

Source: <https://docs.xcp-ng.org/management/updates/>.

- **Xen Orchestra's Rolling Pool Update is the advised way** to
  update a pool: it migrates VMs away, updates and reboots one host
  after another, and disables HA, the load balancer and backup jobs
  for the duration. It needs every VM disk on shared storage. When
  the pool has Xen Orchestra, tell the user that is the route and
  do the update from dom0 only when they ask for it.
- **Always the pool master first.** "Other pool members must never
  run a higher version than the master"; a member updated first
  loses its connection to the pool.
- Before updating, as the docs list them: disable HA (see High
  Availability), check that no XAPI task runs (`xe task-list`),
  eject the guest-tools ISO from running VMs, and do not run the
  update from an interactive console shell. Disconnect passed-
  through devices first. Disabling HA is a change: ask.
- Per host, starting with the master:
  1. Dry-run and show the user the list (`yum --assumeno update`).
  2. `xe host-disable uuid=<uuid>`: no new VMs start here.
  3. Reboot needed: `xe host-evacuate uuid=<uuid>` live-migrates
     every running VM to another host. Confirm with
     `xe vm-list resident-on=<uuid> is-control-domain=false
     params=name-label,power-state` that nothing is left running.
  4. `yum update -y`.
  5. Reboot, or for a control-plane-only update
     `xe-toolstack-restart`. **Never restart the toolstack while
     HA is on**: "Attempting this will cause immediate host
     fencing" (<https://docs.xcp-ng.org/management/ha/>).
  6. `xe host-enable uuid=<uuid>` once the host is back, then the
     next host.
- **Rebooting and evacuating are the user's decision**, every
  time: ask, and say how many VMs will move or stop. A host that
  cannot be evacuated (local storage, no room elsewhere) stops its
  VMs on reboot.
- **Reboot or restart?** There is no automatic answer. The docs:
  rebooting after every update is safest. A kernel, Xen or
  low-level library such as `glibc` needs a reboot; anything else a
  toolstack restart. Read the updated packages from the `yum`
  output or `/var/log/yum.log`, and the blog post for the update.
- On a host with a LINSTOR (XOSTOR) SR, the docs update
  `linstor-satellite` and `linstor-controller` first, on their own;
  follow the updates page for the exact steps.
- Do not update a single member of a pool on its own. The docs
  "do NOT recommend to install updates to individual hosts" unless
  the host is alone in its pool.
- **Upgrading to a new release** (e.g. 8.2 → 8.3) is done from the
  installation ISO at the console, which backs up the system and
  reinstalls it while keeping VMs and SRs. The `yum` upgrade path
  "is **not** supported to upgrade to XCP-ng 8.3"
  (<https://docs.xcp-ng.org/installation/upgrade/>). Refer the
  user to that page; it is not a job for Hostwarden over SSH.

## Management Plane: `xe`, Xen Orchestra, XO Lite

- `xe` runs locally on every host and acts on the whole pool
  (<https://docs.xcp-ng.org/management/manage-locally/cli/>).
  Command reference:
  <https://docs.xcp-ng.org/appendix/cli_reference/>. Check a
  command there before running it (`AGENTS.md` → Verify Before
  Running); `xe help <command>` prints its syntax on the host.
- Select what a listing prints with `params=`, and filter with
  `<param>=<value>`; `--minimal` prints only a comma-separated
  list of values.
- **Xen Orchestra** (a VM or a separate host, not part of dom0)
  holds backup jobs, Rolling Pool Update, and the pool's history.
  It is managed as its own server when Hostwarden manages it at
  all. **XO Lite** is bundled with 8.3 and served by the host
  itself over HTTPS.
- **VMs, storage repositories and networks change through `xe` or
  Xen Orchestra, never by hand.** Never edit the XAPI database,
  run `lvcreate`/`lvremove` on an SR's volume group, create files
  in an SR's mount point, or bring interfaces up and down with
  `ip`/`ifconfig`. XAPI keeps its own record of these objects, and
  a change it did not make leaves that record wrong.
- Name the object an `xe` command acts on by `uuid=`. A selector
  that matches several objects acts on all of them once
  `--multiple` is given; never pass it unless the user asked for
  every match.

## VMs

- List: `xe vm-list is-control-domain=false
  params=uuid,name-label,power-state,resident-on`. Dom0 itself
  appears as a VM with `is-control-domain=true`; never act on it.
- **Stopping, destroying or uninstalling a VM** powers off or
  deletes a server: only on the user's explicit request. First
  show, from the live host and in one call, what it hits: UUID,
  name, power state, disks (`xe vm-disk-list vm=<uuid>`) and the
  newest backup from Xen Orchestra if the user can name it.
  `xe vm-shutdown uuid=<uuid>` is the clean shutdown;
  `force=true` is a hard power cut. `vm-uninstall` and
  `vdi-destroy` delete disks.
- With HA on, a VM shut down from inside the guest is restarted by
  default (`ha-reboot-vm-on-internal-shutdown`).

## Storage Repositories

- List, sizes in bytes, and the SRs' connections to the hosts:
  ```
  xe sr-list params=uuid,name-label,type,shared,physical-size,physical-utilisation
  xe pbd-list params=sr-uuid,host-uuid,currently-attached
  ```
  An unplugged PBD on a shared SR is a finding.
- `xe sr-scan uuid=<uuid>` rescans an SR and is safe.
  `sr-destroy` deletes the SR and every disk on it; `sr-forget`
  drops it from the pool. Both need the user's explicit request,
  and `sr-destroy` counts with the disk taboos.
- **The disk taboos in `AGENTS.md` hold on dom0 as anywhere.**
  Creating a local SR (`xe sr-create … device-config:device=…`)
  writes to a whole disk device: treat it as the taboo it is. Read
  disks with `lsblk` or the `lsblk.py` plugin
  (`xe host-call-plugin host-uuid=<uuid> plugin=lsblk.py
  fn=list_block_devices`), never by writing to them.
- `xe pool-eject` "reinstalls its XAPI state": the host reboots as
  a fresh standalone host, and "the contents of its local SRs are
  destroyed" (<https://docs.xcp-ng.org/management/hosts-pools/>).
  Only on explicit request, after saying so.

## Networking

- Networks, PIFs, bonds and VLANs are XAPI objects: `xe
  network-list`, `xe pif-list
  params=uuid,device,IP,management,currently-attached`.
- Change them only through `xe` (`pif-reconfigure-ip`,
  `host-management-reconfigure`) or Xen Orchestra, never in
  `/etc/sysconfig/network-scripts/`: XAPI owns the network
  configuration.
- Changing the management interface or its address cuts SSH and
  the pool's connection to the host. The docs: do it "from a
  console that won't be cut". Ask the user first, and make sure
  they have console access (IPMI, physical) before running it.

## High Availability

Source: <https://docs.xcp-ng.org/management/ha/>.

- State: `xe pool-list
  params=ha-enabled,ha-host-failures-to-tolerate,ha-plan-exists-for`.
  `ha-plan-exists-for` below `ha-host-failures-to-tolerate` means
  the pool cannot survive the failures it promises: a finding.
- A host with HA on that loses its heartbeat fences itself
  (reboots). Never restart the toolstack with HA on; disable HA
  (`xe pool-ha-disable`) first, which is itself a change to ask
  about, and re-enable it afterwards
  (`xe pool-ha-enable heartbeat-sr-uuids=<sr-uuid>`) with the SR
  it had.
- `xe host-declare-dead`, `xe host-forget` and
  `xe pool-emergency-transition-to-master` are recovery tools for
  a dead host or master. The reference warns that declaring a host
  dead "is dangerous and can cause data loss if the host is not
  actually dead". Only on explicit request.

## Replace: Firewall

- **Expected:** the `iptables` service with its rules in
  `/etc/sysconfig/iptables`, as XCP-ng ships it. Not `firewalld`;
  do not install or enable it.
- Read-only: `iptables -S`, `iptables -L -n -v`, and the same with
  `ip6tables`.
- XAPI listens on 443 (HTTPS), and on 80 unless the pool sets
  `https-only=true` (8.3), which closes it on the management
  interface (<https://docs.xcp-ng.org/releases/release-8-3/>).
  Closing a port XAPI expects can break pool traffic.
- **Opening a port:** only when the user asks. The docs add the
  rule to `/etc/sysconfig/iptables` and restart `iptables`
  (<https://docs.xcp-ng.org/management/monitoring/>), which is a
  config edit (`rules/backups.md`) and a firewall change
  (`AGENTS.md`). XCP-ng staff name
  `/etc/xapi.d/plugins/firewall-port {open|close} <port> <protocol>`
  as the tool, and warn against changing the dom0 firewall at all
  (<https://xcp-ng.org/forum/topic/9823/xcp-ng-firewall>).
- **Before any change:** read the ports sshd listens on
  (`AGENTS.md` → Critical Safety Rules), keep a second SSH session
  open, and ask. A mistake in the file takes effect on the restart,
  SSH included.

## SSH

- The sshd taboo in `AGENTS.md` holds unchanged: never modify
  `sshd_config` or `sshd_config.d/`. On 8.3 `sshd_config` belongs
  to Vates, and local settings go into `/etc/ssh/sshd_config.d/`
  (<https://docs.xcp-ng.org/releases/release-8-3/>) — which the
  user edits, not Hostwarden.
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

## Add: Service Manager

- `xapi` is the toolstack. The docs restart it with
  `xe-toolstack-restart`, not `systemctl`; see Updates for when,
  and High Availability for when never.
- `rsyslog` writes every log (see Logs); XCP-ng's rotation hangs
  off it.

## Remove: Directory Conventions

## Replace: Notes

- Dom0 is CentOS 7, which is end-of-life upstream
  (<https://docs.xcp-ng.org/management/additional-packages/>);
  XCP-ng backports security fixes into its own packages, so a
  CentOS advisory's fixed version may not match. Judge a package
  by XCP-ng's update announcements.
- Hardware health comes through XAPI plugins, read-only:
  `raid.py fn=check_raid_pool`, `smartctl.py fn=health`,
  `ipmitool.py fn=get_all_sensors`, each with
  `xe host-call-plugin host-uuid=<uuid> plugin=<plugin> fn=<fn>`
  (<https://github.com/xcp-ng/xcp-ng-xapi-plugins>).

## Replace: Common Pitfalls

- Pool members updated before the master drop out of the pool.
- `xe-toolstack-restart` with HA on fences the host.
- Enabling a CentOS or EPEL repository, even once, can replace
  XCP-ng packages with higher-versioned ones.
- On some Dell servers the installer creates no separate `/var/log`
  partition, and log rotation then deletes old logs the same day
  (<https://docs.xcp-ng.org/troubleshooting/installation-upgrade/>).
  Missing old logs there are not evidence of tampering
  (`rules/verify-before-reporting.md`).

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
  back, rotated files included:
  ```
  zgrep -hE "hostwarden|heinzel" /var/log/user.log*
  ```
  The glob does not sort by date: order the matches by their
  timestamps before reading the newest.
- `xen-bugtool --yestoall` collects every log and the config for
  a support case. It writes a large archive into dom0; only on
  request.

## Backups

Source: <https://docs.xcp-ng.org/management/backup/>.

- VM backups are Xen Orchestra backup jobs to a remote repository
  (NFS, SMB, S3). Dom0 holds none of them; ask the user what the
  jobs are when an audit needs them.
- Pool metadata: Xen Orchestra's metadata backup, or by hand
  `xe pool-dump-database file-name=<file>`. Write that file outside
  the SRs, and it holds the pool configuration: treat it as a
  secret (`rules/secrets.md`).

## Housekeeping and Audits

- **Pending updates:** `yum check-update` or the `updater.py`
  plugin (see Automatic Security Updates); they are the finding.
  A member on a newer version than its master
  (`xe host-list params=name-label,software-version`) is a
  critical one.
- **Pool and hosts:** every host `enabled=true` and
  `host-metrics-live=true`
  (`xe host-list params=name-label,enabled,host-metrics-live`);
  a disabled host left behind by maintenance is a finding.
  `xe task-list` for stuck tasks.
- **SR usage:** from `xe sr-list` (see Storage Repositories);
  report use above 85 % of `physical-size`, as for any
  filesystem, and any PBD not attached.
- **HA state:** see High Availability.
- **Dom0 disk and memory:** `df -h /` and `df -h /var/log` in dom0
  (a full `/var/log` stops logging); `free -m` for dom0's own
  memory. Host memory for VMs:
  `xe host-list params=name-label,memory-total,memory-free`.
- **Backups:** no Xen Orchestra backup job and no metadata backup
  known for the pool is a finding; say which the user has to
  confirm, since dom0 cannot show them.
- **Hardware:** the RAID, SMART and IPMI plugins (see Notes).
- **Security audit:** the firewall rows read `iptables`; a missing
  `firewalld` or `dnf-automatic` is not a finding. Report
  `https-only` and whether SSH is on.
- **Fleet audit:** compare XCP-ng hosts only with each other; a
  missing automatic-update tool is not drift.
