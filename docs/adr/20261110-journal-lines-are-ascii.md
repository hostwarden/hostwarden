---
id: 20261110-journal-lines-are-ascii
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [journal, changelog, bsd]
---

# Journal lines are ASCII, with the reason after `; because`

## Context

2026-11-10. Every change is logged on the host with `logger -t
hostwarden`, and the next session's activity check reads those
lines back. The form joined the reason with a dash, `— because`,
and German operators wrote umlauts. A BSD syslogd stores each
non-ASCII byte as an escape, so the line read back differs from the
line written and a search for it finds nothing.

## Decision drivers

- An entry must be found by the same search on every host.
- The form is written by hand in many rules and skills.
- Entries in the old form exist on every managed host.

## Considered options

### ASCII only, `; because`, on every host — chosen

`ae oe ue ss` for umlauts, `-` and `->` for dash and arrow, the
reason after `; because`. Old entries with the dash are read as
before.

### ASCII only on BSD hosts

Linux journals keep UTF-8. Lost: one fleet, two forms, and a search
across hosts that has to know which host stores what.

### Keep the dash, decode on reading

Nothing changes for the writer. Lost: every reader has to undo an
escape whose form depends on the syslogd, and a line cut mid-escape
cannot be undone.

## Decision

Journal lines and the local changelog's copy of the headline are
ASCII, with the reason after `; because`, on every host.

## Consequences

`rules/changelog.md` carries the form and reads the old one. A
request for umlauts in the journal, or for the dash back, is the
moment to read this record.

## Confirmation

No test reads a journal line. `rules/changelog.md` carries the form;
review holds every rule and skill that writes a line to it.
