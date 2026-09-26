---
sidebar_position: 5
title: To-do lists and plans
description: How unfinished work survives an interrupted session, and
  how work across several sessions is planned.
---

# To-do lists and plans

Two files keep unfinished work visible: a to-do list for the steps of
one session, and a plan for work that runs over several.

## A session's to-do list

For any task of two or more steps, Hostwarden keeps
`memory/machines/<hostname>/todo.md` and ticks each step the moment it
is done, not at the end — so an interrupted session leaves behind what
was really done.

```markdown
- [x] Snapshot guest 101 before the upgrade
- [x] Upgrade Debian 12 → 13 on web1.example.com
- [ ] Check that nginx and the app come back
- [ ] delete snapshot pre-upgrade on pve1.example.com
```

The next connection to the host shows the open items before new work.
An item with a due time waits silently until then:

```markdown
- [ ] First run of db-dump.timer after rename, due 2026-09-21 03:00
```

The connection that finds it due checks the result and ticks it. Once
everything is done, the file is deleted.

## Plans that outlive a session

Work that spans sessions — a rollout in phases, a migration with
decisions still open, a change on many hosts — gets a plan in
`memory/plans/<slug>.md`. It holds what a checklist cannot: the goal,
the decisions taken and why, the phases, and what is next. It opens
with the hosts it touches and where it stands:

```markdown
# Syslog collector for all sites
- Hosts: log1.example.com, fw1.example.com,
  pve1.example.com
- Status: phase 2 of 4 — collector runs, forwarders
  pending
- Updated: 2026-09-17
```

Each host it touches points to it from its `memory.md`:

```markdown
- Plan: syslog-collector (memory/plans/syslog-collector.md)
```

- **The next phase never starts unasked.** A session working on one of
  those hosts reads the plan when its work touches what the plan
  covers.
- **When it is done,** its facts move into the hosts' memory, what you
  decided and still holds becomes a [decision](decisions.md), and the
  plan and its `Plan:` lines are deleted.
- **A rollout on several hosts** is written down this way until every
  host is done, so a later session can finish it
  ([One task on many hosts](../features/fleet/multi-host.md)).

## Maintenance windows

A planned downtime is a plan of the same kind, with the window, what it
reaches and who has to be told by when above its steps:

```markdown
# pve1 kernel update
- Hosts: pve1.example.com
- Window: 2026-10-05 22:00–23:30 Europe/Berlin
- Kind: reboot
- Affected: web1.example.com, db1.example.com (radius of 2026-09-24)
- Notify by: 2026-09-28 (shop customers, 7 days)
- Status: planned
- Updated: 2026-09-24
```

Every affected host gets a `Downtime:` line, which the recent-activity
summary names on each connection until the plan is done
([Planning a maintenance window](../features/fleet/maintenance-windows.md)).
