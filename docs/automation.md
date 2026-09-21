# Automation and scripting

Running hostwarden without sitting at the prompt: one-shot
commands, fewer approval prompts, and scheduled runs.

## Command line interface

You can script Hostwarden from the command line without
entering the interactive UI.

### Claude Code

Use the `-p` flag to pass a prompt directly:

<details>
<summary>Example: find the OS, then upgrade Debian 11 to 12</summary>

```bash
$ claude --permission-mode auto \
  -p "What OS is installed on \
  server1.example.com? Login as root."
**server1.example.com** is running **Debian 11
(Bullseye)** on an aarch64 (ARM64) system with
4 CPU cores, 3.8 GB RAM, and a 15 GB root disk
(15% used).

Note: Debian 11 reached end of life in August
2024 and only receives long-term support (LTS)
until August 2026. You may want to plan an
upgrade to Debian 12 (Bookworm) before then.
$ claude --permission-mode auto \
  -p "Upgrade server1.example.com to Debian 12. \
  I have a backup. Don't ask me any questions. \
  Just do it. Give me a report afterwards."
---

## Upgrade Report: server1.example.com

**Debian 11 (Bullseye) -> Debian 12 (Bookworm)**
— completed successfully.

### What was done

1. **Verified Debian 11.11 was fully up to date**
   before starting
2. **Updated `/etc/apt/sources.list`** from
   `bullseye` to `bookworm` (backed up first)
3. **Ran `apt-get upgrade`** — installed packages
   that could upgrade without removals
4. **Ran `apt-get full-upgrade`** — completed the
   full dist-upgrade
5. **Cleaned up** — `autoremove` removed 28
   obsolete packages (410 MB freed)
6. **Rebooted** into the new kernel
   6.1.0-43-arm64
7. **Removed old kernel** 5.10.0-38-arm64
   (257 MB freed)
8. **Reinstalled `unattended-upgrades`** — it was
   dropped during the dist-upgrade

### Current state

|                         |                               |
| ----------------------- | ----------------------------- |
| **OS**                  | Debian 12.13 (Bookworm)       |
| **Kernel**              | 6.1.0-43-arm64                |
| **Disk**                | 15 GB, 19% used               |
| **nginx**               | running                       |
| **ufw**                 | active, default deny incoming |
| **unattended-upgrades** | installed and enabled         |
```

</details>

### OpenCode

Use the `run` command to pass a prompt directly:

```bash
opencode run "What OS is installed on \
  server1.example.com?"
```

Useful flags for scripting:

- `--format json` — machine-readable JSON output
- `-m provider/model` — override the model
- `-f file.txt` — attach files to the prompt
- `-c` — continue the previous session

For repeated calls without startup overhead, use the
headless server:

```bash
opencode serve
opencode run --attach http://localhost:4096 \
  "Check disk usage on web1.example.com"
```

## Fewer prompts: auto mode (Claude Code)

By default Claude Code asks for your approval before
every tool call — every SSH command, every file read,
every write. That's the safest setting and the right
one when you're learning. But for batch work it gets
impractical: you can't sit and approve 200 prompts
during an unattended upgrade.

For that, use **auto mode**
(`--permission-mode auto`). Instead of asking you
about everything, a background safety check reviews
each action: routine commands run without a prompt,
risky ones still stop and ask. Press Shift+Tab in the
interactive UI to cycle modes, or pass the flag for
scripted use:

```bash
claude --permission-mode auto \
  -p "Run housekeeping on server1.example.com"
```

(Auto mode is a newer Claude Code feature — on
Team/Enterprise plans an admin may need to enable
it. See the
[permission modes docs](https://code.claude.com/docs/en/permission-modes)
for details and alternatives.)

For locked-down scripting and CI, the strictest
option is an explicit allowlist:
`--permission-mode dontAsk` combined with
`--allowedTools` or `permissions.allow` rules in
`.claude/settings.json` — only pre-approved commands
run, everything else is denied.

The old `--dangerously-skip-permissions` flag still
exists, but the name says it all: it removes *all*
review with no safety check in its place — including
any protection against malicious text in server
output. If you use it at all, use it only in
disposable environments (dev VMs, containers), never
on production servers.

**When to stay with the default ask-everything mode:**

- First time working on a production server
- When you don't trust Hostwarden or don't understand it
- Any time you want to understand what's happening
  step by step

Whatever mode you pick, Hostwarden's own safety rules
still apply — Hostwarden still backs up configs, tests
before applying, asks before destructive actions, and
follows least privilege. Permission modes only change
how often *you* are asked, not the built-in
guardrails.

## Scheduled housekeeping

Auto mode makes recurring, unattended health checks
practical — a nightly housekeeping run that emails
you the report:

```
17 6 * * * cd /path/to/hostwarden && flock -n \
  /tmp/hostwarden-cron-server1.lock timeout 30m \
  /abs/path/to/claude --permission-mode auto \
  -p "Run housekeeping on server1.example.com and \
email me the report" >> ~/hostwarden-cron.log 2>&1
```

Two rules: run the exact prompt **interactively
once** first, so the email recipient, sending path,
and other one-time questions are answered and stored
in memory (unattended runs can't answer pickers) —
and **never use `--dangerously-skip-permissions` in
cron**. Details, systemd-timer variant, and cron
pitfalls:
`.agents/skills/hostwarden-housekeeping/references/scheduled.md`.
