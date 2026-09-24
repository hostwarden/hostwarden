# Features

What Hostwarden does, with example prompts. A feature
that exists only in Claude Code says so; in other
tools the same rules reach the agent as instructions.
The safety rules behind all of it are in
[Safety and guardrails](safety.md); teams, updates and
the operations host in
[Running Hostwarden in production](operations.md).

- [Getting to know a host](#getting-to-know-a-host)
  - [Auto OS-detection](#auto-os-detection)
  - [Onboarding a host](#onboarding-a-host)
  - [DNS aliases and short names](#dns-aliases-and-short-names)
  - [Memory across sessions](#memory-across-sessions)
  - [Recent activity](#recent-activity)
  - [Session to-do list](#session-to-do-list)
  - [A host's network](#a-hosts-network)
  - [Out-of-band access](#out-of-band-access)
- [SSH access](#ssh-access)
  - [Host keys](#host-keys)
  - [SSH certificates and your CA](#ssh-certificates-and-your-ca)
  - [Reaching a host](#reaching-a-host)
- [Systems it knows](#systems-it-knows)
  - [Appliances](#appliances)
  - [Appliance APIs](#appliance-apis)
  - [WSL and workstations](#wsl-and-workstations)
  - [Windows Server](#windows-server)
  - [Local administration](#local-administration)
- [Reviewing servers](#reviewing-servers)
  - [Server baseline](#server-baseline)
  - [Housekeeping checks](#housekeeping-checks)
  - [Security audit](#security-audit)
  - [Disks, ZFS and btrfs](#disks-zfs-and-btrfs)
  - [Decisions](#decisions)
- [Several servers](#several-servers)
  - [One task on many hosts](#one-task-on-many-hosts)
  - [Fleet audit](#fleet-audit)
  - [Fleet read](#fleet-read)
- [Guests and hypervisors](#guests-and-hypervisors)
  - [Hypervisors and their guests](#hypervisors-and-their-guests)
  - [Clusters](#clusters)
  - [Changing a guest](#changing-a-guest)
  - [New guests](#new-guests)
  - [Installing an operating system](#installing-an-operating-system)
- [Changing a server](#changing-a-server)
  - [Configuration management](#configuration-management)
  - [Services in containers](#services-in-containers)
  - [Accounts](#accounts)
  - [Files Hostwarden deploys](#files-hostwarden-deploys)
  - [Renaming a host](#renaming-a-host)
  - [Language runtimes and deploy users](#language-runtimes-and-deploy-users)
  - [Email reports](#email-reports)
- [Working with others](#working-with-others)
  - [Parallel sessions](#parallel-sessions)
  - [Plan mode](#plan-mode)
  - [Moving over from Heinzel](#moving-over-from-heinzel)

## Getting to know a host

### Auto OS-detection

The first connection detects a Linux, FreeBSD or macOS
host in one SSH call: family and version, architecture,
hardware, virtualization, and the markers of an
appliance, a hypervisor and a platform. The login
shell rides in the same call, with one more on a
busybox host (Alpine, OpenWrt).
The host's memory records them, among them
`Virtualization:` (bare metal, VM or container, and
the cloud provider where the firmware names one) and
`Arch:`. A console menu or a banner in place of a
shell stops the probe; it never answers the menu.
Windows takes a second call, `cmd /c ver`, then
PowerShell; only Windows Server goes on. A
distribution without a family file is named, and
Hostwarden goes on with general best practice.

Later connections send a short version check. A full
probe reports each line that changed, such as a
release upgrade.

### Onboarding a host

That first connection happens whenever a host is first
needed. To have it now, ask for it — "onboard
web1.example.com", "nimm web1 in Hostwarden auf", or
`/hostwarden-onboard web1.example.com` in Claude Code.
Hostwarden probes the host in full, writes its memory,
records its network where it can read it, on a
hypervisor lists and registers the guests, reads the
SSH CA setup, and reports what the host lacks against
the server baseline, or a workstation's expectations
where its role replaces the baseline. It changes
nothing on the server
beyond one read-only line in its journal, and in the
journal of each registered guest that has `logger`.
Then it asks which
gaps to take on first; a read-only host gets a report
of the changes instead. Several hosts at once go
hypervisors first. A host it already knows is probed
in full again, and its memory is brought up to date.

### DNS aliases and short names

When several DNS names point to the same server,
Hostwarden finds out: the name ssh connects to
resolves to the same address, on the same SSH port,
and the host key matches. The first hostname becomes
the canonical name; the others become symlinks that
share its memory. Each alias can have its own SSH
user. The same address on another port is another
machine.

Each host records its `FQDN:`. A name without a dot
that matches several servers brings a question before
anything is reached. A `.local` name is asked of mDNS
and of DNS separately, and a disagreement stops for
you instead of being taken as an alias.

### Memory across sessions

Next week, in a new session:

```
 ❯ Check on web1.example.com.
```

It reads `memory/servers/web1.example.com/memory.md`
(Debian 12, nginx, PostgreSQL), the host's open to-do
items, your decisions for it, and the local changelog.

### Recent activity

Every connection reads the host's journal for the
last seven days of Hostwarden entries — its own and
those of an old Heinzel session — and says how far
back the log reached. Where that is less than a week,
as on hosts that keep their logs in RAM, it names the
date and reads your local changelog for the time
before. Scripts that log under the same tag are told
apart from sessions. The summary also names other
sessions registered on the host and recent Ansible
runs.

### Session to-do list

For any task of two or more steps, Hostwarden keeps
`memory/servers/<hostname>/todo.md` and checks off
each step as it finishes, so an interrupted session
leaves behind what was really done. The next
connection shows the open items before new work, and
the file is deleted once everything is done.

Work that spans sessions — a rollout in phases, a
migration with decisions still open — gets a plan in
`memory/plans/<slug>.md`, and every host it touches
points to it with a `Plan:` line. The next phase never
starts unasked. Once it is done, its facts move into
the hosts' memory, what you decided and still holds
becomes a decision record, and the plan is deleted.

### A host's network

Each host gets a network profile in its memory: who
manages the network configuration, which stack runs,
whether it works, whether DNS agrees, and which way
traffic runs. A host that forwards, bridges guests,
does NAT or policy routing gets a traffic-flow
section, which is read before a NAT or bridge change.
Mesh VPN agents — Tailscale, NetBird, ZeroTier,
Nebula, WireGuard, OpenVPN, cloudflared and others —
are judged one by one: which runs, whether it is
connected, whether its login is about to expire, and
what would cut the host off. Every probe is
read-only. The full profile runs when you ask, on
onboarding, and when a failure points at the network.

### Out-of-band access

Each host records a `Management:` line: the BMC,
Intel AMT or provider console to use when SSH is
gone, or for a guest, the host it runs on.
Housekeeping and the security audit settle it, never
in the middle of an outage. A controller is only ever
read; no user, network, firmware or power setting on
it is changed.

## SSH access

### Host keys

Hostwarden checks every server's SSH host key against
one file in the workspace, `memory/known_hosts`, and
never asks you to log in by hand first. A host that is
not in it gets its key in this order:

1. **Through a host that is already verified.** A
   container or VM reached through its hypervisor
   (`pct exec`, `qm guest exec`, `incus exec`, …) has
   its key read inside. Registering a hypervisor's
   guests records their keys this way, and so does
   creating a new guest where the hypervisor can enter
   it.
2. **From the known_hosts files your own ssh reads**
   (`~/.ssh/known_hosts`, the system-wide
   `/etc/ssh/ssh_known_hosts` and any others your ssh
   configuration names), imported with a note saying
   so. An `@cert-authority` line found there is shown
   to you first.
3. **Otherwise it asks:** accept the key on first use,
   compare it with the fingerprint you read at the
   console, or stop. An override can take the first
   option away.

Every entry starts with a comment line saying when and
how the key was obtained. In a team the file is shared,
so each host's key is accepted once for everyone, and
the workspace's history shows who added it. A host
whose key changed stops every call to it; nothing is
replaced until you say so, and never from your own
known_hosts.

`@cert-authority` lines work in the same file, so SSH
host certificates from your own CA need no per-host
lines.

### SSH certificates and your CA

If you already run an SSH CA — `ssh-keygen` with a
script, step-ca, Vault or OpenBao, Teleport — Hostwarden
audits it and uses it wherever it sets up SSH trust. It
does not build a CA for you, never signs a certificate,
and never touches a CA signing key or the configuration
of an sshd that runs. A CA it finds on a server is only
a finding until you confirm it as yours; only then is it
carried anywhere.

- **Audit:** each host certificate's expiry, names and
  renewal job, and whether sshd presents the
  certificate on disk; which user CA each server
  trusts, its principals and its revocation list, and
  whether that list exists, since a missing one locks
  out every key login. Where it can read them, the
  CA's issuing rules: who gets a certificate, for which
  accounts, for how long. A signing key found on a
  server is a finding.
- **Fleet audit:** which CA and which revocation list
  every server trusts, so a revocation that missed a
  server stands out.
- **Your workstation:** every host with a host
  certificate from your CA is covered by its line in
  `memory/known_hosts`. A missing line is offered;
  another CA for the same name stops the connection.
- **Servers that connect to others** get the host CA's
  line in their global known-hosts file when you say
  yes.
- **New guests** trust your user CA from their first
  boot; a container from the Proxmox VE baseline
  template, which shares the template's setup, gets the
  lines to add instead. Their host keys are handed to
  you to sign; installing the certificate is yours.
- **Baseline:** once you confirm a CA as yours and say
  which servers it covers, a server there that does
  not trust it, has another principals setup than the
  rest, presents no valid host certificate, or has no
  revocation list where the others have one, is a
  finding, and you get the lines to add.

### Reaching a host

Every SSH call passes one file, `memory/ssh_config`,
which Hostwarden writes for your machine at every
session start. Your own `~/.ssh/config` keeps working:
it is read after Hostwarden's settings, for whatever
they leave open, such as a key file or your user name
on a host.

A server that answers on another port, only through a
jump host, or at an address its name does not resolve
to goes into `memory/ssh_hosts`, in ssh_config syntax:

```
Host db1 db1.example.com
  HostName 192.0.2.30
  Port 2222
  ProxyJump jump.example.com
```

Only `Host`, `HostName`, `Port`, `ProxyJump` and
`HostKeyAlias` are accepted, with plain values. In a
team the file is shared, and those five cannot run a
command on a teammate's machine; a file with any other
line or value is left out whole until it is fixed. SSH
usernames stay in `memory/user.md`, which is personal.

Every jump host goes through the blacklist as the
user it logs in as, and gets the same host-key check
and shared connection as the server behind it. A
`ProxyCommand` whose path Hostwarden cannot read is
treated as a listed hop: it asks you, each session,
whether it passes a blacklisted host.

A port you give with the host — `web1.example.com:2222`,
`ssh://alice@web1.example.com:2222` or `-p 2222` —
becomes such a block, unless your own ssh
configuration already has it. A known name on a new
port first brings the question whether sshd moved or
another machine answers there. When port 22 of a new
server refuses the connection, Hostwarden tries the
ports you list as `Alternative SSH ports:` in
`memory/user.md`, and 2222 where your known_hosts has a
key for it, those with a key first, three at most;
then it asks. It never scans for a port, and after a
timeout it tries no other port on its own.

Port forwardings are never stored. A session that
needs one adds it to the shared connection, bound to
`127.0.0.1`, and cancels it when done; a remote
forwarding is asked first.

## Systems it knows

The OS families are listed in the
[README](../README.md#supported-distributions). On top
of a family, three more layers can apply to a host:
an appliance, a platform and a role. Hostwarden
detects each, records it in the host's memory, and
tells you; say so when it is wrong.

### Appliances

An appliance runs its own updater, configuration and
firewall, often on top of an OS family, so it gets a
file of its own that replaces what the family file
would get wrong:

| Appliance         | Base    | Appliance file                      |
| ----------------- | ------- | ----------------------------------- |
| Proxmox VE        | Debian  | `rules/appliance/proxmox-ve.md`     |
| OpenMediaVault    | Debian  | `rules/appliance/openmediavault.md` |
| OPNsense          | FreeBSD | `rules/appliance/opnsense.md`       |
| pfSense           | FreeBSD | `rules/appliance/pfsense.md`        |
| TrueNAS           | Debian  | `rules/appliance/truenas.md`        |
| TrueNAS CORE      | FreeBSD | `rules/appliance/truenas-core.md`   |
| XCP-ng            | RHEL    | `rules/appliance/xcp-ng.md`         |
| Home Assistant OS | —       | `rules/appliance/haos.md`           |
| Synology DSM      | —       | `rules/appliance/synology-dsm.md`   |
| UGREEN UGOS Pro   | —       | `rules/appliance/ugos.md`           |
| UniFi OS          | —       | `rules/appliance/unifi-os.md`       |
| Unraid            | —       | `rules/appliance/unraid.md`         |
| OpenWrt           | —       | `rules/appliance/openwrt.md`        |
| ZimaOS            | —       | `rules/appliance/zimaos.md`         |
| QNAP QTS, hero    | —       | `rules/appliance/qnap.md`           |

Each file says how the appliance updates, where its
settings live — mostly in its web UI or its own tools
— which firewall it runs and where it logs. Where a
file names the releases it covers (Synology DSM,
QNAP, Unraid, UGOS Pro, ZimaOS), Hostwarden stops on
any other release before changing anything; UniFi OS
works read-only there. TrueNAS CORE is covered far
enough to report it as end of life. The fleet audit
compares an appliance only with its own kind. Synology
DSM, QNAP, UGOS Pro and UniFi OS run on their vendor's
hardware, which `hostwarden-os-install` never writes
to.

### Appliance APIs

Unraid, TrueNAS, Synology DSM and UniFi Network are
read through their local APIs, each with its own
read-only account: an Unraid `VIEWER` key, a TrueNAS
Readonly Admin, a DSM user for the VM guest list, a
UniFi View Only user. A write account exists only if
you ask for it, and is used only for a change you
approved. You create each account and fill its
credential file (mode 0600); Hostwarden names the file
and passes it to `curl` on stdin. A call from your
workstation pins the certificate's public key you
confirmed, and an API that answers only on plain HTTP
is refused. Hostwarden never tries a write to prove
that a read-only account cannot write.

### WSL and workstations

A platform is what the OS runs inside when something
outside owns part of the machine. Under
[WSL](../rules/platform/wsl.md), Windows owns the
kernel, the firewall, name resolution and the
instance's lifetime, so Hostwarden reads them and
leaves them alone. It records WSL 1 or 2, the
networking mode and what runs as PID 1, gets root
through `wsl.exe -u root` where interop allows, and
judges the firewall from the Windows side.

A role says what the machine is expected to have. A
Mac, a WSL instance and the machine Hostwarden runs on
are inferred to be
[workstations](../rules/role/workstation.md) and held
to workstation expectations instead of the server
baseline: automatic reboots off, a firewall judged by
what listens, your home directory and your own tools
left to you. A workstation that is offline is skipped,
not reported unreachable.

### Windows Server

Hostwarden reports on Windows Server over OpenSSH.
Every Windows host is read-only: housekeeping and the
security audit run in PowerShell and cover updates,
services, the event log, disks, Defender, BitLocker,
backup, sshd, the firewall profiles, accounts, SMBv1
and Remote Desktop. Updates are reported, never
installed. The two things it changes, each after its
own yes: it installs PowerShell 7 from Microsoft's
package with its checksum checked, and makes it
OpenSSH's default shell under the SSH safety net. A
Windows client is refused and pointed to WSL 2.
Windows hosts get no fleet audit and no fleet read.

### Local administration

Hostwarden also works on the machine it runs on — a
Linux, macOS or FreeBSD workstation, or the WSL
instance on Windows — with no SSH: commands run
directly, as your own user, with sudo where it is
needed and unprivileged mode where it is not
available. The steps that only make sense for a remote
host — access lists, SSH user, DNS and host key — are
skipped; OS detection, memory, the activity check and
the rest of the safety rules apply. A development checkout has no
local mode.

```
 ❯ Update all Homebrew packages on this Mac
```

```
 ❯ Check if the firewall is configured on
   this machine
```

## Reviewing servers

### Server baseline

What every server is expected to have is written down in
one place, `rules/baseline.md`: a firewall that denies
incoming traffic by default and keeps SSH open, automatic
security updates, time sync, SSH by key only and trust
in your SSH CA where you run one, a persistent journal,
storage maintenance on a schedule, the guest agent in a
VM, and a backup. A firewall in front of the host, at
the provider or a router, is recorded and weighed
against the ports that still reach it.

Housekeeping and the security audit measure every
server against it. Ask Hostwarden to bring a server up
to the baseline — `/hostwarden-baseline web1` in
Claude Code — and it lists what is missing and applies
it one asked step at a time. It never changes sshd on
a running server: for SSH it gives you the change to
make.

Your own additions go into
`memory/custom-rules/baseline.md`, as an override
([Overrides](overrides.md)), with sections for admin
keys, the timezone, a mail relay and monitoring:

```markdown
## Add: Admin Keys
- alice: ssh-ed25519 AAAAC3Nza… alice@example.com

## Add: Timezone
Europe/Berlin

## Add: Monitoring
node_exporter from the distribution's package.
```

Public keys only: passwords and tokens never go there.
A `# baseline` block in a host's own `rules.md`
changes it for that host, and a decision can settle a
section a host is meant to go without.

### Housekeeping checks

Run routine health inspections on any server:

```
 ❯ Run housekeeping on app.example.com
```

Problems come first in a short report. What it checks:

- **The basics:** disk, memory and swap (zram and
  zswap included, the ZFS ARC counted as available),
  load, pending updates, the firewall, TLS
  certificates, failed services, the network, log
  anomalies, a kernel waiting for a reboot, a service
  still running an old binary, the timezone and the
  persistent journal.
- **The baseline:** automatic security updates, time
  sync, the SSH host certificate, backups, storage
  maintenance.
- **Hardware:** SMART and `smartd`, USB devices with
  an unwatched UPS flagged, CPU microcode on
  bare-metal x86, and the BMC event log.
- **Services:** container engines (Docker, Podman,
  containerd), mesh VPN agents that are down or whose
  login is about to expire, Home Assistant on an
  ordinary host, Pi-hole, AdGuard Home, CasaOS, and
  the services the host's memory names.
- **Hosts and guests:** the guests of a hypervisor and
  what it passes through to them, the Proxmox VE
  baseline template's age, and files Hostwarden
  deployed that changed on either side.
- **Releases:** an Ubuntu LTS past standard support,
  fixes waiting on Ubuntu Pro.
- **macOS:** failed launchd jobs, kernel panics and
  local Time Machine snapshots.

It covers Linux (Debian, Ubuntu, RHEL, Fedora, SUSE,
Alpine), FreeBSD, macOS and Windows Server. In a
container, clock and kernel findings belong to the
host and are not reported twice. Nothing is updated,
pruned or restarted. Your own checks go into
`memory/housekeeping.md`. A scheduled run can mail you
the report
([Scheduled housekeeping](automation.md#scheduled-housekeeping)).

### Security audit

Check security configuration on any server:

```
 ❯ Run a security audit on app.example.com
```

Findings are reported by severity:

- **SSH:** what sshd really uses (`sshd -G`, a
  daemon's own config file, `Match` blocks), password
  and root login, weak algorithms, host certificates
  and user CA trust; the SSH servers built into VPN
  agents and who they admit; the SSH client on the
  server.
- **Firewall:** posture and IPv6 coverage of every
  firewall, legacy iptables rules counted as one,
  Docker ports published past it, and a firewall in
  front of the host.
- **Accounts:** where accounts and sudo rules come
  from — a role account, a directory such as AD or
  FreeIPA, local files, or an agent — who can become
  root without a password, empty passwords and extra
  UID 0 accounts.
- **Containers:** privileged containers, mounted
  engine sockets and an engine API on TCP.
- **Services:** databases listening on every address,
  open DNS resolvers, exposed admin interfaces.
- **The system:** kernel hardening, file permissions,
  SUID and SGID files, fail2ban, blocklistd or
  sshguard.
- **Management controllers:** IPMI over the network,
  cipher suite 0, factory accounts, Intel AMT.
- **macOS:** SIP, FileVault, Gatekeeper, sharing and
  launchd permissions.
- **Windows Server:** SSH, firewall, accounts, SMBv1,
  Remote Desktop, Defender and BitLocker.

Where accounts come from is recorded in the host's
memory as one `Accounts:` line, next to the
`Management:` line and the SSH CA the audit found.

### Disks, ZFS and btrfs

On bare metal, and in a VM for the disks passed
through to it, housekeeping records each disk once —
type, bus, size, model, serial and firmware — in
`memory/servers/<host>/storage.md`, so a failing disk
is known by the serial you replace it by. It reads
SMART there and on the appliances whose file asks for
it, and says when a disk appears, disappears, or its
error counts grow, and says "not checked" rather than
"healthy" where `smartctl` is missing.

TRIM on flash, RAID array checks, ZFS and btrfs scrubs
and `smartd` are part of the server baseline: what a
distribution schedules by itself differs — Alpine
schedules none, openSUSE only scrubs `/` — so
housekeeping reports what is missing and bringing a
server up to the baseline turns it on. A new VM gets
its TRIM schedule at creation; nothing is set up on an
appliance that schedules this itself.

On a host with ZFS pools or btrfs, it also records the
settings that decide how the storage behaves — layout,
compatibility, dataset and pool properties set by
hand, encryption roots, ARC limits, btrfs profiles and
quotas — rereads them on every run, and rates them:
`sync=disabled` on data that matters, dedup without
the RAM for it, autotrim off on flash, an ARC that
crowds out a hypervisor's guests, and more. A pool
feature `zpool upgrade` would enable is reported, never
enabled, since that step cannot be undone. Tell it why
a setting is the way it is, and it stops asking.

When storage fails, Hostwarden reads, asks about your
backup, and hands the repair command to you: repairing
or destroying a file system, array, volume group or
pool is one of its taboos
([Safety and guardrails](safety.md)).

### Decisions

When you settle a standing choice with a reason — "pve1
never gets a local firewall" — Hostwarden writes it
down with who, when, why and what it covers: one host,
a cluster, or a group of hosts. Audits then show the
matching finding as decided instead of proposing it
again, and flag a host that contradicts it. Only your
explicit word makes a decision, never a pattern
Hostwarden infers; only you retire one, and a
`Revisit:` date brings it up once
([Decisions](overrides.md#decisions)).

## Several servers

### One task on many hosts

Ask one question, run one check or roll out one change on
several servers:

```
 ❯ Which kernel runs on web1, web2 and web3?
 ❯ Run housekeeping on web1 and db1
 ❯ Prüf auf allen Servern, ob nginx läuft
```

Each remote host runs the full first-connection pipeline — blacklist,
read-only list, host key, activity check — and returns a short answer; a
local target skips those remote-only steps. In Claude Code each host
gets its own subagent, elsewhere the hosts run one after another in the
session. Hostwarden prints identical answers once, with the hosts that
gave them, so twenty hosts that agree take one line and the outlier
stands out. A remote host never connected before gets its first
connection in the main session first, since it needs your answers. Hosts
behind one jump host run one after another, a guest reached through its
hypervisor runs in sequence with it, and so do the members of a cluster
in a change.

A change asks once, naming every host and a proposed
canary host; blacklisted, read-only and Windows hosts
are left out. The canary runs alone; only when its
result matches what was expected do the others follow,
in Claude Code all at once apart from hosts that have
to wait their turn. A surprise stops every host that
has not started yet: at the canary, the whole rollout;
later, only the hosts still waiting. Each host the
change reached gets its own journal line and memory.
The rollout is written down as a plan in
`memory/plans/` until every host is done, so a later
session can finish it. A change to the firewall, the
network or a login shell runs one host after another
in the main session instead, each with the SSH safety
net and its own questions. Of the named skills,
housekeeping and the security audit run this way; the
others take one host at a time. `/hostwarden-multi-host`
starts it by name.

### Fleet audit

Compare key policies across every server Hostwarden knows about:

```
 ❯ Run a fleet audit
 ❯ Vergleiche die Policies auf allen Servern
```

Hostwarden probes unattended-upgrades, sshd's
effective config and SSH CA trust, firewall posture,
MTA, the network stack and resolver, time sync,
auto-reboot behaviour and needrestart's restart mode,
mesh VPNs and their SSH servers, accounts and sudo
rules and, on Ubuntu, Pro/ESM coverage on each host in
`memory/servers/`, then renders a side-by-side table
that highlights where servers disagree, with sections
for drift, warnings and what you decided. Alpine,
FreeBSD and macOS have probes of their own; a setting
a family does not have reads `n/a`, not drift. An
appliance is compared only with its own kind. Windows
hosts are skipped.

In Claude Code each host gets its own subagent and returns one
comparison row, which keeps the raw output out of the conversation;
elsewhere it probes one host after another. Each guest stands right
after the hypervisor its `Runs on:` line names, whether it has SSH of
its own or is reached through that hypervisor; a VM in the cloud or on a
host Hostwarden does not manage stands on its own. In a container, the
time sync, the uptime and a kernel waiting for a reboot belong to its
host and read `n/a`; the host's own column shows them where the host is
audited. It makes no configuration changes on any host (it only writes
one audit-trail line to each journal). Use it after fixing a config bug
on one server to find which others carry the same bug, or as a periodic
consistency check.

### Fleet read

An operations host — an always-on machine that runs
Hostwarden unattended, such as a nightly housekeeping
run — should not hold a key that is root on every
server. Fleet read gives its key exactly two things on
each host: running a bundle of read-only checks that
you signed, and writing one read-only line to the
journal.

```
 ❯ Build the fleet-read bundle
 ❯ Set up fleet read on web1.example.com for ops1
 ❯ Fleet-Read auf web1.example.com einrichten
```

Hostwarden builds the bundle from its housekeeping
checks, shows it to you, and deploys the wrapper
(`/usr/local/sbin/fleet-read`) and your public signing
key to each host, which needs OpenSSH 8.1 or later.
Four steps stay yours, because they decide what the
key can do:

- making the operations host's key;
- adding its line to root's authorized keys on each
  host, which Hostwarden writes out for you;
- keeping the signing key, somewhere other than the
  operations host;
- signing each bundle, with the command Hostwarden
  gives you.

On the operations host, `bin/hostwarden-fleet-run`
uses it every night and has Claude judge each result
([An operations host](operations.md#an-operations-host)).
A signed bundle stops running on its `valid-until`
date, at most a year ahead, with a warning 30 days
before; Hostwarden tells you when its checks have
changed since it was built. Whoever takes over the
operations host can replay what you signed and write
read-only journal lines, nothing more. Everything
lives in `memory/fleet/fleet-read/`. Windows hosts get
no fleet read.

## Guests and hypervisors

### Hypervisors and their guests

On a hypervisor — Proxmox VE, XCP-ng, or libvirt, Incus,
LXD, LXC, vm-bhyve, Hyper-V or VirtualBox on an ordinary
system, and FreeBSD with its jails from `jail.conf`,
Bastille or iocage — Hostwarden lists every guest without
being asked, stopped ones and templates included, in
`memory/servers/<host>/guests.md`. It reads them through
the hypervisor and asks the guest tools for hostname, OS
and addresses where they run. Other running jails are
listed too, and VirtualBox lists the VMs of the user
Hostwarden logs in as. The guests of TrueNAS, Synology
DSM, Unraid and ZimaOS are listed read-only.

Every running guest the hypervisor can enter — a
container or jail, and a Proxmox VE VM with its guest
agent — then gets memory of its own, named by its
hostname, read-only and without you naming each one. A
blacklisted guest is skipped, a Windows guest is never
entered, and on a Proxmox VE cluster only the guests on
the node the session is on are entered. That is the only
time Hostwarden goes through the hypervisor unasked;
after that, SSH comes first as always. Afterwards it
tells you which guests it read inside and through which
command, which it left out and why, what it wrote (one
read-only journal line in each guest, its host key in
`memory/known_hosts`, memory on your side), and what it
found. The first SSH connection to each guest stays
yours. A stopped guest is never started to look inside.

For stopped guests it asks you once, in one list, why
they are off: on purpose, retired, not in service yet,
or a template. The question comes back only when a guest
starts and stops again. A guest leaves the list only once
its own hypervisor confirms it is gone.

Each guest records the host it runs on, as
`Runs on: pve1.example.com (VM 101)`. The link comes
from what both sides see, never from a name alone: the
MAC addresses, and for KVM, bhyve and Xen VMs the VM's
UUID as well. Hyper-V links by the host name the
hypervisor reports to the guest. A jail without a
network stack of its own has no MAC, and links by its
path or by name and IP address together. A VM in the
cloud records its provider. Where nothing matches,
Hostwarden asks once.

### Clusters

A Proxmox VE cluster, an XCP-ng pool of more than one
host and an Incus or LXD cluster are inventoried as one,
from whichever member the session is on, in
`memory/clusters/<name>/`: its members, its HA state and
pool master, and every guest with the member it runs on.
Each guest is listed and rated once, not once per
member. A guest in a cluster records
`Runs on: cluster prod (VM 101), last on pve2.example.com`;
after a live migration or an HA failover the next listing
moves it without asking you.

### Changing a guest

Restarting a guest counts as a reboot and is asked.
Before a risky change inside a guest, a snapshot is
preferred to a file backup, on Proxmox VE, Incus, LXD,
libvirt, iocage, Bastille and ZFS; what the snapshot
leaves out, such as bind mounts and passed-through
devices, is named first. Stopping or deleting a guest
needs your explicit request and shows its disks and
newest backup first; the guard behind it is the same
as for a system container or VM
([Safety and guardrails](safety.md)). Housekeeping
lists what a host passes through to its guests and
flags a bind mount whose source fell back to the root
filesystem.

### New guests

```
 ❯ Create a Debian VM on pve1.example.com
 ❯ Leg einen neuen LXC auf pve1 an
```

Hostwarden creates VMs and containers on Proxmox VE,
libvirt, Incus, LXD and classic LXC, with the platform's
own tools. A VM starts from the distribution's official
cloud image, checked against its checksum and, where the
distribution signs one, its signature, and gets the
baseline as cloud-init user-data at its first boot, so
there is no golden image to go stale. The rendered
user-data is kept, numbered, in `memory/baseline/`, and
each guest records the version it got. On Proxmox VE,
containers come from a baseline template Hostwarden builds
from the official container template; housekeeping says
when it is due for a rebuild.

A guest that reads no cloud-init gets the same baseline in
the form its system does read: Butane and Ignition for
Fedora CoreOS and Flatcar, a kickstart, preseed,
autoinstall or AutoYaST file where the guest has to be
installed rather than copied from an image, and a seed
written into the root filesystem or the disk image before
the first start for everything else. On Incus the baseline
lives in a profile of its own per version, so it is written
once rather than on every command line. Whichever form it
takes, it is applied only to a guest that has never run:
the SSH server of a machine that is already up is never
touched, in the guest or through its host.

You log in with your SSH keys from the first boot on. If
you have no key and want a password, the guest generates
one and shows it only on its console, where you change it
at the first login; a container from the Proxmox VE
baseline template gets no generated password, and you set
one at its console. Hostwarden then checks the baseline on
the guest, asks about adding it to a backup job, and the
guest goes through the usual first connection and is
registered with its host like every other guest.

On Unraid, ZimaOS and TrueNAS you get the steps for the
web UI and a small seed ISO that carries the
configuration, since their UIs have no field for it; on
XCP-ng you get the user-data to paste into Xen
Orchestra's cloud-init field. Replacing the OS of a
machine that already exists is `hostwarden-os-install`,
not this one.

### Installing an operating system

```
 ❯ Replace the OS on web1.example.com with Debian
 ❯ Set up dual-boot with FreeBSD on this machine
```

`hostwarden-os-install` covers replacing an OS,
dual-boot, EFI boot entries and boot order, cloud
images and freeing a partition on a live system.
Reading and diagnosing always work. Before any write to
a disk, four things must hold: your explicit request,
your understanding of what is lost, a verified backup,
and a session started with the guard switched off
(`HOSTWARDEN_GUARD_DISABLE=1`, Claude Code). It never
writes to an appliance on its vendor's hardware or to a
Mac.

## Changing a server

### Configuration management

Hostwarden needs no Ansible, Puppet or Chef and never
suggests one. When a host carries signs of one —
Ansible runs in the journal, `Ansible managed` headers,
a Puppet or OpenVox, Chef or Cinc, Salt, CFEngine or
Rudder agent, a cron job that runs one of them —
Hostwarden asks once whether it manages the host,
wholly or in some areas, and remembers the answer in
the host's memory:

```markdown
- Config management: ansible (scope: base, nginx)
```

Hosts can be mixed freely. Outside that scope Hostwarden
works by hand as usual. Inside it, it tells you the
tool would undo a hand change; for Ansible it offers to
make the change in your playbooks instead, and for the
other tools the change in their code is yours. A hand
change happens only when you insist, and stays noted
in the host's memory until it is carried into the code.
Ansible runs by anyone show up in the recent-activity
summary on connect. Hostwarden runs no playbook to
apply a change; applying your Ansible code is your
step.

Agent directories and services are looked at on every
connect, so an agent installed later — or a host
Hostwarden knew before the check existed — still gets
the question, as does one whose recorded answer no
longer covers what is there. Cron jobs and rendered
files are looked at on the first connect, and again
when something new points to a tool.

Hosts built with Terraform or OpenTofu are noted when you
say so; Hostwarden then leaves what that code owns, such
as a cloud firewall or DNS record, to the code, and never
runs `terraform` or `tofu` to apply or destroy it.

### Services in containers

For a service that runs in Docker, Podman or
containerd, Hostwarden finds the compose file, Quadlet,
unit or tool that recreates the container and changes
that, after a backup, not the running container. A
restart, pull, removal or prune is asked first. `exec`
into a container only reads. A container an
appliance's web UI owns is left to that UI, and
Kubernetes workloads are reported, never changed.

### Accounts

Hostwarden records how admins log in on each host —
through a role account, a directory, local accounts or
an agent — as one `Accounts:` line, and creates or
removes accounts, groups and sudo rules the way that
model does, each asked first. Team accounts get the
same UID and GID on every host; removing one revokes
its certificates first and keeps the home directory
unless you say otherwise. Logins with user
certificates, and accounts an identity provider hands
out on demand, are covered: the second are read and
reported. It never writes to a directory, an identity
provider or a CA; it tells you what to create there.

### Files Hostwarden deploys

A script, a systemd unit or timer, a cron file, a
config drop-in or a rendered template that Hostwarden
writes onto a server has its master copy in your
workspace, at the same path it has on the host:
`memory/servers/<hostname>/files/usr/local/bin/backup-usb-watch`.
One file deployed to several hosts lives in
`memory/fleet/<name>/`, or in
`memory/clusters/<name>/files/` for a cluster's members.
`deployed.md` beside the host's memory records what was
deployed, with its hash, and a file in a format that
has comments carries one naming its master. sshd's
configuration never gets a master.

Housekeeping compares the three and reports when a file
was edited on the host, removed there, changed its
mode or owner, or changed in the workspace without
being deployed. Neither side is ever overwritten on its
own: you decide whether the host's edit goes into the
master or the master goes back onto the host. Files
you or a configuration management tool own stay where
they are — Hostwarden keeps no second copy of them.
Scripts for your own machine go in `memory/tools/`.

### Renaming a host

```
 ❯ Rename web1.example.com to web2.example.com
```

A rename happens only when you ask, one host at a time.
Hostwarden first lists what the old name reaches: the
files under `/etc` that name it, certificates, cloud-init
settings, memberships keyed by the node name, the places
in memory, and what only you can change, such as DNS,
the DHCP reservation, backups and monitoring. You add
the new DNS name first; Hostwarden then sets the
hostname and `/etc/hosts`, the references you agree to
and, for a Proxmox VE container, its name on the
hypervisor, and moves the host's memory to the new name.
The old name stays an alias until you remove it from
DNS. The host key does not change, sshd and
certificates are left alone, and history keeps the old
name.

Some renames are yours: Windows and WSL, a Proxmox VE
cluster node, an appliance that is named in its web
interface, and a host joined to a directory. Hostwarden
says so and updates memory once you have renamed it.
It never renames an Incus or LXD instance, or a VM
whose cloud-init drive takes its name, on the
hypervisor: that would regenerate its SSH host keys at
the next boot.

### Language runtimes and deploy users

```
 ❯ Install the latest stable Node.js on web1
 ❯ Set up deployment for the shop on web1
```

`hostwarden-runtimes` installs, upgrades, reports on and
removes Node.js, Python, Ruby, Go, Java and the other
runtimes [mise](https://mise.jdx.dev) carries, from mise
unless you name another way, and sets up the shell so
they are found over SSH. A question about installed
versions installs nothing. Appliances get no runtime.

`hostwarden-deploy-user` sets up, audits or removes an
account for CI/CD deployments: its own SSH key, a
restricted shell, no password, a directory it owns, and
sudo only as narrow as the deployment needs — never
root or a person's account. Installing the key is
yours; Hostwarden hands you the block to add.

### Email reports

Send ad-hoc text or files by email about a managed server:

```
 ❯ Email me the output of "df -h" from app.example.com
 ❯ Mail /var/log/auth.log to ops@example.com
```

The first email per host asks where to send from — your
workstation or the server itself — and can remember the
answer. On the server Hostwarden uses `sendmail`,
`msmtp` or a running postfix, OpenSMTPD or Exim; `mail`
or `mailx` alone does not count. When none is there it
asks before installing one, and picks one that queues
the mail — nullmailer, dma or postfix as a null client
— so a relay that is down for a minute does not lose a
report; `msmtp` only when you ask for it. Nothing is
installed on a Mac or on your workstation. It sends as
a non-root user when possible. Attachments are checked
for readability and size, get a content preview before
sending, and a file that likely holds a secret is
refused by default.

Every message closes with a greeting and a signature
naming Hostwarden and the operator, both overridable in
`memory/user.md`, and carries the headers that keep
out-of-office and vacation auto-replies from answering
it.

## Working with others

The workspace, `memory/`, is a git repository of its
own that a team, or one admin on several machines,
shares through a private remote:
[Team setup and several machines](operations.md#team-setup-and-several-machines).

### Parallel sessions

Sessions that change the same host — two windows, or
teammates on different workstations — see each other
and, in Claude Code, can message each other directly:
[Parallel sessions](operations.md#parallel-sessions).

### Plan mode

For complex or unfamiliar tasks, plan before touching
anything:

```
 ❯ /plan Migrate the database from MySQL to
   PostgreSQL on db.example.com
```

Hostwarden explores the server, reads configs and
drafts a step-by-step plan. It changes nothing until
you approve the plan.

`/plan` is a Claude Code command; in the desktop app,
pick Plan in the mode selector instead. In another
tool, ask Hostwarden to plan before acting.

### Moving over from Heinzel

```
 ❯ Take my Heinzel in ~/heinzel over
```

`hostwarden-heinzel-takeover` copies an existing
Heinzel installation into this workspace and onboards
each host read-only. It can run host by host:
[Moving over from Heinzel](operations.md#moving-over-from-heinzel).
