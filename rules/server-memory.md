# Server Memory

Each server: `memory/servers/<hostname>/` with
`memory.md`, `changelog.log`, optionally `todo.md`,
and optionally `rules.md` (per-server rule
overrides — see `rules/overrides.md`).

**On first connection:** create directory and
`memory.md` with at least:

```markdown
# hostname.example.com
- IP: 203.0.113.10
- OS: Debian 12 (Bookworm)
- Distro family: debian
- Appliance: Proxmox VE 9.0.3, standalone
- Shell: bash (root)
- CPU: 4x Intel Xeon E-2236 @ 3.40GHz
- RAM: 16 GB
- Disk: 80 GB (/ ext4, 45% used)
- Last connected: 2026-02-25
```

A host that Heinzel administered gains a
`heinzel legacy:` line once that state has been dealt
with; `rules/heinzel-adoption.md` owns its wording.
Hosts without one never had Heinzel state, which is
the normal case.

Adapt fields to OS (add Arch, Homebrew for macOS;
add `Mode: local` for localhost). `Appliance:` only
when `rules/os-detection.md` → Appliances found one,
in the form the appliance file gives; `Shell:` once
per SSH user, from the same file's step 1.

**Update memory immediately after any system
change.** Keep it compact (~30 lines max). Remove
outdated entries, merge related items.

**Update `Last connected:` on every connection.**

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
