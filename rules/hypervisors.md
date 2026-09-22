# Hypervisors and Their Guests

A hypervisor is a host that runs virtual machines or system
containers of its own: Proxmox VE and XCP-ng, but just as well
libvirt/KVM, Incus, LXD or LXC on an ordinary distribution, bhyve
on FreeBSD, Hyper-V on Windows Server, or VirtualBox. It can
itself be a VM (nested virtualization): then its memory has both a
`Virtualization: … (VM)` and a `Hypervisor:` line.

Every guest on it is inventoried without being asked for, running
or not, and every guest that has memory of its own records which
host it runs on. The inventory comes from the hypervisor's own
manager, never from SSH into the guests: whether and how a guest
can be reached is not known until it is in memory.

Application containers (Docker, Podman) are not guests; they are
`rules/containers.md`. How a guest is reached and changed is
`rules/system-containers.md`.

## Detect

The lines after `@hypervisor` in the step-1 probe
(`rules/os-detection.md`) name the candidates:

| Marker                                   | Manager    |
| ---------------------------------------- | ---------- |
| `pveversion` under `@appliance`          | Proxmox VE |
| `ID=xcp-ng` under `@release`             | xe         |
| `virsh`, or `/run/libvirt` listed        | libvirt    |
| `incus`                                  | Incus      |
| `lxd`, or `/var/snap/lxd/common/lxd`     | LXD        |
| `lxc-ls`, or `/var/lib/lxc` listed       | LXC        |
| `vm` and `/dev/vmm` listed (FreeBSD)     | vm-bhyve   |
| `VBoxManage`                             | VirtualBox |

On Windows Server, `Get-Service vmms` joins the Version Detection
call of `rules/os/windows.md`; a service by that name is Hyper-V.

On Proxmox VE, `lxc-ls` and `/var/lib/lxc` are its own
containers, and Proxmox VE is the manager for them.

`/dev/kvm` or `/dev/vmm` alone says only that the machine could
run guests. A candidate is a hypervisor once its inventory below
lists at least one guest in any state, or its manager's service
is enabled. Record the managers found:

```
- Hypervisor: Proxmox VE (qm, pct)
- Hypervisor: libvirt, Incus
```

A candidate without guests and with no enabled service gets no
line. Housekeeping looks at the markers again, and so does a
session that installs a hypervisor.

## Inventory

**When:** on the first connection to a hypervisor, the whole
inventory; on every later connection, the listing only, joined
to the activity-check call (`rules/first-connection.md`). Where
the listing differs from `guests.md`, the full inventory runs for
the guests that differ.

**Privileges:** each manager shows the system's guests to root
only, or to members of its admin group (`libvirt`,
`incus-admin`, Hyper-V Administrators). Reading them is a read:
escalate as `rules/privilege-escalation.md` says. Where that is
not possible, record
`Hypervisor: libvirt (guests unreadable without root)` and say
so in one line; never guess the guests.

**Read-only:** the inventory is a read and runs on a host on the
read-only list too. It never starts, stops or changes a guest.
In particular, **never start a stopped guest to look inside**:
a retired server brought back can take the IP address or the
jobs of the one that replaced it.

Per guest, record: ID, name, kind (VM or container), state,
whether it starts with the host, whether the hypervisor marks it
as a template, its MAC addresses, and for a VM its UUID. The
commands, each one call for all guests:

- **Proxmox VE:** `pvesh get /cluster/resources --type vm
  --output-format json`, filtered to this node's `node`; then, in
  the same call, the head of every guest config up to its first
  snapshot section:

  ```bash
  for f in /etc/pve/qemu-server/*.conf /etc/pve/lxc/*.conf; do
    echo "@conf $f"
    sed -n '/^\[/q; /^net[0-9]*:/p; /^smbios1:/p;
      /^template:/p; /^onboot:/p' "$f"
  done
  ```

  A VM's MAC is the `virtio=`/`e1000=` value of its `netN:` line,
  a container's the `hwaddr=` value; the UUID is `uuid=` in
  `smbios1:`.
- **libvirt:** always `virsh -c qemu:///system`: without it, a
  non-root `virsh` opens the user's own session and lists nothing.
  `list --all` for the domains, `list --all --autostart` for
  autostart, and per domain `domuuid` and `domiflist`.
- **XCP-ng:** `xe vm-list is-control-domain=false
  params=uuid,name-label,power-state,is-a-template,other-config`,
  and `xe vif-list params=vm-uuid,MAC`. A template with
  `default_template: true` in `other-config` ships with XCP-ng
  and is left out; any other template is the user's.
- **Incus / LXD:** `incus list --all-projects`
  (LXD: `lxc list --all-projects`) lists stopped instances too;
  `incus config show <instance>` carries `volatile.<nic>.hwaddr`
  and `boot.autostart`.
- **LXC:** `lxc-ls -f` shows state and autostart;
  `lxc.net.0.hwaddr` in `/var/lib/lxc/<name>/config`.
- **vm-bhyve:** `vm list` shows every VM with `AUTO` and `STATE`;
  `vm info <name>` its MACs and UUID.
- **Hyper-V:** `Get-VM` (`Name`, `State`, `VMId`,
  `AutomaticStartAction`) and `Get-VMNetworkAdapter -VMName *`
  (`VMName`, `MacAddress`, `IPAddresses`). Hyper-V prints MACs
  without separators.
- **VirtualBox:** `VBoxManage list vms` lists the calling user's
  VMs only; ask whose account runs them before concluding there
  are none.

An appliance file that names its own guest listing (Unraid,
ZimaOS) wins over the list above.

### Guest tools

Where a guest runs its agent, the hypervisor answers for it
without SSH: hostname, OS and IP addresses. Ask it only for
running guests, only read-only queries, and never for a guest
on the blacklist (`rules/access-control.md`):

- **Proxmox VE:** `qm guest cmd <vmid> get-host-name`,
  `get-osinfo`, `network-get-interfaces`
- **libvirt:** `virsh -c qemu:///system domifaddr <dom> --source
  agent`, `guestinfo <dom>`
- **XCP-ng:** the VM parameters `os-version` and `networks`,
  which the guest tools fill
- **Hyper-V:** `IPAddresses` above; integration services fill it
- **Containers** (Incus, LXD, LXC, Proxmox `pct`) need no agent:
  their manager lists the addresses itself.

A running VM without an agent is recorded as `no agent`. A root
shell through the agent (`qm guest exec`) is via-host mode and
follows `rules/system-containers.md` → Reaching It, never the
inventory.

## guests.md

The inventory lives in `memory/servers/<host>/guests.md`, one
entry per guest, wrapped at 80 characters. A guest gets a memory
directory of its own only when it is connected to itself
(`rules/server-memory.md`); until then this entry is all there
is.

```markdown
# Guests on pve1.example.com

- Hypervisor: Proxmox VE (qm, pct)
- Inventoried: 2026-09-22

- 101 web1 (VM): running, autostart. Debian 13 (agent),
  192.0.2.21. mac bc:24:11:00:01:01,
  uuid 6f1c2a3e-0000-4000-8000-000000000101
  → web1.example.com
- 102 db1 (container): running, autostart. 192.0.2.22.
  mac bc:24:11:00:01:02 → probably db1.example.com
- 110 mail-old (VM): stopped. Retired, keep until 2026-12-31
  (user, 2026-09-22). mac bc:24:11:00:01:10
- 9000 debian13-tpl (VM): template (hypervisor).
```

`→ <memory directory>` links a guest to its own memory; `→
probably …` is a name or IP match that the guest has not yet
confirmed (Linking below).

## Stopped Guests

A stopped guest the hypervisor marks as a template needs no
question. For every other stopped guest without a reason in
`guests.md`, ask the user once why it is off, up to four guests
per question. Offer:

    web1 is stopped on pve1.example.com. Why?
      [1] Off on purpose (standby, started when needed)
      [2] Retired, not deleted yet
      [3] Not in service yet
      [4] Template or clone source

Use `AskUserQuestion` where the tool has it; otherwise print the
ASCII form. A free answer is recorded as given. For `[2]`, ask
until when it is kept; "no date" is an answer too. Record the
reason in the guest's entry with `(user, <date>)`.

The question comes back only when the state changes: a guest
that starts loses its reason, and one that stops again is asked
again. Never delete a guest, retired or not, because of an
answer here: removal is the user's explicit request
(`rules/system-containers.md` → Changes).

## Linking Guest and Host

Neither side can name the other by itself: a guest does not see
its host's name, and a host does not see the name its guest
gives itself. Both sides record the same keys, and whichever
side is connected second makes the link:

- **MAC addresses** — the guest reads its own without privileges
  (`ip -o link`, `ifconfig -a`, `Get-NetAdapter`); the host
  reads them from the guest's configuration. Compare them in
  lowercase with colons.
- **UUID**, VMs only, where the guest sees the one its host
  records:
  - KVM (Proxmox VE, libvirt), bhyve: the guest's
    `/sys/class/dmi/id/product_uuid`, readable by root, is the
    VM's UUID.
  - VMware: the same file, but from virtual hardware 13 on with
    the first three fields byte-swapped against the host's
    `uuid.bios`; compare both orders.
  - Xen (XCP-ng): `/sys/hypervisor/uuid` is the VM's UUID. The
    DMI file is byte-swapped there; do not use it.
  - Hyper-V: none. The DMI UUID is the VM's BIOS GUID, which a
    copied VM keeps; MACs and the host name below link it.

  In a container, DMI and `/sys/hypervisor` describe the
  machine underneath: never record a UUID there.
- **Hyper-V** tells its Linux guests the host's name through the
  KVP daemon (`PhysicalHostNameFullyQualified` in
  `/var/lib/hyperv/.kvp_pool_3`) and its Windows guests under
  `HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters`.
- **A cloud VM** (`Virtualization: amazon (VM)`, `google`, …)
  runs on its provider: `Runs on: Amazon EC2 (cloud)`, with no
  keys and no question.

**On the guest.** When `rules/os-detection.md` → Virtualization
settles a VM or a container and memory has no
`Guest identity:` line, the next call reads the MACs, and the
UUID where the session is root already. Record them, then look
for them in every `memory/servers/*/guests.md`:

```
- Guest identity: mac bc:24:11:00:01:01,
  uuid 6f1c2a3e-0000-4000-8000-000000000101
- Runs on: pve1.example.com (VM 101)
```

- A match links both: `Runs on:` here, `→ <this directory>` in
  that entry.
- No match: `Runs on: unknown`. Ask the user once which host it
  is, offering the hypervisors in memory, "one Hostwarden does
  not manage" and "don't know"; record the answer with
  `(user)`. The next inventory of that host confirms it or says
  it was wrong.
- In via-host mode (`rules/first-connection.md`), the host is
  the one the session goes through: record `Runs on:` directly,
  and read the keys all the same.

**On the host.** For each guest in the inventory, look for its
MAC or UUID in the `Guest identity:` lines of
`memory/servers/*/memory.md`. A match links both. Without one,
a guest whose agent-reported name or IP address matches a
memory directory's hostname or `IP:` line is only a hint:
`→ probably <directory>`, confirmed or dropped when that guest
is next connected.

A name alone never links: templates are cloned with their name,
and a retired guest and its successor often share one.

## Changes Between Connections

Report each difference in one line, and nothing when there is
none:

- **New guest:** its full entry; a stopped one gets the question
  above.
- **Gone guest:** remove its entry. A guest with memory of its
  own gets `Runs on: unknown (left <host> <date>)`; if it
  turns up on another host, the keys link it there.
- **State changed:** update the entry; running to stopped asks
  the question above.

Update `Inventoried:` on every listing.

## Housekeeping

On a host with a `Hypervisor:` line, housekeeping runs the full
inventory and rates:

- a stopped guest without a reason: **WARN**
- a retired guest past its keep-until date: **INFO**, naming
  the guest and the date; deleting it is the user's call
- a running guest that does not start with the host: **INFO**,
  it stays down after the next reboot
- a running VM without an agent: **INFO**

On a host without one, it looks at the markers under Detect
again, in its first batch.
