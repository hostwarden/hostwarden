---
name: hostwarden-new-guest
argument-hint: "[hypervisor] [guest name]"
description: Create a new virtual machine or system container on a
  hypervisor Hostwarden manages — Proxmox VE, libvirt, Incus, LXD
  or classic LXC — from the distribution's official cloud image,
  container template or installer, with the Hostwarden server
  baseline applied at first boot in whatever form that guest reads
  (cloud-init, Ignition, kickstart, preseed, autoinstall,
  AutoYaST), then registered like every other guest. Also builds
  and rebuilds the baseline template for containers on Proxmox VE.
  Use when the user asks to "create a VM on pve1", "set up a new
  container", "spin up a Debian guest", "make me a new server on
  <host>", "build the container template", "neuen LXC anlegen",
  "setz mir eine VM auf", "leg einen neuen Container auf pve1 an",
  "ich brauche eine neue VM". Not for installing or replacing the
  OS on an existing machine, which is hostwarden-os-install.
---

# hostwarden-new-guest

Creates a guest and hands it over as a server in memory that
meets `rules/baseline.md`. Nothing here is destructive: the guard
stays on, and a step it asks about is asked of the user.

## Before anything else

1. **Overrides:** keys `hostwarden-new-guest` and `baseline`, per
   `rules/overrides.md`.
2. **The host's pipeline** (`rules/first-connection.md`). The host
   must be in memory with a `Hypervisor:` line, and not on the
   read-only list (`rules/access-control.md`). Register the
   session on it (`rules/parallel-sessions.md`): creating a guest
   is the first change.
3. **Which reference:** by the `Hypervisor:` line.
   - `Proxmox VE (qm, pct)` → `references/proxmox.md`
   - `libvirt` → `references/libvirt.md`
   - `Incus`, `LXD` → `references/incus.md`
   - `LXC` → `references/lxc.md`
   - Anything marked `read-only`, or an appliance whose file says
     its web UI owns the guests (Unraid, ZimaOS, TrueNAS, XCP-ng
     through Xen Orchestra): the user creates it; see Hosts that
     keep guests to their UI below.
   - Anything else: say that Hostwarden has no creation path for
     it and stop.

## The request

First, one call on the host for what the defaults and the
capacity check need: the reference's Before the creation. The
guests' memory comes from the inventory the pipeline already ran
(`rules/hypervisors.md` → Inventory).

Then settle every parameter before the first change, in one
question with defaults filled in (`AskUserQuestion` where it
exists):

- **Kind:** VM or container. A container shares the host's
  kernel; a VM is the default for anything that needs its own
  kernel, a firewall of its own at kernel level, or Docker
  without nesting.
- **Distribution and release:** the current stable release,
  looked up live (`rules/version-check.md`); never an image the
  distribution no longer supports.
- **Name:** the guest's FQDN. Where a `rules/naming-scheme.md` block
  applies to the guest, propose the next name it gives: the site
  token is the code recorded for the hypervisor's `Site:` in
  `rules/network-topology.md` → A site's code, never the site name
  itself — asked, alongside the site, where the host has neither
  yet — the
  role asked, the index the next one free across `memory/machines/`
  and every `guests.md`, and the domain from the block. The user
  confirms it or types another. A
  typed name checked against the block and found not to match it
  (`rules/naming-scheme.md` → Checking a name) is asked about once
  — "does not follow the naming scheme — keep it and mark it
  exempt?" — a yes adds an `Exempt:` line with the reason and who
  and when to `memory/naming.md` and creation goes on with the
  typed name; a no returns to naming the guest, offering the
  proposed name again or another typed name. Once a name is
  settled: no directory of that name under `memory/machines/`, no
  guest of that name in the host's `guests.md`, and neither the
  name nor a static address on the blacklist or the read-only list
  (the lookup of `rules/access-control.md`).
- **ID** (Proxmox VE): the next free one.
- **Address:** DHCP, or a static address with prefix, gateway and
  DNS resolvers. The resolvers default to the host's own, from its
  `/etc/resolv.conf`; Proxmox VE takes those by itself when none
  are given (`--nameserver` in `qm.1` and `pct.1`), every other
  path writes them into the network config. The name's DNS records
  follow the record set `rules/dns.md` → The proposal gives, shown
  in the plan below: After creation writes it where the name
  space's line allows `write`, and otherwise it is the user's to
  add, said when the name does not resolve to the address yet.
- **Resources:** vCPUs, memory, disk size, storage, bridge.
  Defaults: 2 vCPUs, 2 GiB, 20 GiB for a VM and 8 GiB for a
  container, the storage and bridge the host's other guests use.
- **Starts with the host:** yes by default.
- **Admin keys:** where no override fills the baseline's Admin
  Keys, ask which public key to use, offering the `~/.ssh/*.pub`
  files of the workstation and the keys `ssh-add -L` lists (an
  agent such as 1Password's keeps no file), and suggest recording
  it there. A user without a key who asks for a password gets one
  as `references/user-data.md` → Passwords says.

A static address must be free: no `IP:` line in memory and no
entry in `guests.md` has it, and from the host neither
`ping -c 2 -W 1 <address>` answers nor `ip neigh show <address>`
afterwards shows a MAC (`lladdr`); a `FAILED` or `INCOMPLETE`
entry means nothing answered.

The settled name must not already belong to another machine, as
far as the same direct lookup can tell: resolve it directly, the
same system-resolver lookup step 6 below uses (`rules/dns-aliases.md`
→ Detection step 1) — every address it collects, IPv4 and IPv6
alike — never `ssh -G`, which a name with no memory and no block
yet has nothing of its own to answer through. Nothing yet is
normal — the record, if any, is what step 6 below writes once the
guest exists — and so is a static guest's own settled address
already answering there, staged by the user or left by an earlier
attempt at this same name (the Address bullet already expects
this: its DNS record is "the user's to add, said when the name
does not resolve to the address yet"). A DHCP guest has no address
of its own yet to compare against, so any address already returned
there is unexpected. Any other address means the name belongs to
someone else, the way `rules/host-rename.md` → The New Name →
Where it points treats it for an existing host: stop and tell the
user rather than go on to create a guest under a name another
machine already answers to. A resolver-unreachable result
(`rules/dns-aliases.md` → Detection step 1) gets the same stop:
tell the user rather than take an unreachable resolver for a free
name. After creation step 2 repeats this same
lookup once the guest itself exists, as a backstop for a name
claimed in the gap between this plan and the guest's actual first
boot.

Say in one line each what is tight: memory against what running
guests already hold, free space on the storage, CPUs. Creating the
guest anyway is the user's call.

Where the guest's ports are reached through the host — a NAT
network, an Incus proxy device — `rules/port-check.md` and
`rules/firewall-changes.md` apply to the host. A bridged guest
with its own address touches neither.

Show the plan in one block, and ask once: host, kind, image with
its checksum source, name, ID, address, resources, the baseline
version, and the DNS record set. Creating a guest is a change on the host
(`rules/system-containers.md` → Changes).


## The baseline

Render it as `references/user-data.md` says before the guest is
created. The reference names what each platform reads it from.

This is the guest's first-boot configuration, the one place
`AGENTS.md` → Critical Safety Rules lets Hostwarden set sshd's
login options and keys. It is the only place: the boundary is the
guest, not the format. A guest that has already started is a
server, and every rule for a server applies to it.

Which form it takes follows from what the guest reads at its
first boot, not from the hypervisor; the references are all under
`references/`:

| The guest reads          | From                     | Reference             |
| ------------------------ | ------------------------ | --------------------- |
| user-data from the host  | a cloud image            | `user-data.md`        |
| a seed in its filesystem | the container template   | `proxmox-template.md` |
| a seed in its filesystem | the LXC download image   | `lxc.md`              |
| a seed in its filesystem | a prepared disk image    | `image-prep.md`       |
| an Ignition config       | Fedora CoreOS, Flatcar   | `ignition.md`         |
| an installer's answers   | an installer ISO or tree | `answer-files.md`     |

All but Ignition carry the one rendered cloud-init file, handed
over or seeded; Fedora CoreOS and Flatcar run no cloud-init and
get a rendering of their own. Either way one version is recorded
in the guest's memory.

Hostwarden writes sshd's configuration and keys through the
mechanism the guest itself reads, never from outside into a
mounted image or an unstarted container's root filesystem. Where a
guest has no such mechanism, the files are the user's to place
(`references/image-prep.md` → Where this path ends).

## After creation

1. **Wait for the first boot** in one call on the host, as the
   reference shows: a loop there, not an SSH retry
   (`rules/ssh-unreachable.md`). What that call waits for is the
   form's own signal — cloud-init reporting done, the guest agent
   answering after an install, and for Ignition, which has neither,
   a fixed wait before the first login. Never a loop on the SSH
   port, which fail2ban and sshd's `PerSourcePenalties` count.
   Where the manager can enter the guest — `pct exec`,
   `qm guest exec`, `incus exec` — the same call waits for
   `cloud-init status --wait --long`, reads the public host key,
   and, where the address is DHCP, the guest's own
   (`ip -4 addr show scope global`, run inside it through the same
   exec channel); read-only, and only on the guest this run
   created. A call that ends before the signal — out of time, or
   cut by the reboot `package_reboot_if_required` may cause — is
   run once more, then reported.
2. **Bridge the name.** The guest's actual address — the one The
   request settled for a static guest, the one step 1 just read
   for a DHCP guest the manager can enter, or, for a DHCP guest
   under libvirt, `virsh domifaddr <domain> --source agent`, once
   the same wait confirms the guest agent answers — is looked up
   against the blacklist and the read-only list before anything
   else touches it: the same lookup as for any other target
   (`rules/access-control.md` → Shared Lookup Logic). A match on
   the blacklist refuses the guest outright
   (`rules/access-control.md` → Server Blacklist): the bridge is
   never written and the guest is never logged into. A match on
   the read-only list means the address belongs to another host,
   not that inspection is now restricted, the same reasoning Hosts
   that keep guests to their UI further below gives for its own two
   sources — stop and tell the user rather than bridge to it.
   Cleared of both, it still has no DNS
   record for the settled FQDN yet to resolve by (step 6 below
   writes one where the name space allows it). Resolve the settled
   name directly again, as far as the same lookup can tell — the
   same system-resolver tools step 6 below uses, as the backstop
   The request's own check promised: the name could have been
   claimed by something else in the gap since then. An address the
   guest itself already has is normal — DHCP with
   dynamic DNS registration can beat this step to it — and that
   covers a family step 1 above did not check for, such as a
   SLAAC address on a dual-stack network: where the manager can
   enter the guest, read the other family the same way step 1 read
   the first, `ip -6 addr show scope global` beside its `ip -4`; a
   DHCP guest under libvirt already has every family
   `virsh domifaddr <domain> --source agent` reported, not only
   the one used above. Only an address in neither is claimed in
   that gap: stop and tell the user as The request's own check
   would have, rather than let this block silently redirect every
   session that shares `memory/ssh_hosts` to the new guest instead.
   A resolver-unreachable result gets the same stop, for the same
   reason The request's own check does not take one for nothing
   yet. This address is Hostwarden's own, never the user's: gate
   writing it as `rules/ssh-config.md` → A Self-Resolved Address
   says. `same everywhere` adds a
   `Host <settled name>` block to `memory/ssh_hosts` with
   `HostName <that address>` and `HostKeyAlias <settled name>`
   (`rules/ssh-config.md` → Adding a Block, steps 1-3), so every
   connection from here on reaches the guest, and looks its key up,
   by the settled name rather than the address
   (`rules/host-keys.md` → Before the First Connection) —
   `rules/ssh-config.md` → Adding a Block step 5 already expects a
   block for "a host with no memory yet," committed together with
   the memory directory `rules/first-connection.md` step 6 creates
   below. `memory/ssh_hosts` is shared in a shared workspace
   (`rules/ssh-config.md` → The Files), so this overrides the name
   for every session that shares it, not only this one, same as any
   other block written there for a host with no DNS of its own
   (`rules/host-rename.md` → The Order step 1). It is a bridge, not
   meant to last: step 6 further below
   removes it once DNS takes over, restoring IP Verification's
   drift check (`rules/dns-aliases.md`) for it. Until then — DNS
   not live yet, not resolving where the workstation checks, or
   the user's own step to begin with — it works exactly like a
   permanent override, that check included, for as long as nobody
   revisits it. `only this workstation` or `not sure` skips that
   write instead: every step below that still connects to the guest
   does so with
   `-o HostName=<that address> -o HostKeyAlias=<settled name>` on
   every call of its own, the gate's own same-session fallback,
   in place of the block — this run's own resolution, gone once it
   ends, so the report says plainly that no other session, and no
   later connection of this one either, reaches the guest by the
   settled name until DNS does. Step 6 further below has no block to
   remove in that case and skips that part of it.
3. **The first login,** by the settled name — through the block, or
   through the same-run `-o` pair where step 2 used that instead —
   never by the bare address. Record the guest's host key in
   `memory/known_hosts` (`rules/host-keys.md` → Getting a Key,
   source 1), with a read of its own into the cache file, never
   copied from the output above, then log in as usual. Where the
   manager cannot read the key — libvirt, a Proxmox VE Ignition
   guest (`references/proxmox.md` → A VM that reads Ignition, no
   guest agent to read it through), or a host that keeps guests to
   its UI (below) — the first login records it instead,
   the way source 3 there says for a guest this run created with
   no session inside it to read the key through. Only where the
   guest has no cloud-init at all — Ignition (Fedora CoreOS,
   Flatcar), or a UI-guest install with no second ISO at all — does
   it skip the wait for it below: the guest already answering SSH
   is the only signal there is. Every other path, an answer-file
   install included, hands its baseline to cloud-init for the first
   boot after install rather than carrying it itself
   (`references/answer-files.md` → What the answer file does), so
   it waits for cloud-init over SSH the same way:
   `cloud-init status --wait --long` exits 0 when done, 2 when it
   finished with errors it recovered from — a finding to report
   line by line — and 1 when it failed: report that, leave the
   guest as it is, and ask.
4. **The pipeline on the guest** (`rules/first-connection.md`),
   which creates `memory/machines/<settled name>/` directly. Where
   step 2 used the same-run `-o` pair instead of a block, that pair
   rides on every one of the pipeline's own SSH calls to this guest,
   on top of whatever options each of its steps already names — the
   pipeline's own files know nothing of a per-run override, so
   nothing but this run supplies it, at each call site in turn. The
   SSH user is the one the user-data created: write its per-machine
   entry in `memory/user.md` instead of asking (`rules/ssh-user.md`).
5. **Register it.** Run the host's inventory for the new guest
   (`rules/hypervisors.md` → Inventory): its entry goes into
   `guests.md` with `→ <directory>`, and its keys into the guest's
   `Guest identity:`, with `Runs on:` as Linking Guest and Host
   says there. The guest's memory also gets
   `- Origin: cloud image (Debian 13 genericcloud)` or
   `- Origin: <pveam template>`, and `- Baseline:` as
   `rules/baseline.md` → Rendered Versions says. A password the
   user asked for is a decision in the guest's `decisions.md`
   (`rules/decisions.md`): `## Password login`, with the user's
   reason, settling `baseline → SSH Login` for password login, and
   for SSH with it too where they asked for that.
6. **The DNS record set**, where a name space it belongs to has a
   `memory/dns.md` line reading `Hostwarden: write`: written as
   `rules/dns.md` → Writing says, the set the question already
   showed. In any other name space this is the user's step instead,
   and the report says so, as it does when no name space covers the
   name at all — the user may already have added it, before or
   during this run. Either way, check whether the settled name
   already resolves to the guest's address and nothing else: the
   workstation's own system resolver, asked directly for every
   address it collects, IPv4 and IPv6 alike — `getent ahostsv4`
   and `ahostsv6`, `dscacheutil -q host -a name`, or `getaddrinfo`,
   the lookup `rules/dns-aliases.md` → Detection step 1 makes once
   it already has a name to resolve, never `ssh -G`, which a block
   step 2 may still have left would answer with its own override
   rather than a real lookup. This is not the overlap
   `rules/dns-aliases.md` → IP Verification accepts, which
   recognizes an already-known multi-homed host rather than
   checking a name against every other address it could still be
   claimed by. A name space that still carries a second, unrelated
   record for the settled name would pass an overlap check, and a
   later plain connection by that name is not guaranteed to land on
   the guest's address rather than the other one — the guest's host
   key was only ever recorded under the bridge's own address, so
   that connection would fail host-key verification. Requiring
   every resolved address to be the guest's own, rather than merely
   one of them, closes that gap as far as the same direct lookup
   reaches — "the guest's own" meaning both families step 2's own
   check reads them as, a SLAAC address on a dual-stack network
   included, not only the one address the bridge targets. Where it
   holds — Writing → Verify confirming it too,
   where Hostwarden wrote the record — remove step 2's `Host` block
   from `memory/ssh_hosts` and rerun `bin/hostwarden-ssh-config`, so
   a later address change is caught again (`rules/dns-aliases.md` →
   IP Verification) instead of silently masked. Otherwise — nothing
   resolves yet, a resolver-unreachable result, or an address
   besides the guest's own is among the results — leave an item in
   the guest's `todo.md`
   (`rules/machine-memory.md` → Session to-do list) to repeat that
   same direct resolver check later, and, only where step 2 wrote a
   block, remove it once the check passes.
7. **Verify the baseline** on the guest as `hostwarden-baseline`
   step 2 measures it: the check each section of
   `rules/baseline.md` names, in as few bundled calls as they
   allow. The backup is looked up from the host instead: on
   Proxmox VE a job in `/etc/pve/jobs.cfg` with `all 1` or this
   guest's ID, elsewhere the hypervisor's own backup schedule or
   the guest's as
   `.agents/skills/hostwarden-housekeeping/references/backup-presence.md`
   finds it. A section the guest misses is a finding of this run;
   for a missing backup, ask whether to add the guest to a job.
   Where a host CA of the user's covers the guest, the public keys
   of the host keys its sshd loads go to the user to sign; where
   it trusts a user CA with a revocation list, the user hears that
   the guest must now be among the hosts their revocations reach
   (`rules/ssh-ca.md` → Using the CA Everywhere). The probes of
   `hostwarden-onboard` step 5 run in the same calls, their
   questions are asked with this step's, and the guest gets
   `Onboarded:` as that skill's step 6 writes it.
8. **Log** on both, as `rules/changelog.md` says: the host's
   journal line names the guest created, the guest's names the
   baseline version.

A guest that fails is never deleted on Hostwarden's own account,
and never rescued by writing a password or a key into it. Where
the manager can enter it, read `cloud-init status --long` and the
fingerprints of the SSH user's keys (`rules/secrets.md`) to find
out why, and report. Fix the rendered file and create the guest
again once the user has asked for the failed one to be removed
(`rules/system-containers.md` → Changes).

## Hosts that keep guests to their UI

Unraid, ZimaOS and TrueNAS create guests in their web UI, none of
which has a field for user-data. XCP-ng's is Xen Orchestra's: its
VM creation takes a custom cloud-init configuration
(<https://docs.xen-orchestra.com/manage-your-infrastructure/vm-templates>).

Give the user the steps as one list: the image with its checksum
(`references/images.md`) as the VM's disk, name, resources,
network, and the rendered user-data — on XCP-ng to paste, on the
others as a seed ISO attached as a second CD drive
(`references/seed-iso.md`). Where the UI cannot
import a disk image, the distribution's installer takes its answer
file from a second ISO instead
(`references/answer-files.md` → A host whose UI owns the guests),
and the guest still comes up on the baseline. Only a UI that can
attach no second ISO at all leaves the installer's own questions
and a password the user types: say so, and go on only if the user
wants that. The address is static as planned, or DHCP as the user
reports it, since this run has no session inside the guest to read
it from itself. The guest answering SSH is not proof by itself:
every admin guest can share one key (Admin keys above), so it only
proves the address accepts the key, not that it is this guest.
Check a reported address first, the same way a static one is
checked before creation (The request above): no `IP:` line in
memory and no entry in any `guests.md` already names it, and it is
not on the blacklist (`rules/access-control.md` → Server
Blacklist) — a match refuses the connection outright, never asking
for an override, the same as any other target. A match on the
read-only list is not that: `rules/access-control.md`'s read-only
mode is for a target the user named on purpose, not this — it
means the address belongs to another machine instead, the same as
a memory match below. The guest's own MAC is usually known too —
libvirt picks one at
creation (`references/libvirt.md` → Creating it), Proxmox VE's own
`grep '^net0:' /etc/pve/qemu-server/<vmid>.conf` names whatever it
auto-picked, and a UI's own host has the same read its appliance
file already uses for Inventory, where that file records one for
this guest — a TrueNAS `virt.instance` can come back `mac unknown`
(`rules/appliance/truenas.md` → Virtual Machines and Containers) —
never the user's own reading of the page the address came from,
which only catches a typo between the two fields, not a wrong page
throughout. Where it is known, check it too: `ping -c 2 -W 1
<address>` then `ip neigh show <address>` for the `lladdr`.
`REACHABLE`, `STALE`, `DELAY`, `PROBE`, `PERMANENT` or `NOARP` is a
known MAC there, the same split rules/network-probe.md's own
`gw4`/`gw6` neighbor read already makes; `FAILED`,
`INCOMPLETE`, no `lladdr` or an empty entry is not — that confirms
nothing either way, on a routed subnet or any host whose ARP or ND
cache never populates for that address, and is never read as a
match with nothing to mismatch against. A known MAC that is not the
guest's own counts the same as a memory or read-only-list match:
stop and ask the user to recheck the address rather than trust it.
Nothing to check
it against — no MAC known, or nothing back from `ip neigh` — leaves
only the memory check above, so say so once it matters: the address
is unverified beyond it, not confirmed. Once it is clear, go on at
After
creation step 2 with it, so the guest still ends up reached and
known by its settled name rather than that address.

## References

- `references/user-data.md` — the baseline as cloud-init
  user-data: what it carries, how it is rendered and checked,
  and a password on request.
- `references/images.md` — each distribution's cloud image, and
  how its checksum and signature are verified.
- `references/proxmox.md` — Proxmox VE: VMs from a cloud image
  and containers from the baseline template.
- `references/proxmox-template.md` — building that template.
- `references/libvirt.md` — libvirt with `virt-install`.
- `references/incus.md` — Incus and LXD, and the baseline as a
  profile.
- `references/lxc.md` — classic LXC with `lxc-create`.
- `references/ignition.md` — Fedora CoreOS and Flatcar: the
  baseline as Butane, transpiled to Ignition.
- `references/answer-files.md` — kickstart, preseed, autoinstall
  and AutoYaST, for a guest that has to be installed.
- `references/image-prep.md` — changing a disk image before the
  guest's first boot.
