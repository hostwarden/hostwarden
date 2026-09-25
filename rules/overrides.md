# Overrides

An override is a file the user writes to add to, replace or
remove part of what Hostwarden ships, and it wins over the
shipped text. Files under `rules/` and `.agents/skills/` are
replaced on every update, so they are never edited to change
behaviour. Overrides go under `memory/custom-rules/` and into
`memory/machines/<hostname>/rules.md` instead.

## Precedence

Later wins:

1. **Shipped** — the instruction file in `rules/` or a
   skill. For a host, the family file with its
   appliance, platform and role files applied on top
   (`rules/os-detection.md` → Layers).
2. **Global** — the file under
   `memory/custom-rules/` that mirrors it, see below.
   For a host, the override of each layer in the
   order of `rules/os-detection.md` → Layers, all on
   top of the merged shipped files,
   so a shipped `Replace:` never takes out what a user
   wrote.
3. **Every file** — `memory/custom-rules/all.md`, loaded
   once at session start and applying to everything.
4. **This host** — `memory/machines/<hostname>/rules.md`.

`all.md` sits above the mirrored files on purpose: it is
where a user states something that must hold everywhere,
and a mirrored file is the narrower statement of one topic,
not a stronger one. The host file is last because it is the
most specific thing the user can say.

**Not overridable at any level:** `AGENTS.md` → Critical
Safety Rules. The absolute taboos, the ask-before list, the
port-22 refusal, secrets hygiene. The taboo guard enforces
the hardest of them mechanically, so an override that tries
would not work even if this file allowed it. Follow the
rest of such a file and tell the user which part was
ignored.

## Where an override goes

Two shapes, because the shipped tree has two:

| Shipped | Override in `memory/custom-rules/` |
| --- | --- |
| `rules/backups.md` | `backups.md` |
| `rules/os/debian.md` | `os/debian.md` |
| `rules/appliance/opnsense.md` | `appliance/opnsense.md` |
| `rules/platform/wsl.md` | `platform/wsl.md` |
| `rules/role/workstation.md` | `role/workstation.md` |
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

A user who wants to know what can be overridden lists the
shipped tree:
`ls rules/ rules/*/ .agents/skills/`
and the `references/` directory of any skill.

Per host, one file — `memory/machines/<hostname>/rules.md` —
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
moved. It runs on update and as the last step of taking
over a Heinzel checkout. A file already at the new path
wins; the old one is left for the user to merge, and named.

It moves whole files, which is all it can do: when a topic
was not only moved but **split**, some sections of the
moved override now belong under a reference key instead —
a `## Replace: Installation` that followed `mise` into
`hostwarden-runtimes.md` belongs under
`hostwarden-runtimes/install-mise.md`. Those arrive as
headings matching nothing, and the rule above applies:
name them, name the sibling files the section could have
gone to, and ask. Do not resolve them by nearest match.

**An override path that matches nothing shipped needs an
answer before you carry on.** Silently ignoring it is how a
user ends up believing an override is in force for
months. Which answer depends on what is shipped beside the
name it claims:

- **Sibling files extending that name** —
  `transport-local.md` and `transport-remote.md` where the
  override says `transport.md` — mean the shipped file was
  **split**. The override is live text about a topic that
  still exists. Name it, name the siblings, and ask which
  one it belongs under. Never pick one yourself: the two
  branches of a split are exactly the case the user can
  tell apart and a nearest-match guess cannot.
- **Nothing of the sort beside it** is a typo or a stale
  name. Say so once, name the file, and carry on.

A file can split without moving, so this is not something
`bin/hostwarden-migrate` has a row for — and it could not
use one. Moving a whole file is all that script can do, and
a whole file is precisely what a split has stopped being.

## The format

Markdown with heading prefixes naming a section of the
shipped file. Load them before acting on that file, not
after.

    ## Add: Nightly window
    Schedule unattended-upgrade reboots for 02:00-04:00
    and say so when proposing one.

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
shipped file. A `>` narrows it to one entry inside that
section — `## Remove: Notes > snap` drops the snap line and
leaves the rest of `## Notes` standing. Narrow rather than
take a whole section out for the sake of one line in it.

When either part matches nothing, what to do depends on the
prefix, because the two directions fail differently:

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

## An override for a decision

A block whose body opens with `Decision: <heading> (<file>)`
— the first line under its `##` heading, the file's path below
`memory/` — enforces a decision the user recorded
(`rules/decisions.md`). It applies only on the hosts
that decision applies to, and nowhere else, whichever file it
sits in; its place in the precedence above is that file's. The
reason for it is in the decision, never repeated in the block.

A pointer whose decision no longer exists means the block
outlived it: name both and ask whether the block goes too,
before acting on the file it overrides.

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

Trigger behaviour is changed in
`memory/custom-rules/all.md` instead:

    ## Add: Skill triggers
    "check <host>" means run housekeeping, not a quick query.
    Never start a security audit without me saying "audit".

`all.md` is read in the session-start preflight, so it
governs every turn from there on. It is not a gate in front
of the matcher: on the first request of a session the
harness can match a skill before the preflight has run. Say
that when a user wants a hard gate rather than a
preference — the reliable form is not to ship the skill,
and that is their decision to make, not something an
override file can do for them.

Per-host trigger changes are not possible at all: the host
is not known until the connection, which is often after the
skill fired. When a user asks for one, say that, and offer
the `all.md` form with a host condition written into it.

This asymmetry is not a reason to keep something in
`rules/` that belongs in a skill. A workflow the user asks
for by name belongs in a skill; the handful of cases where
its trigger needs changing are served by `all.md`.

## A skill of the user's own

A workflow Hostwarden does not ship is a skill of the
user's own, in `memory/.claude/skills/<name>/SKILL.md`.
Claude Code loads it as `/memory:<name>` once the session
has read a file in `memory/`, which the session-start
preflight does; `/add-dir memory` loads it at once.
OpenCode and Codex look for skills only from the working
directory up to the repository root and in the user's home,
so there it has to be linked into the tool's own directory
in `~` (`~/.config/opencode/skills/`, `~/.agents/skills/`),
where every project sees it.

A skill of the user's own never replaces a shipped one of
the same name: the qualified name keeps both. To change
what a shipped skill does, override it as above — that way
it keeps receiving updates.
