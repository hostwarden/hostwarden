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
`memory/custom-rules/all.md`, which is in context from
the start:

```markdown
## Add: Skill triggers
"check <host>" means run housekeeping, not a quick query.
```

## Where an override goes

A global override mirrors the path of what it changes,
minus the top-level directory and minus `references/`:

| Shipped | Yours, under `memory/custom-rules/` |
| --- | --- |
| `rules/backups.md` | `backups.md` |
| `rules/os/debian.md` | `os/debian.md` |
| skill `hostwarden-security` | `hostwarden-security.md` |
| that skill's `references/ssh.md` | `hostwarden-security/ssh.md` |

What there is to override:
`ls rules/ rules/os/ .agents/skills/`, and the
`references/` directory of any skill.

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
session start. When one matches nothing shipped — a typo,
or a section that moved in an upgrade — it says so, and
for a `Replace` or `Remove` it asks before carrying on.

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
