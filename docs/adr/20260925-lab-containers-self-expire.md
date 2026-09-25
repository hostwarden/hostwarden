---
id: 20260925-lab-containers-self-expire
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: []
---

# Lab containers self-expire; no SessionEnd hook

## Context

`bin/hostwarden-lab up`/`exec` start disposable containers and leave
them running until `down` removes them by hand; nothing else ever
stopped one, so a forgotten container ran indefinitely. A
`SessionEnd` hook that ran `down` on session end was built and
pushed first. Claude Code's `SessionEnd` does not reliably fire on
`/exit` or `/clear`, the two ordinary ways a session ends — only on
Ctrl-D (upstream issues #17885, #6428, both closed not-planned) — so
it left the common case unfixed. It is also fired per session, not
per container: two sessions sharing a checkout share one label, and
one session's `SessionEnd` could force-remove a container the other
was still using.

## Decision drivers

- `SessionEnd` does not fire on `/exit` or `/clear`, verified against
  two closed upstream issues, not assumed from the docs
- Cleanup keyed by checkout rather than by session risks one session
  destroying another's live container
- A container that outlives the checkout directory (removed after a
  merge) becomes unreachable by any tool, not just unstopped

## Considered options

### A fixed lifetime, engine-enforced — chosen

`up` runs the container's main process as `sleep $HOSTWARDEN_LAB_TTL`
(default 6h) instead of `tail -f /dev/null`; once it exits, the
engine's own `--rm` removes the container. Independent of Claude
Code entirely, of whether another session still uses the checkout,
and of whether the checkout still exists. Cost: a command still
running when the TTL elapses is killed with it, undocumented at the
time this record was written.

### A `SessionEnd` hook running `hostwarden-lab down`

Matches the container's lifetime to the session that started it,
when it fires. Lost because it does not fire on the two ordinary
ways a session ends, and because it is checkout-scoped rather than
session-scoped, so it can remove a container a second session in the
same checkout is actively using.

### An idle timeout keyed to last use

Would avoid killing a container mid-use, unlike a fixed lifetime.
Lost for now: doing it portably across six base images without a
dependency needs a marker file's mtime read back with `date` or
`stat`, whose flags differ between GNU, BSD and busybox — more
moving parts than a fixed sleep for a tool meant to be disposable.

## Decision

`bin/hostwarden-lab up` gives every container a fixed lifetime,
`HOSTWARDEN_LAB_TTL` seconds, enforced by the container engine's own
`--rm`, not by any Claude Code session hook.

## Consequences

A lab container is cleaned up regardless of how or whether the
session that started it ends. `exec` recreates one that expired, at
the cost of a moment's delay. A command still running when the TTL
elapses is killed with it; `bin/hostwarden-lab`'s own header carries
that constraint.

## Confirmation

If Claude Code's `SessionEnd` starts firing reliably on `/exit` and
`/clear`, nothing here would tell us — the TTL would keep working
alongside it. Revisit only if the fixed lifetime's mid-command kill
proves disruptive enough that an idle timeout is worth the added
complexity.
