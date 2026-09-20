---
description: Take over an existing heinzel installation — memory, access lists, custom rules, and a per-host inventory of what heinzel left on the servers
argument-hint: "[path to the old heinzel checkout]"
---

Take over the heinzel installation at `$1` by following the
`hostwarden-adopt` skill in
`.agents/skills/hostwarden-adopt/SKILL.md`.

If no path was given, ask for it before doing anything else.

The skill is the source of truth for this workflow — this command
only starts it.
