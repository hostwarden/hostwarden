# Features

## Auto OS-detection

The first time you point Hostwarden at any machine, it
detects the OS, gathers hardware info, and remembers
everything for future sessions.

## DNS alias detection

When multiple DNS names point to the same server,
Hostwarden detects this automatically by comparing IP
addresses. The first hostname becomes the canonical
name; additional names become symlinks that share the
same memory. Each alias can have its own SSH user.

## Memory across sessions

After working on a machine, Hostwarden remembers it.
Next week you start a new session and type:

```
 ❯ Check on web1.example.com.
```

It reads
`memory/servers/web1.example.com/memory.md`, already
knows it's Debian 12 with nginx and PostgreSQL,
checks the local changelog, and picks up right where
it left off.

## Hypervisors and their guests

On a hypervisor — Proxmox VE, XCP-ng, or libvirt, Incus,
LXD, LXC, bhyve, Hyper-V or VirtualBox on an ordinary
system, and FreeBSD with its jails from `jail.conf`,
Bastille or iocage — Hostwarden lists every guest without
being asked, stopped ones and templates included, in
`memory/servers/<host>/guests.md`. It reads them through
the hypervisor and asks the guest tools for hostname, OS
and addresses where they run.

Every running guest the hypervisor can enter — any
container or jail, and a Proxmox VM with its guest agent — then
gets memory of its own, named by its hostname, read-only
and without you naming each one. That is the only time
Hostwarden goes through the hypervisor unasked; after
that, SSH comes first as always. Afterwards it tells you
which guests it read inside and through which command,
which it left out and why, what it wrote (one read-only
journal line in each guest, memory on your side), and
what it found. The first SSH connection to each guest
stays yours.

For stopped guests it asks you once, in one list, why
they are off: on purpose, retired, not in service yet,
or a template. The question comes back only when a guest
starts and stops again.

Each guest records the host it runs on, as
`Runs on: pve1.example.com (VM 101)`. The link comes from
the MAC addresses and the VM's UUID, which both sides
see, never from a name alone. A jail without a network
stack of its own has no MAC, and links by its path or by
name and IP address together.

## ZFS and btrfs

On a host with ZFS pools or btrfs, Hostwarden records the settings
that decide how the storage behaves, once, in
`memory/servers/<host>/storage.md`: each pool's layout, TRIM,
compatibility and features not yet enabled, the dataset properties
someone set by hand (compression, `sync`, dedup, record size),
encryption roots, the ARC limits, and btrfs profiles, compression
and quotas. Housekeeping reads them again on every run and names
what changed.

It also rates them: `sync=disabled` on data that matters, dedup
without the RAM for it, compression off, autotrim off on flash
with no trim running, a special vdev with less redundancy than the
pool, an ARC that leaves too little room for a hypervisor's
guests, and btrfs profiles left half converted. Pool features that
`zpool upgrade` would enable are reported, never enabled: that
step cannot be undone, and it is yours. Tell it why a setting is
the way it is, and it stops asking.

## Server baseline

What every server is expected to have is written down in
one place, `rules/baseline.md`: a firewall that denies
incoming traffic by default and keeps SSH open, automatic
security updates, time sync, SSH by key only, a persistent
journal, the guest agent in a VM, and a backup. The
security audit and housekeeping measure every server
against it. Ask Hostwarden to bring a server up to the
baseline, and it lists what is missing and applies it one
asked step at a time. It never changes sshd on a running
server: for SSH it gives you the change to make.

Your own additions go into
`memory/custom-rules/baseline.md`, as an override
(`docs/overrides.md`):

```markdown
## Add: Admin Keys
- alice: ssh-ed25519 AAAAC3Nza… alice@example.com

## Add: Timezone
Europe/Berlin

## Add: Monitoring
node_exporter from the distribution's package.
```

Public keys only: passwords and tokens never go there.

## New guests

```
 ❯ Create a Debian VM on pve1.example.com
 ❯ Leg einen neuen LXC auf pve1 an
```

Hostwarden creates VMs and containers on Proxmox VE,
libvirt, Incus, LXD and classic LXC, with the platform's
own tools. A VM starts from the distribution's official
cloud image, checked against its checksum, and gets the
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
at the first login. The new guest
then goes through the usual first connection and is
registered with its host like every other guest. On
Unraid, ZimaOS, TrueNAS and XCP-ng you get the steps for
the web UI or Xen Orchestra instead, with a small seed ISO
that carries the same configuration where the UI has no
field for it.
Replacing the OS of a machine that already exists is the
OS-install workflow, not this one.

A Proxmox VE cluster, an XCP-ng pool and an Incus or LXD
cluster are inventoried as one, from whichever member
Hostwarden reaches first, in
`memory/clusters/<name>/`: its members, its HA state and
pool master, and every guest with the member it runs on.
Each guest is listed and rated once, not once per member.
A guest in a cluster records
`Runs on: cluster prod (VM 101), last on pve2.example.com`;
after a live migration or an HA failover the next listing
moves it without asking you.

## Session to-do list

When a multi-step task gets interrupted — connection
drop, conversation ends, laptop closes — Hostwarden
keeps a to-do list in
`memory/servers/<hostname>/todo.md` with checkboxes
for each step. On reconnection it shows what's still
pending and asks whether to continue or start fresh.

## Housekeeping checks

Run routine health inspections on any server:

```
 ❯ Run housekeeping on app.example.com
```

Hostwarden checks disk, memory, load, pending updates,
firewall, SSL certificates, failed services, and
server-specific services. Problems are highlighted
at the top of a concise report.

## Security audit

Check security configuration on any server:

```
 ❯ Run a security audit on app.example.com
```

Hostwarden checks SSH password authentication settings,
firewall status, and reports issues by severity.

## Fleet audit

Compare key policies across every server Hostwarden knows about:

```
 ❯ Run a fleet audit
 ❯ Vergleiche die Policies auf allen Servern
```

Hostwarden probes unattended-upgrades, sshd effective config,
firewall posture, MTA, time sync, auto-reboot behaviour and,
on Ubuntu, Pro/ESM coverage and needrestart's restart mode
on each host in `memory/servers/`, then renders a
side-by-side table that highlights where servers disagree.
Each guest stands right after the hypervisor its
`Runs on:` line names, whether it has SSH of its own or is
reached through that host; a VM in the cloud or on a host
Hostwarden does not manage stands on its own. In a
container, the time sync, the uptime and a kernel waiting for
a reboot belong to its host and read `n/a`; the host's own column
shows them where the host is audited.
It makes no configuration changes on any host (it only
writes one audit-trail line to each journal). Use it after
fixing a config bug on one server to find which others
carry the same bug, or as a periodic consistency check.

## Email reports

Send ad-hoc text or files by email about a managed server:

```
 ❯ Email me the output of "df -h" from app.example.com
 ❯ Mail /var/log/auth.log to ops@example.com
```

The first email per host asks once where to send from
(local workstation or the server itself) and remembers the
answer. On the remote path Hostwarden prefers an existing MTA
(postfix, sendmail, msmtp, mail/mailx) and asks before
installing one. Sends as a non-root user when possible.
Attachments check sender readability, file size, and offer
a content preview before sending.

Every message closes with a two-line greeting from Hostwarden
(`Viele Grüße / Hostwarden`) followed by a short signature
naming Hostwarden, the project URL, and the operator who
requested the send. The operator name comes from
`Operator name:` in `memory/user.md` (with a sensible
fallback chain to git config and the system full name).
Set it once; edit it any time. Both lines are
overridable: a `Greeting:` line in `memory/user.md` or
`memory/servers/<host>/memory.md` replaces the default
wording.

Every Hostwarden email also carries the RFC 3834
`Auto-Submitted: auto-generated` header plus
`Precedence: bulk` and `X-Auto-Response-Suppress: OOF,
AutoReply`, so out-of-office and vacation auto-replies
do not fan back at the operator.

## Plan mode (Claude Code)

For complex or unfamiliar tasks, switch to plan mode
before touching anything:

```
 ❯ /plan Migrate the database from MySQL to
   PostgreSQL on db.example.com
```

Hostwarden explores the server, checks what's running,
reads configs, and drafts a step-by-step plan — but
makes no changes. You discuss the approach, adjust
it, and only when you approve does execution begin.

> **Note:** The `/plan` command is a Claude Code
> feature; in the desktop app, pick Plan in the mode
> selector instead. OpenCode does not have an
> equivalent — simply ask Hostwarden to plan before
> acting.

## Configuration management

Hostwarden needs no Ansible, Puppet or Chef and never
suggests one. When a host carries signs of one —
Ansible runs in the journal, `Ansible managed` headers,
a Puppet, Chef, Salt, CFEngine or Rudder agent or one
of their forks, a cron job that runs one of them —
Hostwarden asks once whether it manages the host,
wholly or in some areas, and remembers the answer in
the host's memory:

```markdown
- Config management: ansible (scope: base, nginx)
```

Hosts can be mixed freely. Outside that scope Hostwarden
works by hand as usual. Inside it, it tells you the
tool would undo a hand change, and offers to make it in
your Ansible playbooks instead; a hand change happens
only when you insist, and stays noted in the host's
memory until it is carried into the code. Ansible runs
by anyone show up in the recent-activity summary on
connect.

Agent directories and services are looked at on every
connect, so an agent installed later — or a host
Hostwarden knew before the check existed — still gets
the question, as does one whose recorded answer no
longer covers what is there. Cron jobs and rendered
files are looked at on the first connect only.

Hosts built with Terraform or OpenTofu are noted when you
say so; Hostwarden then leaves what that code owns, such
as a cloud firewall or DNS record, to the code.

## Local administration

Hostwarden also works on the local machine — no SSH
needed, commands run directly. The same safety rules,
memory, and guardrails apply whether the target is a
remote server or your own laptop.

This works on both Linux and macOS:

```
 ❯ Update all Homebrew packages on this Mac
```

```
 ❯ Check if the firewall is configured on
   this machine
```

