# Passthrough

What a host has handed to a guest — a PCI device, a USB device, a
directory — and what it means for the host. Runs on a host that
has guests (`rules/system-containers.md`).

A VM and a container take a device differently:

- **A VM takes it away.** The host's driver is detached and a stub
  driver holds the device, so nothing on the host reads it any
  more — the UPS behind a passed-through USB port answers
  `references/usb-devices.md` no longer.
- **A container shares it.** The host keeps the kernel driver, and
  host and guests use the device at the same time; several
  containers can hold the same one.

## The host's side

What the host reserved for a guest, whatever manages the guests.
On Linux this rides in the call of the USB inventory
(`references/usb-devices.md`), which walks sysfs anyway:

```sh
seen=
for d in /sys/bus/pci/devices/*; do
  drv=$(readlink "$d/driver"); drv=${drv##*/}
  case "$drv" in vfio-pci|pci-stub|xen-pciback|pciback) ;; *) continue ;; esac
  read -r v < "$d/vendor"; read -r p < "$d/device"; read -r c < "$d/class"
  g=$(readlink "$d/iommu_group"); g=${g##*/}
  echo "== ${d##*/} ${v#0x}:${p#0x} class=${c#0x} driver=$drv iommu=$g"
  case " $seen " in *" $g "*) continue ;; esac
  seen="$seen $g"
  for m in "$d"/iommu_group/devices/*; do
    md=$(readlink "$m/driver"); md=${md##*/}
    case "$md" in vfio-pci|pci-stub|xen-pciback|pciback) continue ;; esac
    echo "   also ${m##*/} ${md:-none}"
  done
done
```

Each `==` line is a device reserved for a guest: `vendor:device`,
PCI class, the stub driver holding it and its IOMMU group.
`vfio-pci` and the older `pci-stub` are KVM's, `xen-pciback` is
Xen's, which an XCP-ng dom0 uses. An `also` line is a device in
the same IOMMU group that a host driver still holds — a group is
passed through as a whole.

A device whose driver is unbound without a stub taking it over
looks the same as one nobody uses, so this probe does not see it;
the guest's configuration below is what names it.

**FreeBSD** reserves a device for bhyve with the `pptdevs` loader
variable, and it then attaches to `ppt` rather than its own
driver ([bhyve(8)](https://man.freebsd.org/cgi/man.cgi?query=bhyve&sektion=8)):

```sh
pciconf -l | grep '^ppt'
```

`pciconf` reads the PCI device nodes and needs root. Each `ppt`
line is a device bhyve may hand to a guest; which guest holds it
comes from the guest's own configuration.

**Windows** hands a device to Hyper-V by dismounting it from the
host ([Discrete Device
Assignment](https://learn.microsoft.com/windows-server/virtualization/hyper-v/deploy/deploying-storage-devices-using-dda)).
`rules/os/windows.md` → Housekeeping holds the form; a dismounted
device the host lists but no VM holds is the finding below.

## The guest's side

Which guest got it comes from the guest inventory, which reads
the lines anyway (`rules/hypervisors.md` → Inventory, and on an
appliance its own file's Inventory entry): the `hostpci`, `usb`,
`virtiofs`, `dev`, `mp` and `lxc.` lines of a Proxmox guest
configuration,
the `lxc.mount.entry` and device lines of a plain LXC
container's `config`, `expanded_devices` under Incus and LXD,
`<hostdev>`, `<filesystem>` and a `hostdev` `<interface>` in a
libvirt domain's XML, and for Hyper-V `rules/os/windows.md` →
Housekeeping. No call of this file's own.

A container takes a device node, not a PCI function; the same
lines carry both.

## Bind mounts

A container may hold a directory of the host, `mp0:
/host/dir,mp=/dir` on Proxmox, a `disk` device with a host
`source` under Incus and LXD. Snapshot and backup consequences:
`rules/system-containers.md` → Snapshots. Privileged versus
unprivileged, which decides whether the guest sees the host's
ownership at all: `rules/system-containers.md` → Privileges.

What the inventory adds is the source, the path inside the guest,
and one check: where the host mounts a network share and hands
out directories of it, the share may not have been mounted when
the guest started, and the guest then writes into an empty
directory on the root filesystem. One call covers every source:

```sh
findmnt -ln -o TARGET,SOURCE,FSTYPE,UUID
```

`-l` is what prints a flat list rather than a tree, whose line
art the paths would have to be read out of. The longest target
that is a prefix of a bind source is the
filesystem that source sits on. Where `findmnt` is missing, `df`
answers the same question (`rules/busybox.md`).

## Memory

The host records what it gave away, with the guest each device
went to, named as `guests.md` names it
(`rules/hypervisors.md` → guests.md):

```
- Passthrough: 10de:2204 → VM 101 (exclusive); /dev/dri → CT 108 (shared); /srv/media → CT 108 (bind on /srv: nas.example.com:/media, nfs4)
```

`exclusive` is a VM's device, `shared` a container's, `bind` a
directory. A bind records the mount its source sat on when the
check last saw it healthy — `TARGET`, `SOURCE` and `FSTYPE` of
the mount `findmnt` matched — because that is what the next run
compares against: without it, a source that has fallen back to
the root filesystem looks like any other local directory. A
local disk records its `UUID` instead of `SOURCE`
(`bind on /data: UUID=3f2a…, ext4`), since its `SOURCE` is a
kernel device name that can change at boot; where only `df`
answers, which prints no `UUID`, `SOURCE` stands. A mount is the
recorded one when its target and its identity both match.

The guest's entry in `guests.md` carries the device too; its own
memory names the device alone, since `Runs on:` already names the
host.

## Findings

Severities as in `references/report-format.md`. The two the USB
inventory also has — a recorded device that is gone, a device
memory does not list yet — count here against the `Passthrough:`
line (`references/usb-devices.md` → Findings). On top:

- **WARN:** a bind source now on the root filesystem where its
  entry records another, or on any other filesystem while the
  recorded one is not mounted. The guest may be writing into the
  host's system disk. Memory above says when a mount is the
  recorded one.
- **INFO:** a bind source on another mounted filesystem, not the
  root one, while the recorded one is still mounted: the data
  moved. Update the entry.
- **INFO:** a reserved device no guest claims. `vfio-pci` also
  serves the host's own userspace drivers (DPDK, SPDK), so ask
  once whether a host workload uses it and record the answer in
  `Passthrough:` (`01:00.0 (host: DPDK)`); a device nobody claims
  after that is a **WARN**.
- **WARN:** a guest configured for a device the host no longer
  has. The host's side lists only what a stub holds, and a stopped
  VM's device may be back on its own driver, so check the full
  device list before reporting it. Resolve a Proxmox `mapping=` to
  this node's `path=` first, then look the address up:
  `ls -d /sys/bus/pci/devices/0000:01:00.*` on Linux, `pciconf -l`
  without the `grep` on FreeBSD, `xe pci-list` from XCP-ng's
  inventory; a USB device in the `==` lines of
  `references/usb-devices.md`.
- **INFO:** an `also` line — a device sharing its IOMMU group with
  a passed-through one while a host driver still holds it.
