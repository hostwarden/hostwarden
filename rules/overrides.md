# Custom Rules and Overrides

A user's customizations win over anything hostwarden ships.
Files under `rules/` and `.agents/skills/` are replaced on
every update, so they are never edited to change behaviour.
The files under `memory/custom-rules/` and
`memory/servers/<hostname>/rules.md` are.

## Precedence

Later wins:

1. **Shipped** — the instruction file in `rules/` or a
   skill.
2. **Global custom** — the file under
   `memory/custom-rules/` that mirrors it, see below.
3. **Every file** — `memory/custom-rules/all.md`, loaded
   once at session start and applying to everything.
4. **This host** — `memory/servers/<hostname>/rules.md`.

`all.md` sits above the mirrored files on purpose: it is
where a user states something that must hold everywhere,
and a mirrored file is the narrower statement of one topic,
not a stronger one. The host file is last because it is the
most specific thing the user can say.

**Not overridable at any level:** `CLAUDE.md` → Critical
Safety Rules. The absolute taboos, the ask-before list, the
port-22 refusal, secrets hygiene. The taboo guard enforces
the hardest of them mechanically, so an override that tries
would not work even if this file allowed it. Follow the
rest of such a file and tell the user which part was
ignored.

## Where a customization goes

**The override path mirrors the shipped path**, minus the
top-level directory and minus the `references/` segment:

| Shipped | Customize in `memory/custom-rules/` |
| --- | --- |
| `rules/backups.md` | `backups.md` |
| `rules/os/debian.md` | `os/debian.md` |
| skill `hostwarden-security` | `hostwarden-security.md` |
| that skill's `references/ssh.md` | `hostwarden-security/ssh.md` |

One rule, and it is unambiguous by construction: two skills
may both ship a `report-format.md` without their overrides
colliding, because each sits under its own skill's
directory. `.claude/hooks/instructions-test.sh` guards the
single seam where a collision is still possible — a rule
file and a skill with the same name.

A user who wants to know what can be customized lists the
shipped tree: `ls rules/ rules/os/ .agents/skills/` and the
`references/` directory of any skill.

The per-server file is one file per host,
`memory/servers/<hostname>/rules.md`, holding blocks for
however many topics that host needs. Its blocks name their
subject in the heading:

    ## Replace: backups / Backup retention
    ## Add: hostwarden-security / Listening services

When an upgrade moves a topic — out of `rules/` into a
skill, or into `rules/os/` — `bin/hostwarden-migrate` moves
the matching override with it, and says which files it
moved. It runs on update and as the last step of adopting a
heinzel checkout. A file already at the new path wins; the
old one is left for the user to merge, and named.

**An override path that matches nothing shipped is almost
always a typo or a stale name.** Say so once, name the file,
and carry on — silently ignoring it is how a user ends up
believing a customization is in force for months. This
matters most after an upgrade moves a topic between
mechanisms: the old path stops resolving, and the message is
the only thing that tells them.

## The format

Markdown with heading prefixes. In a per-key file the
heading names a section of the shipped file; in a per-server
file it names the subject first, then the section.

    ## Add: Nightly reboot window
    These hosts accept a reboot between 02:00 and 04:00
    without asking again.

    ## Replace: Backup retention
    Keep 90 days.

    ## Remove: Provider snapshot question

- `## Add:` — new instruction. Either a new section, or
  extra rules inside a section the shipped file already
  has.
- `## Replace:` — the named section of the shipped file is
  ignored entirely and this stands in its place.
- `## Remove:` — the named section does not apply.
- A heading with no prefix is an addition.

The name after the prefix matches a section heading in the
shipped file. When it matches no section, treat the block
as an addition and say so once.

**Prefer `## Add:` to `## Replace:`.** An added instruction
that contradicts a shipped default wins — it is the user's
word on that point, and it is later and more specific.
Replace means the user takes over maintaining that whole
section: when the shipped one gains a step next month,
their copy will not have it. Reach for Replace only when
the shipped section must genuinely be gone.

Two `## Replace:` blocks for the same section in one file
cannot both be meant. Apply neither and ask.

## When overrides are read

At the moment the shipped file is read, not at session
start — with one exception: `memory/custom-rules/all.md`
and the access lists load during the session-start
preflight, because they have to be in force before the
first connection.

Missing override files are the normal case. Their absence
is never an error and never worth a line to the user.

**Say what is active.** After the preflight, name the
customizations in one line — *"Custom rules: all, backups,
os/debian."* — or say nothing when there are none. A user
who mistyped a path, or whose file was shadowed, finds out
in the first second of the session instead of never.

## Skills are different in one way

A skill's body and its references override exactly like a
rule file: the skill says to load its overrides, and the
chain above applies.

Its **description** does not. The description is what the
harness matches to decide whether the skill fires at all,
and that decision is made before any memory file is read.
So a user cannot change *whether* a skill triggers by
writing `memory/custom-rules/<skill>.md` — only what it
does once it has.

Trigger behaviour is customized in
`memory/custom-rules/all.md` instead, which is in context
before anything fires:

    ## Add: Skill triggers
    "check <host>" means run housekeeping, not a quick query.
    Never start a security audit without me saying "audit".

Per-host trigger changes are not possible at all: the host
is not known until the connection, which is often after the
skill fired. When a user asks for one, say that, and offer
the `all.md` form with a host condition written into it.

This asymmetry is not a reason to keep something in
`rules/` that belongs in a skill. A workflow the user asks
for by name belongs in a skill; the handful of cases where
its trigger needs customizing are served by `all.md`.
