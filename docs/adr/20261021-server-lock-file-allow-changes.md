---
id: 20261021-server-lock-file-allow-changes
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [safety, access-control, guard]
---

# A host locks itself with allow_changes in its own file

## Context

Heinzel added a lock the machine's owner sets on the machine:
`allow_changes = false` in `/etc/heinzel.conf` puts every connecting
agent into read-only mode (Heinzel 3.1.1).
Hostwarden's lists live on the operator's workstation and bind only
that workstation. Hosts that Heinzel also manages must stay locked
whichever of the two tools connects.

## Decision drivers

- A lock must hold for a Heinzel installation that still manages the
  host.
- Unreadable, empty or odd input must lock, never unlock.
- A host without `sh` must not lock for want of a marker.

## Considered options

### `allow_changes` in `/etc/hostwarden.conf` or `/etc/heinzel.conf` — chosen

The key and the `key = value` form are Heinzel's, so one file serves
both tools. Either file locks; a value other than `true`, an empty
file or a missing end marker locks too. The guard denies a write to
both names under every spelling. Against it: Hostwarden reads a
file named after its predecessor.

### Only `/etc/hostwarden.conf`

Lost: a host locked for Heinzel would not be locked for Hostwarden,
and the owner would have to know which tool connects.

### Heinzel's probe as it is

Lost: it proves a read by an end marker printed by `sh`. Windows
and DrayOS print none, so every such host would lock, or the check
would be skipped silently.

## Decision

The lock is `allow_changes = false` in either file, read in the
activity check's call on every `sh` family and in local mode.
Windows is read-only anyway and DrayOS has no shell: both are
reported as not read. Hostwarden never writes, moves or deletes
either file, and the legacy cleanup and rename leave them alone.

## Consequences

The lock is cooperative, not a security boundary. The guard matches
the file name alone, so a write to any file of that name in the full
scope is denied, and a glob or a name built at run time gets
through. `rules/access-control.md` → Server Lock holds the
constraint.

## Confirmation

`tests/hooks/guard-taboos/lock.sh` and the file-tool fixtures in
`edit.sh`; the probe block of `rules/access-control.md` runs through
the instruction-block matrix.
