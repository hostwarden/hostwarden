---
id: 20260924-deployed-file-masters-in-workspace
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [deployed-files, server-memory]
---

# A deployed file's master lives in the workspace

## Context

Decided 2026-09-23 in PR #172. Heinzel had improvised this under
its first host: a script or config a session wrote onto a server
existed only there, so a reinstalled host or a colleague reading
memory had no record of what was meant to be present, only
scattered `Deployed:` lines in `memory.md` with no drift record.

## Decision drivers

- The user wants the master of everything a session deploys kept in
  memory, not only on the host it was written to.
- A host gets restored, reinstalled or edited by a colleague; the
  workspace has to say what was meant to be there.
- Drift between the workspace and the host must be visible, never
  silently resolved.

## Considered options

### A fixed workspace location plus a per-host `deployed.md` — chosen

A file a session writes as a whole gets a master at a fixed
workspace location by what it is — a plain copy, a generated
artifact, one artifact shared by several hosts — mirroring the
host's own path where that applies. A per-host `deployed.md` records
each one's path, source, mode, owner, date and hash as deployed, and
the file itself carries a marker naming Hostwarden as its master.
Against it: every deploying path has to resolve which kind of master
a file is, instead of writing wherever is convenient.

### `Deployed:` lines in `memory.md` (Heinzel's improvised habit)

Note a deployment as a line in the host's free-form memory file.
Lost: a line has no source directory, no hash and no fixed home for
the actual bytes, so nothing could tell a host copy apart from
drift without opening the file itself.

## Decision

A file a session writes onto a host as a whole gets a master copy
at a fixed workspace location, tracked per host in `deployed.md`.
Where its format has comments, it carries a marker naming
Hostwarden as the master; drift is never resolved automatically.

## Consequences

`rules/deployed-files.md` carries the master locations, the
`deployed.md` schema and the drift rule; a session writing, editing
or removing such a file follows it. Adoption of files Heinzel left
in its own layout, and filtering automated watcher entries out of
the activity check, are tracked as separate follow-up work, not
part of this decision.

## Confirmation

A deployed file with no entry in `deployed.md`, or a proposal to go
back to a free-form memory line, is the moment to reread this
record.
