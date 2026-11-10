---
id: 20261110-macos-cleanup-trash-only-never-root
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [macos, cleanup, privileges, skills]
---

# The macOS cleanup moves to the Trash, never as root

## Context

2026-11-10. `hostwarden-macos-cleanup` finds what removed apps left
in `~/Library` and `/Library`. Whether an entry is a leftover is
judged from names, bundle identifiers and code signatures, which is
a lead and can be wrong: a shared vendor folder, a helper another
app still loads. Half of the places are owned by root.

## Decision drivers

- A wrong match must be undone by the user without a backup.
- A Mac is its owner's machine; their data sits beside the entries.
- An agent removing files as root under `/Library` has no way back.
- The scan has to be useful on a read-only host.

## Considered options

### Trash only, as the user, root entries handed over — chosen

The scanner reads and prints. Confirmed entries move to the user's
Trash; what needs an administrator is returned as a command block
the user runs.

### Delete with `rm -r` after confirmation

Frees the space at once. Lost: the way back for a match that was
wrong, and the Trash's own "Put Back".

### Use sudo for `/Library`

One run does everything. Lost: least privilege; a mistaken path as
root reaches every user of the Mac.

## Decision

The skill moves confirmed entries to the Trash as the logged-in
user, never deletes, and never uses root.

## Consequences

Space is free only once the user empties the Trash, and the report
says so. `references/removal.md` carries the move and the handed
over blocks. A request to have the skill delete directly, empty the
Trash on its own or run through sudo is the moment to read this
record.

## Confirmation

`tests/skills/hostwarden-macos-cleanup/test_scan.py`, run by
`scripts/check.sh`, holds the scanner to reading and printing.
Review holds `references/removal.md` to the Trash and the handed
over command blocks.
