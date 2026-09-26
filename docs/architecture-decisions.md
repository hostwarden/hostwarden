# Architecture decisions

Why Hostwarden is built the way it is: one record per decision, in
[docs/adr/](adr/README.md). A record says why, once, on a date, and
once a release carries it, it is never rewritten. What holds now is in the
instruction files, which change whenever a decision does.

The format is Workoho's decision-records skill (plugin `wkho-code`),
copied here so that no contributor needs the plugin: this page, the
templates below and `scripts/decisions.py`, with the three changes
[20260924-cite-only-rules](adr/20260924-cite-only-rules.md) and
[20260926-edit-unreleased-records](adr/20260926-edit-unreleased-records.md)
explain.

## What is a record, and what is not

- **A record** is a decision about Hostwarden itself: how it is
  built, what it supports, how it is developed.
- **A user's decision** about their own hosts — "this host never gets a
  local firewall" — is not one. It lives in that user's `memory/`,
  as `rules/decisions.md` says, and never reaches this repository.
- **A change** is described in `CHANGELOG.md` and `changelog.d/`.
  A record says why something was chosen over something else, not
  what changed.
- **A design issue** proposes. Its "Rejected" section is half a
  record, but issues close and are not searched by topic; the pull
  request that builds the design writes the record, and that
  section becomes its considered options. The same goes for a
  reason given only in a commit message or a pull request body.

## When a pull request needs one

Three questions, in this order:

1. **Could one pull request undo it?** Then no record. A line in
   the rule that governs the area is enough, and most decisions end
   here.
2. **Will somebody propose a rejected option again?** Then the full
   record. The paragraph on why the losing option lost is the only
   thing the long form buys.
3. **Otherwise the short record.** That is most of what gets
   written.

A decision the code alone would make look like an oversight — a
constraint from outside, something tried that did not work — earns
a record too. A decision nobody would be surprised by does not,
however carefully it was made.

A decision that still binds but was taken before these records
existed is written when it comes up, dated the day it is written;
its Context says when and where it was taken.

## The record

`docs/adr/YYYYMMDD-slug.md`, one decision per file, named by the
day it is first written, a date it keeps through an edit
(→ Superseding). Not a sequence number: two sessions working in
parallel would hand out the same one.

Its frontmatter is the template's below: `id` equals the file
name, and `status` is `proposed`, `accepted`, `rejected` or
`superseded`.

- **The title names the decision, not the topic.** "Windows Server
  as the only target", not "Windows support". Ten words at most.
- **Write what was true then, not what is true now.** A dated
  record whose context was quietly updated is worth nothing. The
  one edit allowed, to a record no release carries yet, is not
  quiet (→ Superseding).
- **Under a page.** A context that needs three pages is two
  decisions.

`scripts/decisions.py --check` holds each part to a word budget,
since padding goes to the same places every time:

| Part               | Short | Full                          |
| :----------------- | :---- | :---------------------------- |
| Title              | 10    | 10                            |
| Context            | 80    | 120                           |
| Decision drivers   | —     | 25 each, at most five         |
| Considered options | —     | 120 each, every live option   |
| Decision           | 30    | 60                            |
| Consequences       | 80    | 120                           |
| Confirmation       | —     | 60                            |
| The whole record   | 250   | 400, plus 150 for each option |

Frontmatter, headings and fenced blocks do not count. Over budget
on a short record means say less, or it needed the full template.

## Where the constraint goes

The constraint a record leaves is written into the file that
governs its area, wherever `.claude/rules/instruction-authoring.md`
→ Where a new instruction belongs puts it. Those files carry many
decisions each and describe the current state only, so none of them
gets a `Source:` line and a record has no `rule:` field: the
backlink checks in `scripts/decisions.py` have nothing to hold
together here. The record's Consequences name the file instead.

Nothing loads the records into a session on its own, and nothing
should: a superseded record would arrive with the standing ones.
The [index](adr/README.md) is what a session reads before it
changes a behaviour a record set.

## Status through a review

- A new decision enters its pull request as `proposed`. When the
  review settles it, a commit on the branch sets `accepted` or
  `rejected` and regenerates the index, before the squash.
- A rejected record still lands: it is what stops the same proposal
  coming back.
- A record merges as `proposed` only with `waiting-on:` naming what
  it waits for, and then on its own, without the change that
  depends on it.
- A decision already taken before it was written down enters as
  `accepted`.

## Superseding

A record is immutable except for two fields: `status` becomes
`superseded` and `superseded-by` names the new record. In one pull
request: the new record with `supersedes:` set, those two fields,
the governing file rewritten, and the index regenerated. Its
context says what changed since. There is no `deprecated`: a
decision dropped without replacement gets a new record saying so.

That holds once a finished release carries the record: a `vX.Y.Z`
tag reachable from `HEAD`, a pre-release not counted. Until then
the record is edited in place, in the pull request that changes the
decision. It keeps its file name and `id`, so links to it hold; its
context is written for the day of the edit, and says so. The
version it gives up becomes a considered option that lost, or a
sentence in a short record's context, so the proposal does not come
back.

A released record that was still `proposed` is settled the same
way it would have been before: `status` becomes `accepted` or
`rejected`, and `waiting-on` is emptied. Those are the only moves a
released record's fields make, besides the supersede: an `accepted`
one never becomes `rejected`, which would take it out of force with
no record saying why. `scripts/decisions.py
--check` fails on a released record that differs from its release
in more than `status`, `superseded-by` and `waiting-on`, or is
gone.

## The index

`docs/adr/README.md` is generated, never edited:

    python3 scripts/decisions.py --write

`scripts/check.sh` runs the same script with `--check`, which fails
on a stale index, a broken supersede chain or a record over budget.

## Templates

The short record:

```markdown
---
id: YYYYMMDD-slug
status: proposed
waiting-on:
tags: []
---

# {The decision, not the topic.}

## Context

{What forced a decision, and what was true at the
time. Not what the code says; the reader has the code.}

## Decision

{What we do, present tense.}

## Consequences

{What becomes easy, what becomes hard, and which
file carries the constraint.}
```

The full record, for a decision whose rejected option will come
back:

```markdown
---
id: YYYYMMDD-slug
status: proposed
supersedes:      # the record this one replaces, if any
superseded-by:   # filled in when this one is replaced
waiting-on:      # required while proposed: what it waits for
tags: []         # optional, for the index
---

# {The decision, not the topic.}

## Context

{What forced a decision, and what was true then.}

## Decision drivers

- {One line each, at most five: what actually decided it.}

## Considered options

### {Option A} — chosen

{What it is, then what speaks against it.}

### {Option B}

{What it is, and why it lost. One heading per
option that was really live.}

## Decision

{What we do, present tense.}

## Consequences

{What becomes easy, what becomes hard, and which
file carries the constraint.}

## Confirmation

{How we would notice this stopped holding. "Nothing
would tell us" is a valid answer.}
```
