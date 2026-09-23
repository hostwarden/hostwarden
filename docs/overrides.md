# Overrides

An override is a file you write to change what Hostwarden
does: add to a rule, replace part of it, or take part of
it out. Files under `rules/` and `.agents/skills/` belong
to Hostwarden and are replaced on every update, so you
never edit them. Your overrides live in the workspace,
under `memory/`, and survive every update.

This page is for you. The agent follows
`rules/overrides.md`, which uses the same terms and adds
what it does in the unclear cases: an override that
matches nothing, a section that moved in an upgrade.

## Precedence

Later wins:

1. **Shipped** — the rule file in `rules/` or a skill.
2. **Global** — the file under `memory/custom-rules/`
   that mirrors it, see below.
3. **Every file** — `memory/custom-rules/all.md`,
   loaded at session start and applying to everything.
4. **This host** — `memory/servers/<hostname>/rules.md`.

Two things no override changes: the Critical Safety
Rules in `AGENTS.md`, and whether a skill starts at all.
A skill is picked by its description before any of your
files are read, so trigger wording goes into
`memory/custom-rules/all.md`, which is read at session
start:

```markdown
## Add: Skill triggers
"check <host>" means run housekeeping, not a quick query.
```

That governs every request after the read. The first
request of a session can pick a skill before it, so
`all.md` is a preference, not a hard gate.

## Where an override goes

A global override mirrors the path of what it changes,
minus the top-level directory and minus `references/`:

| Shipped | Yours, under `memory/custom-rules/` |
| --- | --- |
| `rules/backups.md` | `backups.md` |
| `rules/os/debian.md` | `os/debian.md` |
| `rules/appliance/opnsense.md` | `appliance/opnsense.md` |
| `rules/platform/wsl.md` | `platform/wsl.md` |
| `rules/role/workstation.md` | `role/workstation.md` |
| skill `hostwarden-security` | `hostwarden-security.md` |
| that skill's `references/ssh.md` | `hostwarden-security/ssh.md` |

What there is to override:
`ls rules/ rules/*/ .agents/skills/`, and the `references/`
directory of any skill.

For one host, everything goes into one file,
`memory/servers/<hostname>/rules.md`, with a `#` heading
per subject, named the way the table names it:

```markdown
# backups
## Replace: Backup retention
Keep 90 days.

# hostwarden-security/ssh
## Remove: Weak algorithm check
```

## Writing one

Each section's heading says what it does to the section
of the same name in the shipped file:

```markdown
## Add: Nightly window
Schedule unattended-upgrade reboots for 02:00-04:00.

## Replace: Backup retention
Keep 90 days.

## Remove: Notes > snap
```

- `Add:` — new instruction, as a section of its own or
  inside one the shipped file has. A heading without a
  prefix is an addition too.
- `Replace:` — the shipped section is ignored, and yours
  stands in its place.
- `Remove:` — the shipped section does not apply. A `>`
  narrows it to one entry: `Notes > snap` drops the snap
  line and leaves the rest of Notes standing.

**Prefer `Add` to `Replace`.** An addition that
contradicts a shipped default still wins. A replacement
makes the section yours to maintain: when the shipped one
gains a step, your copy does not.

Hostwarden names the overrides in force in one line at
session start. A file whose path matches nothing shipped
gets one line saying so — that is how you catch a typo —
and is otherwise ignored; if the shipped file was split
in an upgrade, it asks which part you meant. A `Replace`
or `Remove` whose section matches nothing makes it stop
and ask; an `Add` becomes a new section.

## Decisions

A decision is not an override. It records a choice you made
about your servers, with the reason: pve1 gets no local
firewall, a key stays unrotated, the UniFi devices get no SSO.
Hostwarden then stops proposing what the decision rules out,
and an audit reports what it settles as `DECIDED` instead of
as an issue. It never records one on its own: it offers to
when you turn a proposal down with a reason, and writes on
your yes. `rules/decisions.md` has the rest.

| For | File |
| --- | --- |
| One host | `memory/servers/<hostname>/decisions.md` |
| A cluster | `memory/clusters/<name>/decisions.md` |
| A group, or all hosts | `memory/decisions/<name>.md` |

```markdown
# Decisions — pve1.example.com

## No local firewall
- Decided: alice, 2026-09-18
- Why: the router guest filters everything; rules on the
  bridges broke guest traffic.
- Settles: baseline → Firewall; proposals to enable one
```

Where the reasoning is longer — the options you weighed, the
numbers behind it — it goes into a file beside the decision
file, in a directory of the same name without `.md`
(`servers/<hostname>/decisions/<name>.md` under `memory/` for
a host), and the entry names that file in a `Details:` line.
Hostwarden reads it only when the decision is in question.

A group file says which hosts it covers in its second line, never
wrapped however long it gets:
`Applies to: all`, a line from the hosts' memory
(`Applies to: Appliance: Proxmox VE`), or a list
(`Applies to: hosts web1.example.com, web2.example.com`).

Where a decision also has to change what Hostwarden does, it
gets an override too, whose first line points back at it:
`Decision: Reboots by hand only (decisions/databases.md)`. The
reason then stays in the decision. To retire a decision, say
so; Hostwarden deletes it and the override with it. The
workspace history keeps the old text.

The Critical Safety Rules cannot be decided away, just as they
cannot be overridden.

## Your own skills

A workflow Hostwarden does not ship goes into
`memory/.claude/skills/<name>/SKILL.md` and travels
with the workspace. Claude Code offers it as
`/memory:<name>` once the session has read your
memory, or at once after `/add-dir memory`. OpenCode
and Codex only find skills in the project's own
directories and in your home, so link it into
`~/.config/opencode/skills/` or `~/.agents/skills/`
there. To change what a shipped skill does, override
it as above instead — a copy stops receiving
updates.
