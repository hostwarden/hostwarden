---
name: hostwarden-multi-host
argument-hint: "[all | hostname ...] <question, command or change>"
description: Run one question, command or change on several managed
  servers at once and report the answers grouped, so hosts that agree
  print once and the outlier stands out. Each host runs the full
  pipeline in its own subagent; a change asks once, names every host
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

One task, several hosts. `rules/multi-host.md` holds the procedure —
targets, dispatch, order, merging, the change rule. Read it first;
this is the workflow around it.

## Workflow

1. **Load overrides**, key `hostwarden-multi-host`, per
   `rules/overrides.md`.
2. **Targets**, as `rules/multi-host.md` → Targets says: the hosts
   named, or every known host for "all". New hosts get their first
   connection here before anything else.
3. **The task.** Decide the mode:
   - `read` — a question or a command that only inspects;
   - `skill` — housekeeping or a security audit;
   - `change` — anything that writes to a host.

   Then write the task and the shape of the answer, so every host
   answers alike: `kernel: <release>`, one line per mount as
   `<mount> <use%>`, `nginx: active|inactive|absent`. A command that
   differs by family is named by what it has to find, and each agent
   takes its family's form.
4. **A change** goes through `rules/multi-host.md` → Changes on
   several hosts before any agent starts: prepared here, one
   question naming every host and the canary, then the canary alone.
5. **Dispatch** as `rules/multi-host.md` → Dispatch and → Order say.
6. **Report** as `rules/multi-host.md` → Merging the answers says,
   and nothing around it (`AGENTS.md` → Talking to Humans). A change
   ends with one line per host it reached.
7. **Record.** Each agent wrote its own journal line, changelog and
   memory. Commit each host's paths as its agent returns, then push
   once (`rules/changelog.md` → The Workspace).

## Example

```text
❯ Which kernel runs on web1, web2, web3 and db1?

web1.example.com, web2.example.com, web3.example.com: 6.12.38+deb13-amd64
db1.example.com: 6.1.0-37-amd64
```
