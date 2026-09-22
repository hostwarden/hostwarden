# Server Memory

Each server: `memory/servers/<hostname>/` with
`memory.md`, `changelog.log`, optionally `todo.md`,
and optionally `rules.md` (per-server rule
overrides — see `rules/overrides.md`).

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
  under `@platform` (`rules/os-detection.md`). Where
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

A host that Heinzel administered gains a
`heinzel legacy:` line once that state has been dealt
with; `rules/heinzel-adoption.md` owns its wording.
Hosts without one never had Heinzel state, which is
the normal case.

A host that a configuration management tool manages,
wholly or in some areas, gains a `Config management:`
line, and one that Terraform or OpenTofu provisioned
a `Provisioned by:` line; `rules/config-management.md`
owns their wording. Most hosts have neither.

Adapt fields to OS (add Homebrew for macOS;
add `Mode: local` for localhost, or
`Mode: via pve1.example.com (pct exec 105)` for a
guest that has no sshd of its own, with the whole
command it is reached by, the Incus project included
(`rules/first-connection.md`). A guest whose SSH
merely timed out never gets that line: via-host mode
is this session's only, and the line would route
every later session through the host
(`rules/system-containers.md` → Reaching It);
an OS file whose Version Detection names fields to
record adds those. `Appliance:`,
`Platform:`, `Role:` and `Shell:` come from
`rules/os-detection.md`; `SSH port:`, remote mode only, is
the `port` line of `ssh -G <user>@<hostname>`, which the
alias check in `rules/dns-aliases.md` compares. A
field a probe could not read is written `unknown`, never
filled from an example. A container engine is recorded as
`- Container runtime: podman (rootless: alice)`, the form
`rules/service-class-check.md` gives.

`Virtualization:` and `Arch:` come from
`rules/os-detection.md` → Virtualization and step 2.

**Update memory immediately after any system
change.** Keep it compact (~30 lines max). Remove
outdated entries, merge related items.

**Update `Last connected:` on every connection.**

Two lines join once their rule has run, never before.
`- Network:` summarises
`memory/servers/<hostname>/network.md`, the host's own
network profile (`rules/network.md`). `- Access:` records
how Hostwarden reaches the host and which other paths were
tested (`rules/ssh-safety-net.md` → Which way in):

```markdown
- Access: via Tailscale (web1.tail1234.ts.net); direct
  203.0.113.10 timeout (2026-09-19)
```

Memory files never hold credential values — see
`rules/secrets.md`.

## Session to-do list

For a session of two steps or more, create
`memory/servers/<hostname>/todo.md`. Mark a task
`[x]` the moment it is done, not at the end — a
session that is interrupted has to leave behind
what was actually finished. On reconnection, show
the pending items before starting new work. Delete
the file once everything is done.

## Cross-server facts

Facts that belong to no single host — a shared
gateway, a VPN subnet, which machine holds the
backup target — go in `memory/network.md`, created
on first need. Current facts only; it is a picture
of now, not a history.

## Personal versus shared

`memory/` is the workspace, a git repository of its
own, never part of Hostwarden's. Solo use is the
default: it has no remote. A team gives it a private
one, and then the split matters.

**Always personal, never shared:** `memory/user.md`
(SSH usernames and language), `memory/blacklist.md`,
`memory/readonly.md`, and the memory directory of
anyone's local machine. The workspace's own
`.gitignore` names them; a machine's hostname
directory has to be added there by hand.

**Shared in team mode:** everything else —
`memory/servers/*/` with each host's `rules.md`,
`memory/network.md`, `memory/housekeeping.md`,
`memory/service-policy.md` and `memory/custom-rules/`.

When a teammate's session shows up in the activity
check (`rules/activity-check.md`), their memory
edits may not be pulled into the workspace yet. Trust
the host over the file.
