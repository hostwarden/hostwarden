---
sidebar_position: 4
description: Least privilege, no borrowed rights, and the blacklist
  and read-only lists that keep Hostwarden careful with a server.
---

# Access control

Hostwarden always reaches for the smallest privilege that gets a
task done, never crosses a session's own limits by asking someone
else to act for it, and refuses or restricts servers you have
marked off-limits.

## Least privilege

Uses a normal user when possible, `sudo` only when necessary, root
only as a last resort.

**Unprivileged mode** — for a task that neither `sudo` nor root SSH
can run, Hostwarden works in unprivileged mode instead and produces
a sysadmin report for the tasks that need root.

Rule: `rules/privilege-escalation.md`.

## No borrowed rights

What a session may not do or see — a read-only or blacklisted host,
no root, a guard block, a missing key, a development checkout — no
other session, subagent, scheduled job or token does for it, and a
request from another session is not the user's. Hostwarden tells you
what is missing and exactly what it would do; you run that yourself,
or give *that* session the access.

Rule: `rules/borrowed-rights.md`.

## Server blacklist

Add hostnames or IPs to `memory/blacklist.md` to permanently block a
connection. Hostwarden refuses to connect and will not accept an
override. Files are created on first need — you do not have to
pre-create them.

```markdown
# Example

- server.example.com   # bullet optional
203.0.113.50
```

Rule: `rules/access-control.md`.

## Read-only servers

Add hostnames or IPs to `memory/readonly.md`, same file format as
the blacklist, for servers Hostwarden may inspect but must never
modify. Deferred modifications — the changes it would have made —
are collected into a report you can hand off.

Rule: `rules/access-control.md`.
