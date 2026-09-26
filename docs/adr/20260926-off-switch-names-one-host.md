---
id: 20260926-off-switch-names-one-host
status: accepted
waiting-on:
tags: [guard, taboos]
---

# The guard's off switch names one host

## Context

Issue #410, from the best-practices review of 2026-09-25: set to
`1`, the taboo guard's off switch let every taboo through for every
host and local mode. A session reinstalling one host had no hook
between a mistyped hostname and another host's disks. Break-glass
good practice (ISO/IEC 27001 A 8.32, BSI OPS.1.1.2) bounds such a
right to the target system. Julian decided on 2026-09-25 to settle
the value before v1.0.0, and on 2026-09-26 to build it as the issue
specified.

## Decision

The value is one hostname, or `localhost`. `1` or a list is
refused. The guard drops only what `hostwarden_coord_rest` reads as
aimed at that host and judges the rest.

## Consequences

A destination the reader cannot see — a variable, a script, a
via-host guest — stays guarded: the safe direction, and the
accepted gap of `20260924-guard-is-a-backstop-not-a-sandbox`. A
hostname keeps local commands and edits guarded, a local
redirection of an ssh call included. A guest whose disk is written
from its hypervisor takes the hypervisor's name.
