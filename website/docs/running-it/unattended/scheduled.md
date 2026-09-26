---
sidebar_position: 2
description: A recurring, unattended housekeeping run that emails you
  the report.
---

# Scheduled housekeeping

Auto mode makes recurring, unattended health checks practical — a
nightly housekeeping run that emails you the report:

```
17 6 * * * cd /path/to/hostwarden && flock -n \
  /tmp/hostwarden-cron-server1.lock timeout 30m \
  /abs/path/to/claude --permission-mode auto \
  -p "Run housekeeping on server1.example.com and \
email me the report" >> ~/hostwarden-cron.log 2>&1
```

This runs on your workstation. An always-on machine that should do
it for the whole fleet while the workstation sleeps is an operations
host instead, with its own least-privilege access
([An operations host](../team/operations-host.md)).

Two rules: run the exact prompt **interactively once** first, so the
email recipient, sending path, and other one-time questions are
answered and stored in memory (unattended runs can't answer pickers)
— and **never use `--dangerously-skip-permissions` in cron**.
Details, systemd-timer variant, and cron pitfalls:
`.agents/skills/hostwarden-housekeeping/references/scheduled.md`.
