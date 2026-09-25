# Server Memory

Each server: `memory/servers/<hostname>/` with
`memory.md`, `changelog.log`, optionally `todo.md`,
optionally `rules.md` (per-server rule
overrides — see `rules/overrides.md`), optionally
`decisions.md` (the user's decisions about it —
see `rules/decisions.md`), on a
hypervisor `guests.md`, its guest inventory
(`rules/hypervisors.md`), and on bare metal or a
host with ZFS pools or btrfs `storage.md`, its disks
and their settings (`rules/storage-inventory.md`). A
host taken over from Heinzel has `heinzel-memory.md`
until its first connection and `heinzel-inventory.md`
until its leads are checked
(`rules/heinzel-takeover.md`).
A hypervisor cluster or pool keeps its members, state
and guest inventory in `memory/clusters/<name>/`
instead (`rules/hypervisors.md` → Clusters and Pools).
A host may also have `files/`, `src/`, `deployed.md`
and `notes/` (below).

Two guests can carry the same hostname: the same instance name
in two Incus or LXD projects, or a VM cloned and never renamed.
The second one's directory then takes what tells them apart,
lowercase — the hypervisor host and the project or ID,
`web-incus1-prod`, `web-pve1-105` — while the first keeps the plain
name. Its `Runs on:` line says which guest it is, the
project included: `- Runs on: incus1.example.com (container
prod/web)` (`rules/hypervisors.md` → Linking Guest and Host).
Without that, the second guest's onboarding writes over the
first one's memory and a later session acts on the wrong
server.

On WSL the directory is
`<windows-hostname>-wsl-<distribution>`, lowercase:
every distribution on one Windows machine carries
the same hostname.

- **The Windows hostname** comes from the Windows
  side, `hostname.exe` through interop
  (`rules/platform/wsl.md` → Windows programs), never from
  the Linux `hostname`, which `/etc/wsl.conf` can
  change. Where interop is off, ask the user.
- **The distribution** is the `WSL_DISTRO_NAME` line
  under `@platform` (`rules/first-detection.md`). Where
  that line is empty, as it often is over SSH, ask the
  user for the name `wsl.exe -l -v` shows; never take
  the os-release `ID`, which can differ from it.

Its `memory.md` records how the instance is reached:
`- Reached as: <ssh destination>`. That destination, not
the directory name, is the host's key in `memory/user.md`
and the target of the SSH call.

A WSL instance is found by the Windows hostname and
the port. When the user names a machine and memory
holds `<that-hostname>-wsl-*` directories, the one
whose `SSH port:` matches the
connection is its memory; none matching is a new
instance. In local mode, `WSL_DISTRO_NAME` picks the
directory, and where it is empty, ask which.

**On first connection:** create directory and
`memory.md` with at least:

```markdown
# hostname.example.com
- IP: 203.0.113.10
- SSH port: 22
- OS: Debian 13 (Trixie)
- Distro family: debian
- Appliance: Proxmox VE 9.0.3, standalone
- Role: server (inferred)
- Shell: bash (root)
- CPU: 4x Intel Xeon E-2236 @ 3.40GHz
- Arch: x86_64, Intel
- RAM: 16 GB
- Disk: 80 GB (/ ext4, 45% used)
- Virtualization: none (bare metal)
- Last connected: 2026-02-25
```

A field a probe could not read is written `unknown`, never
filled from an example. `- FQDN: hostname.example.com` comes
only from its probe (`rules/dns-aliases.md` → The FQDN), never
from the directory name and never as a placeholder: a first
connection writes the file without it, and the activity
check's call right after adds it; a guest's registration
writes what its own call read (`rules/hypervisors.md` →
Registering Guests).

`Mode: local` marks the local machine. `Mode: via` marks a
guest that has no sshd of its own and is reached through its
host's manager (`rules/first-connection.md` → Via-host mode).
The line holds the mode and nothing else: the host and the ID
are the ones `Runs on:` names, and the command is that
manager's line in `rules/system-containers.md` → Reaching It,
so a guest that moves or leaves its host changes its `Runs on:`
alone. A guest whose SSH merely timed out never gets the line:
via-host mode is then this session's only, and the line would
route every later session through the host.

`SSH port:`, remote mode only, is the `port` line of
`ssh -G <user>@<hostname>` with the standard options
(`AGENTS.md` → SSH Options), which the alias check in
`rules/dns-aliases.md` compares. It is written again when the
user confirms that the host's sshd moved
(`rules/ssh-config.md` → Adding a Block).

**Update memory immediately after any system
change.** Keep it compact (~30 lines max). Remove
outdated entries, merge related items. A change to a
ZFS or btrfs setting, a mount option or an ARC limit
updates `storage.md` in the same step.

**Update `Last connected:` on every connection.**

Memory files never hold credential values — see
`rules/secrets.md`.

## Who writes which line

Each line has one owner, which gives its wording and says when
it changes; every other rule and skill only reads it, except that
`hostwarden-onboard` runs the owner's probe and writes the line as
the owner gives it, and a line's own section may name one further
mover for a narrow case — the activity check moving the timestamp
and duration in `Auto restarts:` is one
(`rules/maintenance-windows.md` → Automatic restarts), never its
other half. A line joins when its moment comes, never
before, and most hosts never get most of them. An owner ending in
`.md` is a file under `rules/`; the others are skills. An OS file whose Version
Detection names further fields to record owns those. The
`guests.md` and `cluster.md` of a hypervisor keep lines of their
own, `Inventoried:` among them (`rules/hypervisors.md`), and
so does a host's `network.md` (`rules/network.md`).

| Field                    | Owner                       | Written          |
|--------------------------|-----------------------------|------------------|
| `IP:`                    | `dns-aliases.md`            | first connection |
| `Resolved via:`          | `mdns.md`                   | `.local` name    |
| `FQDN:`                  | `dns-aliases.md`            | activity check   |
| `SSH port:`              | this file                   | first, on a move |
| `Reached as:`            | this file                   | first connection |
| `Mode:`                  | this file                   | mode chosen      |
| `Last connected:`        | this file                   | every connection |
| `OS:`, `Distro family:`  | `os-detection.md`           | every connection |
| `Appliance:`             | `first-detection.md`        | first connection |
| `Platform:`, `Role:`     | `first-detection.md`        | first connection |
| `Shell:`, `CPU:`         | `first-detection.md`        | first connection |
| `Arch:`, `RAM:`, `Disk:` | `first-detection.md`        | first connection |
| `Virtualization:`        | `first-detection.md`        | first connection |
| `Hypervisor:`            | `first-detection.md`        | first connection |
| `Storage:`               | `storage-inventory.md`      | inventory taken  |
| `Installation:`          | `os/windows.md`             | first connection |
| `PowerShell:`, `Admin:`  | `os/windows.md`             | first connection |
| `Full disk access:`      | `os/macos.md`               | first connection |
| `Model:`                 | the appliance file          | first connection |
| `SSH server:`            | `appliance/unifi-os.md`     | first connection |
| `Boot scripts:`          | `appliance/unifi-os.md`     | first connection |
| `API key reads:`         | `appliance/unifi-os.md`     | user's answer    |
| `Journal:`, `API port:`  | `appliance/synology-dsm.md` | first use        |
| `Sudo:`, `Root SSH:`     | `privilege-escalation.md`   | privileged use   |
| `Privilege mode:`        | `privilege-escalation.md`   | privileged use   |
| `Root-equivalent group:` | `privilege-escalation.md`   | group found      |
| `Accounts:`              | `accounts.md`               | accounts probed  |
| `Doas:`                  | `os/alpine.md`              | privileged use   |
| `WSL root:`              | `platform/wsl.md`           | privileged use   |
| `Management:`            | `management-controller.md`  | first need       |
| `DNS alias:`             | `dns-aliases.md`            | alias confirmed  |
| `SSH host cert:`         | `ssh-ca.md`                 | cert found       |
| `SSH user CA:`           | `ssh-ca.md`                 | CA trust found   |
| `SSH client host CA:`    | `ssh-ca.md`                 | CA line found    |
| `heinzel legacy:`        | `heinzel-takeover.md`       | legacy settled   |
| `Other ways in:`         | `heinzel-takeover.md`       | host taken over  |
| `Planned:`               | `heinzel-takeover.md`       | host taken over  |
| `Config management:`     | `config-management-leads.md`| tool found       |
| `Provisioned by:`        | `config-management-leads.md`| tool found       |
| `Web server:`            | `service-class-check.md`    | service found    |
| `Database:`, `MTA:`      | `service-class-check.md`    | service found    |
| `Time sync:`             | `service-class-check.md`    | service found    |
| `DNS resolver:`          | `service-class-check.md`    | service found    |
| `DNS server:`            | `dns.md`                    | name spaces read |
| `Firewall manager:`      | `service-class-check.md`    | service found    |
| `Upstream firewall:`     | `baseline.md`               | user's answer    |
| `Container runtime:`     | `service-class-check.md`    | runtime found    |
| `Container: privileged`  | `system-containers.md`      | container found  |
| `Cluster:`               | `hypervisors.md`            | member found     |
| `Runs on:`               | `hypervisors.md`            | guest linked     |
| `Guest identity:`        | `hypervisors.md`            | guest linked     |
| `Depends on:`            | `coordination.md`           | found, or told   |
| `SSH: untested`          | `hypervisors.md`            | guest registered |
| `Baseline:`              | `baseline.md`               | baseline applied |
| `Baseline template:`     | `appliance/proxmox-ve.md`   | template built   |
| `Baseline check:`        | `baseline.md`               | baseline measured|
| `Network:`               | `network.md`                | first connection |
| `Site:`                  | `network-topology.md`       | user's answer    |
| `Dynamic routing:`       | `network-topology.md`       | daemon found     |
| `Access:`                | `ssh-safety-net.md`         | paths tested     |
| `Access:` (agent SSH)    | `mesh-vpn.md`               | activity check   |
| `API read:`              | `appliance-api.md`          | access set up    |
| `API write:`             | `appliance-api.md`          | access set up    |
| `API path:`              | `appliance-api.md`          | access set up    |
| `API pin:`               | `tls-pinning.md`            | pin confirmed    |
| `Flags:`, `Rollback:`    | `changelog.md`              | entry logged     |
| `Plan:`                  | this file                   | plan started     |
| `Downtime notice:`       | `maintenance-windows.md`    | user's answer    |
| `Downtime:`              | `maintenance-windows.md`    | window planned   |
| `Auto restarts:`         | `hostwarden-housekeeping`   | onboarding       |
| `USB:`, `Passthrough:`   | `hostwarden-housekeeping`   | onboarding       |
| `Backup:`                | `hostwarden-housekeeping`   | onboarding       |
| `Container registries:`  | `hostwarden-security`       | user's answer    |
| `Onboarded:`             | `hostwarden-onboard`        | onboarded        |
| `Housekeeping:`          | `hostwarden-housekeeping`   | housekeeping     |
| `Deploy user:`           | `hostwarden-deploy-user`    | account set up   |
| `Deploy target:`         | `hostwarden-deploy-user`    | account set up   |
| `Deploy sudo:`           | `hostwarden-deploy-user`    | account set up   |
| `Fleet read:`            | `hostwarden-fleet-read`     | set up, checked  |
| `Origin:`                | `hostwarden-new-guest`      | guest created    |
| `Origin:`                | `hostwarden-os-install`     | OS installed     |
| `Device:`                | `hostwarden-os-install`     | before a write   |
| `Mail:`, `Alert email:`  | `hostwarden-email`          | first email      |
| `Email source:`          | `hostwarden-email`          | user's answer    |
| `Email sender:`          | `hostwarden-email`          | first email      |
| `Email send policy:`     | `hostwarden-email`          | user's answer    |
| `MTA install policy:`    | `hostwarden-email`          | user's answer    |
| `Operator name:`         | `hostwarden-email`          | user's answer    |
| `Greeting:`, `From:`     | `hostwarden-email`          | user's answer    |
| `Reply-To:`              | `hostwarden-email`          | user's answer    |

`Flags:` and `Rollback:` lines stand last in the file, one per
changelog entry they come from (`rules/changelog.md` → Standing
lines). An `Access:` line reads:

```markdown
- Access: via Tailscale (web1.tail1234.ts.net); direct
  203.0.113.10 timeout (2026-09-19)
```

### Onboarded and stale lines

`- Onboarded: 2026-09-24` says `hostwarden-onboard` steps 3 to 5
ran through the host's own way in: SSH, local mode, or through its
host for a `Mode: via` guest. A full re-probe through onboarding
moves the date. A guest only registered through its hypervisor has
`SSH: untested` instead, until its first own login
(`rules/first-connection.md` step 9).

Housekeeping refreshes `USB:`, `Passthrough:`, `Storage:` with
`storage.md`, the entries of `Depends on:` it detects, `Backup:`
and, on Linux, `Auto restarts:`. Such a line is stale once it is
older
than 90 days: its age is the later of `Onboarded:` and
`Housekeeping:`, which housekeeping writes as its step 6 says, or
the line's own date where it carries one, such as
`Backup: restic to backup1.example.com, verified 2026-06-10`,
whose date housekeeping moves on each check that finds the backup
ran. A `Backup:` line that records the user's answer
(`confirmed <date>`) is never stale: it is asked again after 180
days, as
`.agents/skills/hostwarden-housekeeping/references/backup-presence.md`
says. The fleet audit refreshes no line. An answer or a report
that rests on a stale line says so, with its age and the run that
refreshes it: `USB: recorded 140 days ago — housekeeping
refreshes it`.

## Session to-do list

For a session of two steps or more, create
`memory/servers/<hostname>/todo.md`. Mark a task
`[x]` the moment it is done, not at the end — a
session that is interrupted has to leave behind
what was actually finished. On reconnection, show
the pending items before starting new work; an item
with a `due` time waits silently until then. Delete
the file once everything is done.

## Plans that outlive a session

Work that spans sessions — a migration in phases, a
rollout across sites, a design with decisions still
open — gets `memory/plans/<slug>.md`, whether it
touches one host or many. `todo.md` stays what it is:
one session's steps, deleted when they are done. A
plan holds what a checklist cannot: the goal, the
decisions taken and why, the phases, and what is next.
It opens with the hosts it touches and where it
stands:

```markdown
# Syslog collector for all sites
- Hosts: log1.example.com, fw1.example.com,
  pve1.example.com
- Status: phase 2 of 4 — collector runs, forwarders
  pending
- Updated: 2026-09-17
```

Each host it names gets a line in `memory.md`:
`- Plan: syslog-collector (memory/plans/syslog-collector.md)`.
Read the plan when the work on a host touches what it
plans, and never start its next phase unasked. Update
`Status:` and `Updated:` whenever a phase moves.

A planned maintenance window is a plan of this kind, with a
`Window:`, `Kind:`, `Affected:`, `Notify by:` and `Notice:` line of
its own above the steps, and a `Downtime:` line on each affected
host beside `Plan:` (`rules/maintenance-windows.md` → The window
plan).

Once the plan is done, its facts go into the hosts'
`memory.md`, a decision of the user's that still
binds becomes a decision (`rules/decisions.md` →
Writing one), and the plan and its `Plan:` lines —
and a window's `Downtime:` lines with them — are
deleted.

## Deployed files

A file a session wrote onto a host as a whole keeps
its master in the workspace, beside the memory it
belongs to:

```
memory/servers/<host>/files/<path on the host>
memory/servers/<host>/src/<name>/
memory/servers/<host>/deployed.md
memory/fleet/<name>/files/<path on the host>
memory/clusters/<name>/files/<path on the host>
memory/tools/<name>
```

What each holds, the format of `deployed.md` and how a
file is deployed: `rules/deployed-files.md`.

## Notes and evidence

What a session needs to keep but nobody deploys — a
list of files quarantined before a cleanup, an export
of a device inventory, a snapshot of a config for
comparison — goes to
`memory/servers/<host>/notes/`, named with its date:
`smb-leftovers-quarantine-2026-08-27.tsv`. The
changelog entry that produced it names the file. A
note that no entry and no memory line points to any
more is deleted. Secrets never go in a note
(`rules/secrets.md`).

## Cross-server facts

Facts that belong to no single host — a mesh VPN
network, which machine holds the backup target,
which UPS powers which machines — go
in `memory/network.md`, created
on first need. Current facts only; it is a picture
of now, not a history. A choice the user made about
several hosts is a decision instead, under
`memory/decisions/` (`rules/decisions.md`).

Management controller addresses go there too, under
`## Management controllers`
(`rules/management-controller.md` → What to record),
the SSH CAs the hosts trust, under `## SSH CAs`
(`rules/ssh-ca.md` → Memory). The networks the
hosts share — sites, IP ranges, gateways and the
routes between them — go in `memory/topology.md`
instead (`rules/network-topology.md` → The store),
and the fleet's DNS name spaces in `memory/dns.md`
(`rules/dns.md` → The inventory).

## Personal versus shared

`memory/` is the workspace, a git repository of its
own, never part of Hostwarden's. Solo use is the
default: it has no remote. A **shared workspace** has
a private one — a team's, or one person's on several
machines — and then the split matters.

**Always personal, never shared:** `memory/user.md`
(SSH usernames, language, operator handle),
`memory/blacklist.md`, `memory/readonly.md`,
`memory/ssh_config`, which `bin/hostwarden-ssh-config`
writes for each machine, and the memory directory of
anyone's local machine. The workspace's own
`.gitignore` names them; a machine's hostname
directory has to be added there by hand.

**Shared in a shared workspace:** everything else —
`memory/servers/*/` with each host's `rules.md`,
its masters and `decisions.md`, `memory/clusters/*/`,
`memory/decisions/`, `memory/fleet/`, `memory/tools/`,
`memory/plans/`, `memory/known_hosts`
(`rules/host-keys.md`), `memory/ssh_hosts`
(`rules/ssh-config.md`), `memory/operators.md` (the
handles in use, `rules/session-start.md`),
`memory/network.md`, `memory/topology.md`, `memory/dns.md`,
`memory/housekeeping.md`,
`memory/service-policy.md`, `memory/naming.md`
(`rules/naming-scheme.md`) and `memory/custom-rules/`.

When another machine's session shows up in the activity
check (`rules/activity-check.md`), their memory
edits may not be pulled into the workspace yet. Trust
the host over the file.
