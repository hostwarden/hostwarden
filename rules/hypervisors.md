# Hypervisors and Their Guests

Every guest on a hypervisor (`rules/os-detection.md` → Hypervisors)
is inventoried without being asked for, running or not, and every
guest with memory of its own records which host it runs on. The
inventory comes from the hypervisor's manager, never from SSH into
the guests: whether and how a guest can be reached is not known
until it is in memory.

Application containers (Docker, Podman) are not guests
(`rules/containers.md`). Reaching and changing a guest is
`rules/system-containers.md`.

## Inventory

**When:** the full inventory on the first connection and in
housekeeping. On a later connection, the light listing (ID and
state only), once a day at most: when `Inventoried:` is not
today, or when the request is about guests. The full inventory
then runs for the guests whose listing differs from `guests.md`.

**Privileges:** each manager shows the system's guests to root
and to its root-equivalent group
(`rules/privilege-escalation.md`). Where neither is available,
record the manager detection found with the reason,
`Hypervisor: Incus (guests unreadable without root)`, and say so
in one line; never guess the guests.

**Never start a stopped guest to look inside.** A retired server
brought back can take the IP address or the jobs of the one that
replaced it.

Per guest, record: ID, name, kind (VM, container or jail), state,
whether it starts with the host, whether the hypervisor marks it
as a template, its MAC addresses, and a VM's UUID where Linking
below names a source for it. On a host with more than one
manager, an ID or a name is unique only within its manager: each
entry then starts with its manager (`incus: prod/web`), and
`Runs on:`, the link and a second directory of one hostname
(`rules/server-memory.md`) carry it too. Per-guest commands go
into one
bundled call (`rules/ssh-connections.md`). On an appliance, its
file's **Inventory** entry gives every command, and nothing below
applies (`rules/os-detection.md` → Hypervisors). Elsewhere:

- **libvirt:** always `virsh -c qemu:///system`: without it, a
  non-root `virsh` opens the user's own session and lists nothing.
  `list --all` is the light listing; `list --all --autostart` for
  autostart, and per domain `domuuid` and `domiflist`.
- **Incus / LXD:** the listing from `rules/system-containers.md`
  → Reaching It, with `--format json`: it carries each
  instance's project, and its `expanded_config` the
  `volatile.<nic>.hwaddr` and `boot.autostart`, a profile's
  included. Record the project with the name (`prod/web`); every
  later command carries it.
- **LXC:** `lxc-ls -f` shows state and autostart;
  `grep -H hwaddr /var/lib/lxc/*/config` the MACs.
- **vm-bhyve:** `vm list` shows `AUTO` and `STATE`; `vm info`
  without a name gives every VM's MACs and UUID.
- **Hyper-V:** `rules/os/windows.md` → Version Detection.
- **VirtualBox:** `VBoxManage list vms` lists the calling user's
  VMs only; ask whose account runs them before concluding there
  are none.
- **FreeBSD jails:** below.

### FreeBSD jails

A jail's name is its ID: the JID that `jls` prints changes at
every start and is never recorded. Its kind is `jail`, and its
entry also records the jail's path, its `host.hostname` where
that differs from the name, and whether it has `vnet`, its own
network stack.

Every jail host's call starts with the services that start jails
at boot, which are also what makes a candidate a hypervisor
(`rules/os-detection.md` → Hypervisors), and with the running
jails of every manager and the MACs and addresses of those with
`vnet`:

```bash
sysrc jail_enable jail_list jail_conf bastille_enable iocage_enable
jls -n name path host.hostname ip4.addr ip6.addr vnet
jls name vnet | while read -r n v; do
  test "$v" = new && echo "@ifconfig $n" && ifconfig -j "$n" -a
done
```

`sysrc` without `-n` names each variable in front of its value,
so one it does not know leaves the others readable. `jls` fails
as a whole on a parameter the kernel does not know (`vnet`
without `VIMAGE`, `ip6.addr` without IPv6): an error in place of
the list means dropping that parameter and asking again, never
that no jail runs. `jls` lists running jails only; the stopped
ones come from each manager's own list. The light listing is
`jls -N` and those lists, without the `ifconfig` loop:

- **jail:**

  ```bash
  for f in /etc/jail.conf /etc/jail.conf.d/*.conf; do
    test -r "$f" && echo "@conf $f" && jail -f "$f" -e '|'
  done
  ```

  Where `jail_conf` names another file than `/etc/jail.conf`, the
  loop reads that one in its place: it is the file `service jail`
  starts from. `jail -e` prints every jail the file defines,
  running or not, one line each with its parameters, and changes
  nothing. A jail printed twice, because `/etc/jail.conf` includes
  the directory, is one jail. It starts with the host when
  `jail_enable` is `YES` and `jail_list` names it. With
  `jail_list` empty, the jails of the file `jail_conf` names and
  the files it includes start; a file in `/etc/jail.conf.d/` that
  it does not include does not.
- **Bastille:** `bastille list all` shows every jail with `BOOT`,
  `STATE`, its addresses, hostname and path. A jail starts with
  the host when `BOOT` is `on` and `bastille_enable` is `YES`.
  Its configuration is `jail.conf` in the directory above its
  path (`/usr/local/bastille/jails/<name>/jail.conf`).
- **iocage:** `iocage list -l` shows `BOOT`, `STATE`, `TYPE` and
  the addresses, `iocage list -t` the templates, recorded as
  `template (hypervisor)`, and `iocage get -r vnet` which jails
  have `vnet`. A jail starts with the host when `BOOT` is `on`
  and `iocage_enable` is `YES`. `jls` shows it under another
  name (`rules/system-containers.md` → Reaching It).
- **Any other:** a running jail that no list above names belongs
  to a manager Hostwarden does not read — AppJail, pot, cbsd, or
  one started by hand — and `jls` does not say which. Its entry
  records `manager unknown` and autostart as unknown. Such
  jails, not an installed tool, make the host a hypervisor:
  `Hypervisor: other jails (running only)`. Say in one line
  that their stopped jails are not listed.

A jail without `vnet` has no MAC of its own: its addresses, the
`ip4.addr` and `ip6.addr` the listing shows, sit on the host's
interfaces. A stopped `vnet` jail's MAC is the one its
configuration fixes, or else the one `guests.md` has:

- **jail, Bastille:** an `ether` set on the jail's side of its
  `epair` in its configuration file (Bastille names that side
  `e<n>b_<jail>`, and its address ends in `b`);
- **iocage:** `iocage get -r vnet0_mac` (`vnet1_mac` … for more
  interfaces) prints the host's and the jail's address, the
  jail's second, as twelve hex digits without colons, separated
  by a space or a comma.

An `epair` without an `ether` in the configuration takes a MAC
that depends on the unit number it gets at start, so that MAC can
change whenever the jail starts.

### Guest tools

Where a running guest has an agent, the hypervisor answers for it
without SSH: hostname, OS and IP addresses. Ask only for guests
whose hostname or OS `guests.md` does not know yet, only
read-only queries, each under `timeout 5` in the same call, and
never for a guest on the blacklist (`rules/access-control.md`).
libvirt's is `virsh -c qemu:///system guestinfo <dom>`; the
appliance files and `rules/os/windows.md` name theirs.
Containers need none: their manager lists the addresses.

A running VM without an agent is recorded as `no agent`. Where
the appliance file says `Guest tools: none`, the manager has no
read-only way to ask an agent: every running VM there is recorded
as `agent not readable` instead, and its hostname, OS and
addresses stay unknown until it is connected to. A root
shell through the agent is via-host mode
(`rules/system-containers.md` → Reaching It): never part of the
inventory, and used right after it only for Registering Guests.

## guests.md

The inventory lives in `memory/servers/<host>/guests.md`, one
entry per guest, whether or not the guest has a memory directory
of its own (Registering Guests below).

```markdown
# Guests on pve1.example.com

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

A jail's entry is named, not numbered:

```markdown
- web (jail): running, autostart. vnet, 192.0.2.31.
  mac 58:9c:fc:0a:1b:2b, path /usr/local/bastille/jails/web/root
  → web.example.com
```

`→ <memory directory>` links a guest to its own memory;
`→ probably …` is a name or IP match the guest has not confirmed
yet (Linking below).

## Stopped Guests

A stopped guest the hypervisor marks as a template needs no
question. Every other stopped guest without a reason in
`guests.md` gets one, after the user's request is answered: one
list of them all, in the picker form of
`rules/service-reload.md` → Prompt Shape When Asking, where one
answer can cover all or a single guest:

    Stopped on pve1.example.com: web1, mail-old, test3. Why?
      [1] Off on purpose (standby, started when needed)
      [2] Retired, not deleted yet
      [3] Not in service yet
      [4] Template or clone source

A free answer is recorded as given. For `[2]`, ask until when it
is kept; "no date" is an answer too. Record the reason in the
guest's entry with `(user, <date>)`. A guest that starts loses
its reason; one that stops again is asked again.

Never delete a guest because of an answer here: removal is the
user's explicit request (`rules/system-containers.md` →
Changes).

## Registering Guests

A running guest the host's manager can enter gets a memory
directory of its own right after the inventory, so the user never
has to name each guest. This is the one read-only use of via-host
mode that needs no failed SSH first
(`rules/system-containers.md` → Reaching It). Which guests the
manager can enter, and how, is listed there: containers always,
FreeBSD jails among them, a Proxmox VM only with a responding
agent, whose answer is read as that section says (`out-data`,
`exitcode`). A libvirt, Hyper-V, XCP-ng, bhyve or VirtualBox VM,
a Windows guest on any of them (reached over OpenSSH only), and
every stopped guest stay in `guests.md` alone until they are
connected to by name.

Per guest, after the user's request is answered and announced in
one line (*"Registering 7 guests of pve1.example.com through
`pct exec` — read-only"*):

1. Before entering the guest, run the shared lookup of
   `rules/access-control.md` for the blacklist and the read-only
   list with everything the inventory knows of it: the manager's
   name, the hostname it already has (a container's config, a
   jail's `host.hostname`, the agent's `get-host-name`), the
   first label of each, so `db1` meets a listed
   `db1.example.com`, and the IP addresses the manager or the
   agent reported, against listed addresses and listed names
   resolved. Where the inventory has no hostname or
   no address, a first call reads only `hostname -f`, `hostname`
   and the guest's addresses, and the lookup runs on them before
   anything else. A blacklisted guest is not entered further:
   note `blacklisted` in its entry.
2. Inside the guest, run the rest of the pipeline as
   `rules/first-connection.md` → Via-host mode gives it, one
   bundled call per step: OS detection with the link keys
   (Linking below), the activity check with its
   configuration-management probe, and the Heinzel check where it
   applies. What they find is recorded as they say.
3. The hostname names the memory directory. Where one exists
   already and its `Guest identity:` or its `IP:` matches this
   guest, it is the same server: add only `Runs on:` and the
   missing keys. Where its keys differ, this is a second server
   of that name, and its directory is named as
   `rules/server-memory.md` says for two guests of one hostname
   (`web-pve1-105`). Where the existing directory has neither
   keys nor a matching `IP:`, ask the user before writing
   anything.
4. Write `memory.md` as `rules/server-memory.md` says, with
   `Runs on:`, `Guest identity:` and
   `- SSH: untested (registered through pve1.example.com)`. The
   SSH user and the DNS check follow on its first SSH connection,
   which removes the line.
   Never `Mode: via …`: that line says the guest has no SSH of
   its own, and it would route every later session through the
   host.
5. Log a `read-only:` journal line inside the guest, in the same
   call, and a line in its local changelog (`rules/changelog.md`).

Registration never changes a guest, whatever the probe finds:
findings go into its memory and are reported in one line each.

## Linking Guest and Host

A guest does not see its host's name, and a host does not see
the name its guest gives itself. Both sides record the same keys,
and where both are in memory, whichever is connected second makes
the link. Often only one side ever is — a VM at a provider, a
hypervisor someone else runs — and that is normal, never a
finding.

- **A cloud VM** (`Virtualization: amazon (VM)`, `google`, or a
  provider after the kind, `kvm (VM, Hetzner)`) runs on its
  provider: `Runs on: Amazon EC2 (cloud)`, `Runs on: Hetzner
  (cloud)`, with no keys and no question. It is settled before
  anything below.
- **MAC addresses** — the guest reads its own without privileges
  (`ip -o link`, `ifconfig -a`, `Get-NetAdapter`); the host
  reads them from the guest's configuration. Compare them in
  lowercase with colons.
- **UUID**, from the source in the UUID column of
  `rules/os-detection.md` → Virtualization for the
  `Virtualization:` type. A type without one, `unknown (VM)` and
  containers included, links by MAC alone; a FreeBSD jail links
  as below.
- **A FreeBSD jail** has no DMI and no UUID of its own. Its keys:
  - its hostname and IP addresses,
    `Guest identity: jail web.example.com, ip 192.0.2.31`;
  - its MACs, only where `sysctl -n security.jail.vnet` prints
    `1` (Inventory → FreeBSD jails);
  - the path its host reported, where it was registered through
    it: `path /usr/local/jails/web`.

  It links by path, by MAC, or by name and address together: its
  jail name or `host.hostname` and one of its IP addresses match
  a jail that is running. Against a stopped jail, that match is
  a hint (On the host, below). A `vnet` jail whose MAC changed
  at a start links by name and address too, and both sides take
  the new MAC. The link reads
  `Runs on: bsd1.example.com (jail web)`.
- **Hyper-V** gives no usable UUID, but tells its guests the
  host's name:
  `PhysicalHostNameFullyQualified` in
  `/var/lib/hyperv/.kvp_pool_3` on Linux, under
  `HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters` on
  Windows.

**On the guest,** record the keys and the result:

```
- Guest identity: mac bc:24:11:00:01:01,
  uuid 6f1c2a3e-0000-4000-8000-000000000101
- Runs on: pve1.example.com (VM 101)
```

Look for them with one `grep -i` over
`memory/servers/*/guests.md`. A match links both, a jail's as its
bullet above says: `Runs on:` here, `→ <this directory>` in that
entry. No match: once the user's request is answered, ask once
which host it is, offering the hypervisors in memory, "one
Hostwarden does not manage" (with its name, if they want) and
"don't know", and record the answer as `Runs on: <host> (user)`,
with the guest's ID where the user gives one
(`Runs on: pve1.example.com (container 105, user)`),
`Runs on: <name> (user, not managed)` or `Runs on: unknown
(user)`. It is never asked again; a later inventory that finds the
keys replaces it. In via-host mode (`rules/first-connection.md`),
the host is the one the session goes through, and the ID the one
it enters. A guest Hostwarden just created: the host it was
created on; `Runs on:` and `Guest identity:` come from the
creation, with no lookup and no question (`hostwarden-new-guest`).

**On the host,** for the guests without a `→`, one `grep` over
the `Guest identity:` lines of `memory/servers/*/memory.md`. A
match links both. Without one, a guest whose agent-reported name
or IP address matches a memory directory's hostname or `IP:` line
is only a hint: `→ probably <directory>`, confirmed or dropped
when that guest is next connected. The one exception is a
running jail matched by name and address together (the jail
bullet above). A name alone never links: templates are cloned
with their name, and a retired guest and its successor often
share one.

## Changes Between Connections

Report each difference in one line, and nothing when there is
none:

- **New guest:** its full entry.
- **Gone guest:** a missing row proves nothing by itself: the
  manager may have failed, printed part of its list, or be
  migrating the guest. Only after a listing that exited 0, and a
  read-only check for that guest by its own manager that says it
  does not exist (`qm config`, `pct config`, `virsh dominfo`,
  `incus info --project …`, `xe vm-list uuid=…`, `bastille list
  <jail>`, `iocage get -s <jail>`, or no `name=<jail>` line from
  `jail -f <file> -e '|'` for any file), remove its
  entry; a guest with memory of its own then gets
  `Runs on: unknown (left <host> <date>)` and loses its
  `Mode: via …` line, and if it turns up on another host, the keys
  link it there. A guest the cluster listing shows on another node
  moved: `Runs on:` names that node, and a `Mode: via …` line is
  rewritten for it (`rules/server-memory.md`).
  Until the check settles it, the entry only gains
  `not listed <date>`.
- **State changed:** update the entry.

Update `Inventoried:` after every listing, full or light: it is
what limits the light listing to once a day.

Housekeeping rates the inventory
(`.agents/skills/hostwarden-housekeeping/references/guests.md`).
