---
sidebar_position: 6
description: How a choice you made about your servers is recorded, what
  it changes in audits, and how you retire it.
---

# Decisions

A decision records a choice you made about your servers, with the
reason: pve1 gets no local firewall, a key stays unrotated, the UniFi
devices get no SSO. Hostwarden then stops proposing what the decision
rules out, and flags a host that contradicts it.

```
 ❯ pve1 never gets a local firewall — the router guest filters
   everything, and rules on the bridges broke guest traffic.
```

## How one is made

- **Only your explicit word makes a decision.** Hostwarden never
  records one from a pattern it noticed. It offers to when you turn a
  proposal down with a reason, and writes on your yes.
- **It records who, when, why and what it covers:** one host, a
  cluster, or a group of hosts.
- **Only you retire one.** Say so, and Hostwarden deletes it, and the
  override that goes with it. The workspace's history keeps the old
  text. A `Revisit:` date brings it up once.

## What it changes

An audit shows the matching finding as decided instead of proposing it
again. In a housekeeping report:

```
Firewall   DECIDED — No local firewall (user, 2026-09-18)
```

A host that contradicts a decision that covers it is flagged. The
Critical Safety Rules cannot be decided away, just as they cannot be
overridden.

## Where it is written

| For                   | File                                     |
| --------------------- | ---------------------------------------- |
| One host              | `memory/machines/<hostname>/decisions.md` |
| A cluster             | `memory/clusters/<name>/decisions.md`    |
| A group, or all hosts | `memory/decisions/<name>.md`             |

```markdown
# Decisions — pve1.example.com

## No local firewall
- Decided: alice, 2026-09-18
- Why: the router guest filters everything; rules on the
  bridges broke guest traffic.
- Settles: baseline → Firewall; proposals to enable one
```

- **Longer reasoning** — the options you weighed, the numbers behind
  it — goes into a file beside the decision file, in a directory of the
  same name without `.md` (`machines/<hostname>/decisions/<name>.md`
  under `memory/` for a host), and the entry names it in a `Details:`
  line. Hostwarden reads it only when the decision is in question.
- **A group file** says which hosts it covers in its second line, never
  wrapped however long it gets: `Applies to: all`, a line from the
  hosts' memory (`Applies to: Appliance: Proxmox VE`), or a list
  (`Applies to: hosts web1.example.com, web2.example.com`).

## Decisions and overrides

A decision is not an override: it records a choice about your servers,
while an override changes what Hostwarden does. Where a decision also
has to change Hostwarden's behaviour, it gets an override too, whose
first line points back at it:

```
Decision: Reboots by hand only (decisions/databases.md)
```

The reason then stays in the decision
([Overrides](../running-it/tailoring/overrides.md)). The rules behind
it: `rules/decisions.md`.
