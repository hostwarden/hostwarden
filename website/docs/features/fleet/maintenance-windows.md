---
sidebar_position: 3
description: Plans a disruptive step ahead of time, with who needs
  telling and by when.
---

# Planning a maintenance window

Plan a disruptive step ahead of time, with who needs telling and
by when.

```
 ❯ Plan pve1's kernel update for next week
 ❯ When should pve1's update happen?
```

Hostwarden runs the same radius as [what a reboot would
hit](impact.md), reads every `Downtime notice:` inside it for the
audience and lead time, and proposes a window: it says whether the
update must, should or can happen sooner, from any pending reboot,
the longest lead time in the radius, and the host's own
automatic-restart slot. Once you pick a window, it writes a plan
in `memory/plans/` with the steps, the radius, the notify-by date
and the rollback, and each affected host gets a `Downtime:` line —
nothing runs yet. Asked later ("run plan pve1-kernel"), Hostwarden
re-reads the radius, shows what changed, and puts the steps to you
once more before running them. It also writes a short notice for
other admins — three lines to paste into chat, or a fuller email —
and records automatic reboots and restarts a host would do on its
own, so a slot nobody planned still shows up as a known one.
