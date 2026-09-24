---
id: 20260924-decisions-scoped-not-overrides
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [decisions, memory]
---

# Operator decisions are scoped entries, not overrides

## Context

Decided 2026-09-23 while designing `rules/decisions.md`. A host's
firewall choice existed only as a fact plus an override, with no
reason and no link between the two; nothing stopped a future
session proposing it again, and nothing explained why the override
was there. Two other layouts survived to round 3 of review before
being dropped: reading overrides before the decision files load,
and naming every matching host on its own line instead of a
selector.

## Decision drivers

- An override with no reason attached looks like an oversight to a
  later review or session, not a choice.
- A decision must stop a proposal and settle an audit finding on
  its own, before any override exists for it.
- Retiring a decision must leave nothing to filter around later,
  not a status to check.

## Considered options

### Scoped decision files with an `Applies to:` selector — chosen

One file per scope (host, cluster, group or fleet) holds one `##`
entry per decision: who decided it, why, and what it settles. A
group or fleet file names its match with a single `Applies to:`
line — `all`, a memory field, or a host list. The decision alone
stops proposals and rates a matching finding `DECIDED`; an override
is written only where a procedure changes, and points back with
`Decision:`. Every connection reads all of them at pipeline step 6.
Against it: two files can disagree for the same host, so precedence
has to be resolved by scope.

### Reading overrides before step 6

Apply `memory/custom-rules/` earlier in the pipeline, before the
decision files load. Dropped in round 3: nothing before step 6 has
read the decision an override is supposed to point back to, so
there is nothing yet to verify it against.

### One host named per line instead of a selector

Write every matching host out in the group file, instead of an
`Applies to:` field. Dropped in round 3: it does not scale past a
handful of hosts, and drops the reason a group or fleet scope
exists — matching hosts by what they are, not by an enumerated
list.

## Decision

A decision is one `##` entry in the file its scope picks — a
host's, a cluster's, or a `memory/decisions/` file chosen by
`Applies to:`. It alone stops proposals and settles findings; an
override exists only where a procedure changes, and names the
decision with `Decision:`. Retiring one deletes the entry and any
override naming it, and logs the removal.

## Consequences

`rules/decisions.md` carries the scopes, the entry format, the
`Applies to:` selector and the step-6 read order; `rules/overrides.md`
→ An override for a decision carries the `Decision:` pointer.
`rules/server-memory.md` documents which memory files are personal
versus shared. A design in flight at the time (#172, plan text
pointing at findings) needed a small follow-up once both landed, to
point at `rules/decisions.md` instead.

## Confirmation

An override with no `Decision:` line pointing at anything, or a
decision entry nobody can find a live reason to keep, is the moment
to reread this record.
