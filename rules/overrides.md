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

Two shapes, because the shipped tree has two:

| Shipped | Customize in `memory/custom-rules/` |
| --- | --- |
| `rules/backups.md` | `backups.md` |
| `rules/os/debian.md` | `os/debian.md` |
| skill `hostwarden-security` | `hostwarden-security.md` |
| that skill's `references/ssh.md` | `hostwarden-security/ssh.md` |

**A rule keeps its path under `rules/`. A skill is a
directory named after itself, holding one file per
reference.** Nothing else to work out: `references/` is
noise in a path that is already inside a skill, and no
two skills collide, because each has its own directory.

The only way two things can want the same name is a rule
file and a skill called the same — `rules/os/` and a
skill named `os` included.
`.claude/hooks/instructions-test.sh` guards exactly that.

A user who wants to know what can be customized lists the
shipped tree: `ls rules/ rules/os/ .agents/skills/` and the
`references/` directory of any skill.

Per host, one file — `memory/servers/<hostname>/rules.md` —
with an `H1` per subject, written the way the table above
writes it, and the usual prefixed headings under each:

    # backups
    ## Replace: Backup retention
    Keep 90 days.

    # hostwarden-security/ssh
    ## Remove: Weak algorithm check

A prefixed heading that sits outside any `H1` names no
shipped file, so there is nothing to resolve it against —
`## Replace: Backup retention` alone could mean the backups
rule or a skill's own backup section. Do not guess which:
name the file and the headings, and ask which subject they
belong under. Same reason as an unmatched `## Replace:`
below — a heading that says "the shipped text must not
apply" is the wrong one to resolve by nearest match.

When an upgrade moves a topic — out of `rules/` into a
skill, or into `rules/os/` — `bin/hostwarden-migrate` moves
the matching override with it, and says which files it
moved. It runs on update and as the last step of adopting a
heinzel checkout. A file already at the new path wins; the
old one is left for the user to merge, and named.

**An override path that matches nothing shipped is almost
always a typo or a stale name.** Say so once, name the file,
and carry on — silently ignoring it is how a user ends up
believing a customization is in force for months.

## The format

Markdown with heading prefixes naming a section of the
shipped file. Load them before acting on that file, not
after.

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
shipped file. When it matches none, what to do depends on
the prefix, because the two directions fail differently:

- `## Add:` — treat it as a new section and say so once.
  An addition that lands beside nothing is still the
  instruction the user wrote.
- `## Replace:` and `## Remove:` — **stop and ask.** Both
  mean "the shipped text must not apply", and silently
  reclassifying them as additions inverts that into "apply
  this as well". On a topic like disk replacement, an
  override saying *remove this safety section* becoming
  *add it* is the wrong way round to guess.

A shipped file that was split since the override was
written is the common cause: the section still exists,
under a sibling file's name. Name the siblings when you
ask.

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

At the moment the shipped file is read and **before acting on
it**, not at session start — with one exception: `memory/custom-rules/all.md`
and the access lists load during the session-start
preflight, because they have to be in force before the
first connection.

Missing override files are the normal case. Their absence
is never an error and never worth a line to the user.

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
