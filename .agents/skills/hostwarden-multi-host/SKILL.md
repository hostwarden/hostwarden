---
name: hostwarden-multi-host
argument-hint: "[all | hostname ...] <question, command or change>"
description: Run one question, command or change on several managed
  servers at once and report the answers grouped, so hosts that agree
  print once and the outlier stands out. Each host runs the full
  pipeline, all hosts in one call per round; only a skill on many
  hosts or a large change goes to subagents; a change asks once,
  names every host
  and goes to a canary first. Use when the user names two or more
  servers, or all of them, for one task — "which kernel runs on web1,
  web2 and web3?", "check disk space on all servers", "is nginx
  running everywhere?", "roll this config out to the web servers",
  "run housekeeping on web1 and db1", "welcher Kernel läuft auf
  allen Servern?", "prüf auf allen Servern, ob nginx läuft", "spiel
  die Änderung auf allen Webservern aus", "mach Housekeeping auf web1
  und db1". Not for one server, not for the fleet audit
  (hostwarden-fleet-audit), and not for copying files between hosts.
---

# hostwarden-multi-host

One task, several hosts.

## Workflow

1. **Load overrides**, key `hostwarden-multi-host`, per
   `rules/overrides.md`.
2. **Follow `rules/multi-host.md`** from its first section to its
   last: targets, the task and its answer's shape, the change rule
   where the task writes, dispatch, and the merged answers.
3. **Report** as that file → Merging the answers says, and nothing
   around it (`AGENTS.md` → Talking to Humans).

## Example

```text
❯ Which kernel runs on web1, web2, web3 and db1?

web1.example.com, web2.example.com, web3.example.com: 6.12.38+deb13-amd64
db1.example.com: 6.1.0-37-amd64
```
