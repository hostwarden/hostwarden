---
sidebar_position: 3
description: An always-on machine that runs the fleet's housekeeping
  unattended, with least-privilege access to every host.
---

# An operations host

An always-on machine — a small container or VM — can run the fleet's
housekeeping every night while your workstation sleeps, and mail you
one report. It is an operations checkout of its own that joined the
shared workspace, and it reaches your servers only through fleet
read (`hostwarden-fleet-read` skill): its key runs a bundle of
read-only checks you signed and writes one journal line, nothing
else. Not a shell, let alone root.

## What it needs from you

- An account without `sudo`, the `claude` CLI logged in, and a mail
  transport.
- `bin/hostwarden-init --clone <workspace remote>`, with a key that
  may push there.
- Its own `memory/user.md` (see below).
- `*` in its `memory/readonly.md`, so no session there changes
  anything, and a copy of your blacklist.
- The fleet key, made by you, and the key line on each server, added
  by you from what the skill writes out.

```
Operator: ops1
Report email: ops@example.com
Workspace push: always
Coordinator: off
```

`ops1` is the machine's own handle, which every journal line of the
nightly run carries — `[ops1 as root] read-only: housekeeping: …` —
so your colleagues can tell it from your own sessions. It is
reserved in `operators.md` as `ops1 (operations host)` — the session
that sets the machine up does that — and the nightly run refuses to
start until the reservation has been pushed. `Coordinator: off` keeps
the machine from starting a coordinator nobody needs there.

## Running the job

Then run `bin/hostwarden-fleet-run --no-judge` and `--dry-run` by
hand, and put it on a timer; the units are in the
`hostwarden-fleet-read` skill. Each night it updates Hostwarden,
pulls the workspace, reads every server, has Claude judge each
output without any tools, checks the hard thresholds itself, logs
one line per server, commits those changelog lines and pushes, and
mails the report. Its exit status is 2 when a CRITICAL is not
explained by the server's memory.

Anything else you run on that machine — a mailbox triage, a bot — is
yours, not Hostwarden's, and never gets the fleet key.
