# First Detection

What OS detection settles once and records in server
memory: the family, the appliance, the platform,
virtualization, the hypervisor and the role. A first
connection runs all of it, in order. A known host
reads only the section that settles a line its memory
lacks, as `rules/os-detection.md` → On subsequent
connections says. That file is read on every
connection, first: the first call, Windows and Layers
are there.

## On first connection

What counts as a first connection:
`rules/first-connection.md` step 6. A host adopted
from Heinzel is one; what Heinzel remembered never
stands in for this probe.

0. **Check access control and DNS alias.** For remote
   servers: check blacklist, then read-only list
   (see `rules/access-control.md`), then DNS aliases
   (see `rules/dns-aliases.md`). If the hostname is
   an alias for a known server, skip OS detection.

1. **Probe everything in one call** — OS, login shell,
   architecture, version, hardware and appliance
   markers:
   ```
   ssh … <host> 'uname -s; ps -o comm= -p $$; uname -m;' \
     'echo @release; freebsd-version;' \
     'grep -E "^(ID|ID_LIKE|VARIANT_ID|VERSION_ID|PRETTY_NAME|OS_VERSION|OS_IS_BETA)=" /etc/os-release;' \
     'sw_vers -productVersion; echo @hardware; df -h /;' \
     'nproc; grep -c "^processor" /proc/cpuinfo; free -h;' \
     'grep -m1 "model name" /proc/cpuinfo;' \
     'sysctl hw.model hw.ncpu hw.physmem;' \
     'sysctl hw.memsize; echo @appliance;' \
     'which pveversion ha opnsense-version pfSense-upgrade' \
     'midclt ubnt-device-info; ls -d /homeassistant; pveversion;' \
     'opnsense-version; cat /etc/version /etc/unraid-version;' \
     'midclt call system.version; dpkg -l openmediavault;' \
     'cat /etc.defaults/VERSION; ls -d /ugreen;' \
     'ls -d /etc/config/qpkg.conf;' \
     'ubnt-device-info firmware; ubnt-device-info model;' \
     'echo @virt; uname -m; systemd-detect-virt; openrc --sys;' \
     'ls -d /.dockerenv /run/.containerenv;' \
     'grep -c -w hypervisor /proc/cpuinfo;' \
     'cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name;' \
     'sysctl kern.vm_guest security.jail.jailed;' \
     'sysctl kern.hv_vmm_present hw.model;' \
     'echo @hypervisor; which virsh incus lxd lxc-ls vm VBoxManage' \
     'bastille iocage appjail pot cbsd;' \
     'ls -d /run/libvirt /var/snap/lxd/common/lxd /var/lib/lxc /dev/vmm;' \
     'ls /etc/jail.conf /etc/jail.conf.d; sysrc jail_enable jail_conf;' \
     'echo @storage; ls -d /dev/zfs; grep -c -w btrfs /proc/mounts;' \
     'echo @platform; cat /proc/version; printenv WSL_DISTRO_NAME'
   ```
   It goes out, and its first line is read, as
   `rules/os-detection.md` → The first call says.

   **The second line is the shell** (compare its
   basename; macOS may print `-zsh` or a path). Record
   it per SSH user in server memory (`Shell: csh
   (root)`); every later call goes through `sh -s`
   whatever it is (`rules/os-detection.md` → The
   first call). An error in place of the second line
   (busybox `ps` rejects `-p`) means reading the
   shell from the SSH user's line in `/etc/passwd` in
   the next call; record `Shell: unknown` only if that
   fails too. A
   shell that rejects the whole line (fish rejects
   `$$`) records `Shell: unknown`, and then the probe
   goes again through `sh -s`.

2. **Map the OS to a family** from the lines after
   `@release`, and read `rules/os/<family>.md`:
   - **Linux:** the os-release `ID` and `ID_LIKE`
     fields (e.g. `ubuntu` → `debian`; `centos`,
     `rocky`, `alma`, `fedora` → `rhel`; `opensuse*`
     variants → `suse`; `alpine` → `alpine`); the
     version from `VERSION_ID` and `PRETTY_NAME`. A
     host that matches a marker with base `none` under
     Appliances below has no family, whatever its
     `ID`. Neither has an image-based OS that ships no
     package manager — `VARIANT_ID=coreos` beside
     `ID=fedora`, or `ID=flatcar` — although its `ID`
     points at one. If no family file matches (e.g.
     Arch, Gentoo, those two), tell the user, proceed
     cautiously with generic commands, and apply extra
     verify-before-running care.
   - **FreeBSD:** `freebsd`, version from the
     `freebsd-version` line.
   - **macOS:** `macos`, version from the `sw_vers`
     line.
   - **Windows:** `windows`, from the Windows probe
     (`rules/os-detection.md` → Windows); the lines
     after `@release` do not apply.

   Hardware comes from the lines after `@hardware`:
   the CPU count, the CPU model and `free` on Linux,
   `sysctl` elsewhere. The CPU count is `nproc`'s, the
   first number, which honours a container's CPU limit;
   the `processor` count after it stands in only where
   `nproc` is missing (OpenWrt). Record
   `Arch: <architecture>, <maker>` — `Arch: x86_64,
   AMD`, `Arch: aarch64, Apple M2`. The architecture
   is the `uname -m` line under `@virt`, which the
   marker places whatever the shell printed before;
   the maker is the one the CPU model names. Where no
   line names a maker (many ARM boards), `Arch:` holds
   the architecture alone. An image, an installer or a
   binary download picks its build by this line.
   Whether it has ZFS pools or btrfs comes from the
   lines after `@storage`; see
   `rules/storage-inventory.md` → Detection. Whether
   the hardware is the host's
   own comes from the lines after `@virt`; see
   Virtualization below. Whether it runs guests of
   its own comes from the lines after `@hypervisor`;
   see Hypervisors below.

3. **Check for an appliance** from the lines after
   `@appliance`, and for a marker of the form `ID=…`
   from the os-release lines after `@release`, with or
   without quotes around the value. See Appliances
   below. Where the probe already prints
   what the appliance file's Version Detection reads,
   the version comes from the probe; otherwise run
   that command.

4. **Check for a platform** from the lines after
   `@platform`. See Platforms below.

5. **Settle the role**, server or workstation. See
   Roles below.

6. Create a server memory file.

## Appliances

An appliance is a product whose vendor runs the OS
underneath: its own updater, its own configuration
model, its own firewall. The family file's rules for
changing the system are then partly wrong, and a file
in `rules/appliance/` says which. A service that merely
runs on a host — Docker, a database, a web server — is
not one.

The probe in step 1 reports the markers. `which`
prints a path for a command that exists; what it
prints for a missing one depends on the shell. Where
one marker has two rows, the family from step 2 picks
the row.

| Base    | Marker               | Appliance file                      |
| ------- | -------------------- | ----------------------------------- |
| Debian  | `pveversion`         | `rules/appliance/proxmox-ve.md`     |
| Debian  | `ii  openmediavault` | `rules/appliance/openmediavault.md` |
| Debian  | `midclt`             | `rules/appliance/truenas.md`        |
| FreeBSD | `opnsense-version`   | `rules/appliance/opnsense.md`       |
| FreeBSD | `pfSense-upgrade`    | `rules/appliance/pfsense.md`        |
| FreeBSD | `midclt`             | `rules/appliance/truenas-core.md`   |
| RHEL    | `ID=xcp-ng`          | `rules/appliance/xcp-ng.md`         |
| none    | `ID=haos`, `ha`      | `rules/appliance/haos.md`           |
| none    | `os_name="DSM"`      | `rules/appliance/synology-dsm.md`   |
| none    | `/ugreen` + `OS_…`   | `rules/appliance/ugos.md`           |
| none    | `ubnt-device-info`   | `rules/appliance/unifi-os.md`       |
| none    | `version="…"`        | `rules/appliance/unraid.md`         |
| none    | `ID="openwrt"`       | `rules/appliance/openwrt.md`        |
| none    | `ID=zimaos`          | `rules/appliance/zimaos.md`         |
| none    | `…/qpkg.conf`        | `rules/appliance/qnap.md`           |

`ii  openmediavault` is the line `dpkg -l` prints for
the installed package, with its version. `rc` (removed,
config files left) and the "no packages found" error
name the package too and are no match.

`ha` counts only where `/homeassistant` exists too.
`ID=haos` means the probe reached the HAOS host
itself; its file says to stop there.
`version="…"` is the content of `/etc/unraid-version`
on a line of its own; an error that names the file is
no match.
`os_name="DSM"` is a line of `/etc.defaults/VERSION`
from DSM 7.2 on; an error that names the file is no
match. The file with another `os_name`, or none, as on
DSM 7.1 and earlier: show the user its lines and ask
what the host is.
`/ugreen` is what `ls -d` prints where the directory
exists: UGOS Pro keeps its own service files there.
`OS_…` stands for the `OS_VERSION=` line UGOS Pro
adds to `/etc/os-release`, printed under `@release`.
Only both together are a match. One without the other
is none: show the user what the probe printed and ask
what the host is.
`…/qpkg.conf` is `/etc/config/qpkg.conf`, the package
registry of QNAP's QTS and QuTS hero, which `ls -d`
prints on a line of its own without needing read
access to it. An error that names the file is no
match; OpenWrt has an `/etc/config` but no such file.

On a match, read the family file its `Base:` line
names, then the appliance file on top of it
(`rules/os-detection.md` → Layers). Record
`Appliance: …` in server memory, in the form the
appliance file gives.

The line under `Base:` says whose hardware the
appliance runs on. `Hardware: any` is an OS that
installs on ordinary machines and in VMs.
`Hardware: vendor` is sold only with the vendor's
device: the OS cannot be replaced (the
`hostwarden-os-install` skill refuses), hardware
health comes only through what the appliance file
names, and a firmware update also brings the boot
loader and the device's own firmware. `any` describes
the OS, not the machine: OpenWrt on a consumer router,
HAOS on a Home Assistant Green or pfSense on a Netgate
ARM box still run on the vendor's device. Where that
decides something, the `hostwarden-os-install` skill
reads the device.

## Platforms

A platform is what an ordinary OS runs inside when
something outside it owns part of the machine — the
kernel, the firewall, the network, the power switch.
The distribution's own package manager and services
still work as its family file says; what the outside
owns does not. What the outside owns is read, never
changed from inside: the platform file gives the
command for the user to run there. An ordinary
virtual machine is not a platform: the guest owns its
kernel, its firewall and its reboot.

| Marker                                    | Platform file           |
| ----------------------------------------- | ----------------------- |
| `microsoft` in `/proc/version`, any case  | `rules/platform/wsl.md` |

The environment variable under `@platform` is a label
for the memory directory (`rules/server-memory.md`),
never a marker: whoever starts the shell sets it.

The platform file applies on top of the family and
appliance files (`rules/os-detection.md` → Layers).
Record `Platform: …` in server memory, in the form the
platform file gives.

## Virtualization

Whether the host runs on its own hardware, in a
virtual machine or in a container. It is recorded so
that memory shows where each machine runs and so that
what only physical hardware has is looked for where
it exists. It changes no rule by itself; a rule that
depends on it says so.

Read the lines after `@virt` in this order; the first
case that matches decides:

1. **Container.** `systemd-detect-virt` prints a
   container type (`lxc`, `lxc-libvirt`,
   `systemd-nspawn`, `docker`, `podman`, `openvz`,
   …), `openrc --sys` prints `LXC`, `DOCKER` or
   `PODMAN`, `ls` lists `/.dockerenv` or
   `/run/.containerenv`, or `security.jail.jailed` is
   `1` (a FreeBSD jail, recorded as `jail`). Checked
   first because in a
   container the DMI lines and the `hypervisor` count
   describe the machine underneath.
2. **Virtual machine.** `systemd-detect-virt` prints a
   VM type (`kvm`, `qemu`, `vmware`, `microsoft`,
   `oracle`, `xen`, `amazon`, `google`, `bhyve`,
   `parallels`, `apple`, …); `kern.vm_guest` is
   anything but `none` (FreeBSD); `kern.hv_vmm_present`
   is `1` or `hw.model` starts with `VirtualMac`
   (macOS). Where `systemd-detect-virt` is missing, a
   `hypervisor` count above 0 is a VM too, and so are
   DMI lines from the type table below.
3. **Bare metal.** Only on an answer that says so:
   `systemd-detect-virt` prints `none`,
   `kern.vm_guest` is `none`, or `kern.hv_vmm_present`
   is `0`. Where `systemd-detect-virt` is missing, an
   x86 host (`uname -m` under `@virt` is `x86_64`,
   `amd64` or `i686`) whose `hypervisor` count is 0
   and whose DMI lines name a hardware vendor. A
   hypervisor's own shell counts here: a Proxmox VE
   host prints `none`, and so does the Xen dom0 of an
   XCP-ng host although its CPU flags carry
   `hypervisor`.
4. **Unknown.** Anything else. ARM has no
   `hypervisor` flag and often no DMI, so an ARM host
   without `systemd-detect-virt` (OpenWrt, Alpine on a
   Raspberry Pi) usually lands here.

DMI vendor (`sys_vendor`) and product
(`product_name`) that name a hypervisor, with the
type to record and where a VM of that type reads its
UUID:

| Vendor                  | Product           | Type        | UUID |
| ----------------------- | ----------------- | ----------- | ---- |
| `QEMU`                  | any               | `kvm`       | DMI  |
| `VMware, Inc.`          | any               | `vmware`    | none |
| `innotek GmbH`          | any               | `oracle`    | none |
| `Xen`                   | any               | `xen`       | Xen  |
| `BHYVE`                 | any               | `bhyve`     | DMI  |
| `Parallels …`           | any               | `parallels` | none |
| `Microsoft Corporation` | `Virtual Machine` | `microsoft` | none |
| `Amazon EC2`            | not `*.metal`     | `amazon`    | none |
| `Google`                | `Google Compute…` | `google`    | none |

Google names its bare-metal machines the same way, so
its row counts only with a `hypervisor` count above 0
where there is one; Windows has none, and there the
row decides.

The UUID column says where a VM reads the key
`rules/hypervisors.md` → Linking Guest and Host
compares. It goes with the recorded type, whether a
row or `systemd-detect-virt` named it. DMI is
`/sys/class/dmi/id/product_uuid`, readable by root;
Xen is `/sys/hypervisor/uuid`, because the DMI file
is byte-swapped there. `qemu`, which
`systemd-detect-virt` prints for QEMU without KVM,
reads DMI like `kvm`. Every other type has none,
`unknown (VM)` and every container included:
Hyper-V's DMI GUID survives a copy of the VM,
VMware's is byte-swapped from hardware version 13,
and in a container DMI and `/sys/hypervisor`
describe the machine underneath.

Only where case 2 found a VM do these DMI lines name
the cloud provider, recorded after the kind:

| Field          | Match                  | Provider        |
| -------------- | ---------------------- | --------------- |
| `sys_vendor`   | `Amazon EC2`           | `Amazon EC2`    |
| `sys_vendor`   | `Google`               | `Google Cloud`  |
| `sys_vendor`   | `Hetzner`              | `Hetzner`       |
| `sys_vendor`   | `DigitalOcean`         | `DigitalOcean`  |
| `sys_vendor`   | `Vultr`                | `Vultr`         |
| `sys_vendor`   | `UpCloud`              | `UpCloud`       |
| `sys_vendor`   | `Scaleway`             | `Scaleway`      |
| `sys_vendor`   | `Linode`               | `Linode`        |
| `sys_vendor`   | `Akamai`               | `Akamai`        |
| `sys_vendor`   | `NWCS`                 | `NWCS`          |
| `product_name` | starts with `Exoscale` | `Exoscale`      |
| `product_name` | `CloudSigma`           | `CloudSigma`    |
| `product_name` | `Alibaba Cloud ECS`    | `Alibaba Cloud` |

The kinds `amazon` and `google` name their provider
themselves: where `systemd-detect-virt` printed one of
them and no row above matched, because the DMI fields
were unreadable or empty, record `Amazon EC2` or
`Google Cloud` after the kind all the same.

The providers sell bare-metal machines under the same
names, so a name alone makes no VM. On Windows, which
has only the type table to find one, it names no
hardware vendor either: the host is `unknown`. A
hoster that leaves QEMU's DMI in place stays plain
`kvm (VM)`. Past Amazon and Google, the strings are
the ones cloud-init's `ds-identify` matches
(https://github.com/canonical/cloud-init/blob/main/tools/ds-identify).

On Windows the same strings come from `Manufacturer`
and `Model` in the `@hardware` part of
`rules/os/windows.md` → Version Detection.

On WSL record `wsl (container)`, whatever the lines
say; `Platform:` carries what that means.

Record it in server memory with the type the
detector named. Where a case matched but named no
type — a `hypervisor` count above 0 whose DMI lines
are in no row of the type table — the kind alone is
the type:

```
- Virtualization: none (bare metal)
- Virtualization: kvm (VM)
- Virtualization: kvm (VM, Hetzner)
- Virtualization: amazon (VM, Amazon EC2)
- Virtualization: unknown (VM)
- Virtualization: lxc (container)
- Virtualization: unknown
```

What the user says replaces it with `user` last in
the brackets — `Virtualization: none (bare metal,
user)`, `kvm (VM, Hetzner, user)` — and is never
probed again.

## Hypervisors

Whether the host runs virtual machines or system
containers of its own. A hypervisor can itself be a
VM; the two facts are independent.

The lines after `@hypervisor` name the candidates on
an ordinary system:

| Marker                                      | Manager            |
| ------------------------------------------- | ------------------ |
| `virsh`, or `/run/libvirt` listed           | libvirt            |
| `incus`                                     | Incus              |
| `lxd`, or `/var/snap/lxd/common/lxd`        | LXD                |
| `lxc-ls`, or `/var/lib/lxc` listed          | LXC                |
| `vm` and `/dev/vmm` listed (FreeBSD)        | vm-bhyve           |
| `VBoxManage`                                | VirtualBox         |
| `jail_enable: YES`, or a jail configuration | jail               |
| `bastille`                                  | Bastille           |
| `iocage`                                    | iocage             |
| `appjail`, `pot`, `cbsd`                    | other jails        |

The last four rows are FreeBSD jails and count on
FreeBSD only; `jail` is the base system's `jail.conf`.
A jail configuration is `/etc/jail.conf` listed, a
`.conf` file listed in `/etc/jail.conf.d`, or a
`jail_conf` other than `/etc/jail.conf`: that file is
the one `service jail` starts from. FreeBSD ships
`/etc/jail.conf.d` empty, so the directory alone is
no marker. What each manager's listing covers, and
when other jails count: `rules/hypervisors.md` →
FreeBSD jails.

On Windows, a `vmms` line under `@hardware` is
Hyper-V (`rules/os/windows.md` → Version Detection).

**On an appliance, only its own file decides**, never
this table. The platform's tools know its
configuration, locks and cluster state; the generic
ones underneath bypass them or are missing (Proxmox VE
runs LXC and QEMU, but `lxc-attach` and `virsh` go
around `pct`, `qm` and `/etc/pve`). An appliance file
whose guest section has an **Inventory** entry names
the `Hypervisor:` value and every command for its
guests. An appliance file without one leaves its
guests uninventoried, whatever markers show: say so in
one line when a marker showed, and record nothing.

A marker says only that the machine could run
guests. A candidate is a hypervisor once its listing
(`rules/hypervisors.md` → Inventory) shows at least
one guest in any state, or its manager's service is
enabled. Record the managers found:

```
- Hypervisor: libvirt, Incus
```

A candidate without guests and without an enabled
service gets no line.

## Roles

The role is what the machine is for, and it decides
what is expected of it, not how it is administered.
Two exist:

- **server** — the default, and what every rule and
  skill is written for. It has no file.
- **workstation** — a machine a person works at. It
  sleeps, changes networks and reboots when its owner
  decides, and its OS's own updater and firewall are
  what count. `rules/role/workstation.md` says what
  changes.

A machine whose memory has no `Role:` line gets
`workstation` when it is the local machine, runs
macOS, or its platform file says so; anything else
gets `server`. Windows Server (`ProductType` 2 or 3)
gets `Role: server (inferred: Windows Server)`.
Record it with where it came from —
`Role: workstation (inferred: macOS)` — and say it in
one line when it is recorded: *"Recorded as a
workstation (macOS) — say so if it serves others."*
What the user says replaces it as
`Role: server (user)`, and a role the user set is
never inferred again. The purpose decides, never the
OS: a Mac mini that runs builds for a team is a
server.
