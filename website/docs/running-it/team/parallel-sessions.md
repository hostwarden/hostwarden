---
sidebar_position: 2
description: Sessions that see each other on the same host, steps
  that reach other hosts, and the coordinator that tracks them.
---

# Parallel sessions

Sessions that change the same host — two windows, or teammates on
different workstations — see each other. Before its first change a
session registers on the host itself, in `/tmp/hostwarden/` (no root
needed), with who it is, where it runs and what it is doing. Another
live entry makes Hostwarden say so and ask whether the two get in
each other's way; a session on the same machine can be messaged
directly, to share what each has seen, never to have one do what the
other may not. Sessions that only read — housekeeping, audits —
register nothing.

## Steps that reach other hosts

A reboot, a firewall or network change or a restart reaches more
than its own host: the guests of a hypervisor, the hosts behind a
jump host, the hosts that use a service it runs. Before such a step
a session announces it; the sessions on this machine that work on a
host it reaches are named, the ones changing something there get up
to two minutes to reach a safe point, and you decide whether to go,
wait or stop. A session that then reaches one of those hosts is told
once what is going on.

## In a team

In a team — two or more people in `operators.md`, not counting a
handle marked `(inactive since …)` or `(operations host)` — the
announcement also goes onto each host it reaches, as a register
entry and a journal line, so your colleagues' sessions see it too.
Alone, with or without a shared workspace, nothing is written on
other hosts.

## The coordinator

The first session in an operations checkout starts a coordinator in
the background, one per checkout, and says so in one line. It keeps
track of which session works on which host, asks a session what it
is doing when it moves on to other hosts, passes an announced step
on to the sessions it concerns, keeps an order of steps that spans
sessions, and warns about maintenance windows. It never reaches a
server and never decides anything for you or another session.

`claude agents` lists it as `hostwarden coordinator`. To turn it off,
run `/hostwarden-coordinator` in any session: it stops the
coordinator and writes `Coordinator: off` into your `memory/user.md`,
so the next session does not start it again. The same skill removes
the line and starts one when you want it back.
