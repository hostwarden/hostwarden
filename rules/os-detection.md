# OS Detection (mandatory first step)

Before doing any work on a server, you **must** know
its OS.

Detection is what makes `rules/os/`,
`rules/appliance/`, `rules/platform/` and
`rules/role/` reachable. Those files are not rules
that fire on a situation — they are reference data
addressed by a fact this procedure establishes.
Detection reads **at most one** family file — the family
it just established, and no other — and on top of it
**at most one** appliance file, **at most one**
platform file and **at most one** role file, in that
order (see Layers below). A distribution no family
covers gets no family file; step 2 below says what to
do instead. Never reach for the nearest file — a Debian
reference on an Arch host prescribes the wrong
package manager and the wrong firewall.

That cap is on detection, not on the session. A
workflow that deals with two operating systems at once
— an OS replacement, a dual-boot setup — reads the
file for each of them, old and new, because each is a
fact about a real system. The `hostwarden-os-install`
skill says so where it needs it.

## On first connection

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
     'grep -E "^(ID|ID_LIKE|VERSION_ID|PRETTY_NAME|OS_VERSION|OS_IS_BETA)=" /etc/os-release;' \
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
     'echo @hypervisor; which virsh incus lxd lxc-ls vm VBoxManage;' \
     'ls -d /run/libvirt /var/snap/lxd/common/lxd /var/lib/lxc /dev/vmm;' \
     'echo @platform; cat /proc/version; printenv WSL_DISTRO_NAME'
   ```
   `ssh` joins the quoted pieces with spaces into one
   command line. In local mode, run the same commands
   without `ssh`.

   Keep its shape: single quotes, so the local shell
   does not expand `$$`; no redirects, `&&` or `$(…)`,
   because the account's login shell runs it and that
   is not always sh — csh and tcsh are common on
   FreeBSD and the firewalls built on it; and `ps`
   not last, because bash and dash exec the last
   command of `-c` in place and `ps` would then report
   itself. Every OS lacks some of these commands, so
   expect "not found" errors: read what the commands
   that exist printed, and nothing else. An error line
   can turn up under any `@` marker, because ssh passes
   stdout and stderr on separately; never read it as
   belonging to the section it lands in.

   **The first line decides whether to go on.** If it
   is anything but `Linux`, `FreeBSD` or `Darwin` — a
   menu, a banner, "This account is currently not
   available" — the account has no command shell. Stop
   and show the user the output. Never answer a menu
   over SSH: the same menus reboot the machine or reset
   it to factory defaults.

   One exception: when no line reads `Linux`,
   `FreeBSD` or `Darwin` and the reply holds an error
   that names `uname` as a command the shell could not
   find — in whatever language the host speaks — a
   shell ran the line and knows no `uname`. That is
   how `cmd.exe` and PowerShell answer; PowerShell
   also runs the rest, so a bare hostname can come
   first. Go on with Windows below.

   A first line that starts with `MINGW`, `MSYS_NT` or
   `CYGWIN_NT` is a POSIX layer — Git Bash, MSYS2,
   Cygwin — that Windows OpenSSH starts as its default
   shell. Go on with Windows too, but skip `cmd /c ver`,
   whose `/c` such shells may rewrite as a path, and
   run the PowerShell probe directly.

   **The second line is the shell** (compare its
   basename; macOS may print `-zsh` or a path). Record
   it per SSH user in server memory (`Shell: csh
   (root)`). Because the login shell is not always sh,
   every later call goes through the `sh -s` bundle
   from `rules/ssh-connections.md` → Bundle commands,
   whatever the shell; only this probe goes without
   stdin, so nothing is ever typed into a menu. An
   error in place of the second line (busybox `ps`
   rejects `-p`) means reading the shell from the SSH
   user's line in `/etc/passwd` in the next call;
   record `Shell: unknown` only if that fails too. A
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
     `ID`. If no family file matches (e.g. Arch,
     Gentoo), tell the user, proceed cautiously
     with generic commands, and apply extra
     verify-before-running care.
   - **FreeBSD:** `freebsd`, version from the
     `freebsd-version` line.
   - **macOS:** `macos`, version from the `sw_vers`
     line.
   - **Windows:** `windows`, from the Windows probe
     below; the lines after `@release` do not apply.

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
   Add `zpool status` to the next call on a FreeBSD
   host with ZFS. Whether the hardware is the host's
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

## Windows

When step 1 ends in the `uname` error, the second
call asks cmd.exe, which every Windows host has
whatever its SSH default shell is:

```
ssh … <host> 'cmd /c ver'
```

A line naming Windows and a version number means
Windows; Microsoft does not document the exact
format, so read it for those two things only.
Anything else: stop and show the user both replies.

Then read `rules/os/windows.md` and run its Version
Detection probe through PowerShell as its Reaching
PowerShell section describes.

**`ProductType` decides whether to go on.** `2` is a
domain controller and `3` a server: carry on. `1` is
a Windows client, which is no managed target: say so,
name the alternative — Hostwarden runs on a Windows
client in WSL 2 (`docs/install.md` → Windows) — and
stop. Record nothing.

Windows has no appliance or platform markers: steps 3
and 4 do not apply.

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
names, then the appliance file on top of it, the way
an override is read (`rules/overrides.md` → The
format): `## Replace:` and `## Remove:` take a section
of the base out, `## Add:` and a heading without a
prefix add to it, and a section the appliance file
does not name applies as the base wrote it.
`Base: none` means no family file at all. Record
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

A platform file has no `Base:` line. It applies on top
of whatever family detection found, and on top of an
appliance file if there is one, with the same prefixes,
so a `Replace:` or `Remove:` names a section every
family file has. Record `Platform: …` in server memory,
in the form the platform file gives.

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
   `1` (a FreeBSD jail). Checked first because in a
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
   DMI lines from the table below.
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
type to record:

| Vendor                  | Product           | Type        |
| ----------------------- | ----------------- | ----------- |
| `QEMU`                  | any               | `kvm`       |
| `VMware, Inc.`          | any               | `vmware`    |
| `innotek GmbH`          | any               | `oracle`    |
| `Xen`                   | any               | `xen`       |
| `BHYVE`                 | any               | `bhyve`     |
| `Parallels …`           | any               | `parallels` |
| `Microsoft Corporation` | `Virtual Machine` | `microsoft` |
| `Amazon EC2`            | not `*.metal`     | `amazon`    |
| `Google`                | any               | `google`    |

A cloud vendor also sells bare-metal machines under
its own name, so `Amazon EC2` and `Google` count only
with a `hypervisor` count above 0 where there is one.

Smaller cloud providers run KVM and name themselves in
DMI, in no row of the type table. Only where case 2
found a VM do these DMI lines name the provider,
recorded after the kind; like `Amazon EC2`, the names
also sit on bare-metal machines. A `sys_vendor` of
`Hetzner`, `DigitalOcean`, `Vultr`, `UpCloud`,
`Scaleway`, `Linode`, `Akamai` or `NWCS` is the
provider as it stands; a `product_name` that starts
with `Exoscale`, or is `CloudSigma` or `Alibaba Cloud
ECS`, names `Exoscale`, `CloudSigma` or `Alibaba
Cloud`.
The strings are the ones cloud-init's `ds-identify`
matches
(https://github.com/canonical/cloud-init/blob/main/tools/ds-identify).
A hoster that leaves QEMU's DMI in place stays plain
`kvm (VM)`. Windows has only the type table to find a
VM, so there a provider's name makes no VM and names
no hardware vendor either: the host is `unknown`.

On Windows the same strings come from `Manufacturer`
and `Model` in the `@hardware` part of
`rules/os/windows.md` → Version Detection.

On WSL record `wsl (container)`, whatever the lines
say; `Platform:` carries what that means.

Record it in server memory with the type the
detector named. Where a case matched but named no
type — a `hypervisor` count above 0 whose DMI lines
are in no row — the kind alone is the type:

```
- Virtualization: none (bare metal)
- Virtualization: kvm (VM)
- Virtualization: kvm (VM, Hetzner)
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

| Marker                                | Manager    |
| ------------------------------------- | ---------- |
| `virsh`, or `/run/libvirt` listed     | libvirt    |
| `incus`                               | Incus      |
| `lxd`, or `/var/snap/lxd/common/lxd`  | LXD        |
| `lxc-ls`, or `/var/lib/lxc` listed    | LXC        |
| `vm` and `/dev/vmm` listed (FreeBSD)  | vm-bhyve   |
| `VBoxManage`                          | VirtualBox |

On Windows, a `vmms` line under `@hardware` is
Hyper-V (`rules/os/windows.md` → Version Detection).
An appliance that runs guests says in its guest
section what to record and how to list them, and the
markers its own guests leave (Proxmox VE's
`/var/lib/lxc`) belong to it.

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

The activity-check call (`rules/first-connection.md`,
step 7) then carries, as `rules/hypervisors.md`
describes:

- on a host with a `Hypervisor:` line, the guest
  listing (Inventory);
- on a VM or container (Virtualization above) without
  a `Guest identity:` line, the keys that link it to
  its host (Linking Guest and Host).

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

## Layers

Later wins, and each layer is read against the result
of the ones before it:

1. the family file (`rules/os/`);
2. the appliance file (`rules/appliance/`);
3. the platform file (`rules/platform/`);
4. the role file (`rules/role/`);
5. the user's overrides, in the order
   `rules/overrides.md` → Precedence gives.

**The family file with the appliance and platform
files applied is the OS file.** Wherever an
instruction names the loaded OS file or
`rules/os/<family>.md`, it means that. A role file is
not part of it: it changes no command, only what is
expected and how a finding is rated, and it names
each rule, expectation or check it changes. What it
does not name applies as written.

The `## Housekeeping and Audits` section of the
family, appliance, platform and role file applies to
housekeeping and both audits: it adds checks, changes
the command of those it names, skips those it
excludes and rates some differently. A family file
whose commands are not `sh` (Windows) holds its checks
there in full, and the skills' baseline references do
not run on it.

## On subsequent connections

Subsequent connections run the same pipeline as the
first (see `rules/first-connection.md`), including
the blacklist and read-only checks. Specific to
known servers: read the memory file, changelog, and
`todo.md` (if present) before any work, read the
family file and the files that `Appliance:`,
`Platform:` and `Role:` name.
Shell and hardware come from memory. The first call
still goes without stdin, in the shape of step 1:
`uname -s`, then the version command from the OS
file's Version Detection section and, for an
appliance, its own, then `echo @platform;
cat /proc/version`. Its first line decides as in
step 1. On Windows the first call is `cmd /c ver`,
read as in Windows above — or, where memory records a
POSIX layer as the shell, `uname -s` read as step 1
does; the second is the Version Detection probe of
`rules/os/windows.md` without its hardware part,
joined with the activity read-back, and its
`ProductType` decides as above. Update memory if a
version changed, and settle the platform (step 4)
when the `@platform` lines and `Platform:` disagree,
and the role (step 5) when memory has no `Role:`
line. When memory has no `Virtualization:` line or no
`Arch:` line, the first call also carries the `@virt`
lines from step 1, and for a missing `Arch:` the
`model name` and `hw.model` lines of `@hardware` that
name the maker; on Windows the second call carries
its `@hardware` part, which holds both. Virtualization
and step 2 above settle them. If a command fails or
the OS no longer matches memory, run the full probe
from step 1.
