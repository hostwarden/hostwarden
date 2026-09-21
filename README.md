# Hostwarden — System Administration with Safety Guardrails

Hostwarden is a set of rules that turns an AI coding
assistant into a cautious, methodical sysadmin. It
works with
[Claude Code](https://docs.anthropic.com/en/docs/claude-code),
[OpenCode](https://opencode.ai), or any other
terminal-based AI tool that can read project files
and run shell commands. It manages Linux, FreeBSD,
and macOS targets — remote servers over SSH and the
local machine alike — and runs on any workstation
where your AI tool runs, including Windows (via WSL
or natively).

Describe what you need in plain English, and Hostwarden
figures out the right commands for your OS, proposes
each one with an explanation, and waits for your
approval before running anything. It backs up configs,
tests commands before real execution, remembers every
server it has worked on, and gives you a detailed
report when it's finished.

Using it feels like pair-programming with a colleague
who always checks the docs first and never skips a
step because he's in a hurry. The bigger the network,
the more it pays off — Hostwarden remembers every server's
OS, services, and quirks so you don't have to. Not
sure yet? Ask Hostwarden to plan first before making
changes — no changes until you say go.

hostwarden continues
[heinzel](https://github.com/wintermeyer/heinzel) by
Stefan Wintermeyer as an independent project. It keeps
heinzel's history and still takes over heinzel's
improvements where they fit. Coming from heinzel? See
[Moving over from heinzel](#moving-over-from-heinzel).

## Screencast: Debug and fix some webserver problems

![Screencast: Debug and fix some webserver problems](assets/webshop-bugfix-example.gif)

Recorded with heinzel, before the rename — a
hostwarden session looks the same.

## How to Install

### Prerequisites

- **An AI coding assistant** that runs in the
  terminal — e.g.
  [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  or [OpenCode](https://opencode.ai).
- **SSH access** to the target server — either as a
  normal user or as root. The SSH connection must
  not prompt for a password or passphrase (use
  key-based authentication without a passphrase).
  This is not needed for local administration
  (localhost / your own machine).

  Hostwarden shares one SSH connection per host and
  keeps it open for 10 minutes after the last call.
  The sockets live in `~/.cache/hostwarden` (mode 0700),
  so any process of your local user can use an open
  connection without asking for the key again.

  Quick setup: generate a key with `ssh-keygen`,
  copy it to the server with `ssh-copy-id user@host`,
  and test with `ssh user@host`. See the
  [Arch wiki SSH keys guide](https://wiki.archlinux.org/title/SSH_keys)
  for details.

- Linux (any distribution), FreeBSD, or macOS on the
  target machines. All supported systems can also be
  managed locally without SSH.
- **A checkout that supports symbolic links.**
  Hostwarden uses them in two load-bearing places:
  `.claude/skills` links to `.agents/skills/`, and
  DNS aliases become symlinks under
  `memory/servers/`. Git, macOS, Linux, FreeBSD and
  WSL do this out of the box. Native Windows needs
  Developer Mode (or an elevated shell) plus
  `git config --global core.symlinks true` *before*
  cloning; a checkout made without it turns every
  link into a text file, and hostwarden then has no
  skills and no alias resolution.
  A session-start hook says so whenever the skills are
  out of reach, because a session without them is
  otherwise silent about it;
  `sh .claude/hooks/instructions-test.sh` reports the
  state at any time.
- **Workstation:** Hostwarden itself runs wherever
  your AI tool runs — Linux, macOS, FreeBSD, or
  Windows. On Windows, the recommended path is
  [WSL](https://learn.microsoft.com/windows/wsl/)
  (full Linux environment). You can also run
  natively via
  [Git for Windows](https://gitforwindows.org/) —
  launch Claude Code or OpenCode from the bundled
  Git Bash terminal so the SessionStart
  auto-update hook and `bin/hostwarden-*` scripts can
  execute. PowerShell and `cmd.exe` are not
  supported as the launch shell.

### Steps

1. **Clone the repo and start hostwarden**
   ```
   git clone https://github.com/jpawlowski/hostwarden.git
   cd hostwarden
   claude
   ```
   Or use `opencode` to launch OpenCode.
2. **Describe what you need in plain English**
   ```
   ❯ Install postgresql on server1.example.com
   ```
3. **Answer a few questions on the first connection**
   The first time Hostwarden connects to a new server,
   it may ask for details it can't detect on its own
   — most commonly which SSH user to log in as. Your
   answers are stored in `memory/user.md` and the
   per-server memory file, so Hostwarden won't ask again
   on future sessions. You can also pre-fill
   `memory/user.md` by copying `memory/user.md.example`
   and editing it — this is also where you set a
   preferred language (e.g. `Language: German`).
4. **Review and approve each command before it runs**
   Hostwarden proposes every SSH command, explains what
   it does and why, and waits for your approval.
   Nothing runs without your say-so.

### Team setup

Hostwarden supports team use where multiple people share
server state via git while keeping SSH usernames
personal.

1. Each team member copies `memory/user.md.example`
   to `memory/user.md` and sets their own SSH
   usernames. This file is always gitignored.
2. Edit `.gitignore` to track server memory — the
   comments in the file explain which lines to
   comment out.
3. If any team member uses hostwarden locally (on their
   own machine), add their machine's hostname
   directory to `.gitignore` (e.g.
   `memory/servers/my-laptop/`).
4. Commit server memory changes after sessions so the
   team stays in sync.

## Updates & Versioning

Hostwarden uses [semantic versioning](https://semver.org).
The current version is in the `VERSION` file; changes
are listed in `CHANGELOG.md`.

**Auto-update (Claude Code):** On every session start,
a hook runs `git pull` and reports version changes.
No action needed. Auto-update is skipped when pinned
to a tag (see below), when on a non-`main` branch, or
when `HOSTWARDEN_NO_UPDATE=1` is set.

**Manual update (OpenCode / any tool):**

```bash
bin/hostwarden-update           # pull latest
bin/hostwarden-update --check   # check without pulling
```

**Pin to a stable version** (skip auto-updates):

```bash
bin/hostwarden-update --pin vX.Y.Z   # pin
bin/hostwarden-update --unpin        # back to main
```

**Opt out of auto-update** without pinning:

```bash
export HOSTWARDEN_NO_UPDATE=1
```

### Moving over from heinzel

hostwarden is a new clone, not an update of your
heinzel checkout. Your state moves with the backup
script, which both projects share:

```bash
cd /path/to/heinzel && bin/heinzel-backup
cd /path/to/hostwarden && \
  bin/hostwarden-backup --restore /path/to/heinzel-backup-<host>-<ts>.tar.gz
bin/hostwarden-migrate
```

The migration renames skill overrides in
`memory/custom-rules/` from `heinzel-<skill>.md` to
`hostwarden-<skill>.md`. What else changed:

- Environment variables are now `HOSTWARDEN_*`.
  `HEINZEL_NO_UPDATE` still works; the guard only
  honours `HOSTWARDEN_GUARD_DISABLE`.
- New journal entries on your servers use the tag
  `hostwarden`. The activity check reads `heinzel`
  entries as well, so earlier work stays visible.
- Point hostwarden at your old checkout — "my
  heinzel is in ~/heinzel, take it over", or
  `/hostwarden-adopt ~/heinzel` in Claude Code. The copy
  itself is a script — `bin/hostwarden-adopt <path>`
  moves access lists, custom rules and every server's
  memory across and renames what is found by name.
  The skill then reads your memory files and
  changelogs into a per-host list of leads: the
  scripts, configs, units and cron jobs your sessions
  improvised. Neither contacts a server.
- Keeping heinzel around during the switch?
  `contrib/heinzel-coexistence/` holds three custom
  rules for your heinzel checkout so it reads both
  journal tags, treats its server memory as a lead
  rather than a fact, and leaves hostwarden's files
  alone. hostwarden warns in the other direction when
  a heinzel journal entry is minutes old, and leaves
  a host alone that heinzel still uses.
- On the first connection to a host, hostwarden
  reports what heinzel left there — config backups,
  scratch directories — and offers to move it under
  the new name. It asks first, and it says which old
  backups the retention cleanup would then delete.
  New config backups go to
  `/var/backups/hostwarden/`.
- SSH sockets live in `~/.cache/hostwarden`.
- Scheduled runs (cron, systemd timers) need the new
  path and script names.
- heinzel's version tags are not carried over.
  `--pin` only knows hostwarden releases.

## Backup & Restore

Hostwarden keeps all your personal state under a
single directory — `memory/` — so backups are one
`tar` command. The tree is text and typically well
under a megabyte. No database, no hidden dotfiles,
no scattered config.

### What lives in `memory/`

- `user.md` — SSH usernames and language
  preference
- `blacklist.md`, `readonly.md` — access policies
- `service-policy.md` — per-service opt-out /
  opt-in for auto-reload and auto-restart
- `servers/<hostname>/` — per-server memory,
  changelog, todo, and per-server rule overrides
- `custom-rules/` — your global rule overrides
- `opencode.json` — your OpenCode config
- `network.md`, `housekeeping.md` — cross-server
  facts and custom checks

### Back up

```bash
bin/hostwarden-backup
```

Writes
`hostwarden-backup-<hostname>-<timestamp>.tar.gz` to
the current directory. Use `--list` for a dry run,
`-o <path>` to write somewhere specific.

### Restore

```bash
bin/hostwarden-backup --restore <file.tar.gz>
```

Refuses to overwrite existing `memory/` content
unless `--force` is passed. The archive is validated
before any files are written: all entries must live
under `memory/`, and symlink or hardlink entries are
rejected.

### Team mode note

In team mode, `memory/servers/`, `memory/network.md`,
`memory/housekeeping.md`, and
`memory/custom-rules/` are shared via git already.
But `memory/user.md`, `memory/blacklist.md`,
`memory/readonly.md`, and `memory/opencode.json`
are always personal and still need this backup.

## Features

### Auto OS-detection

The first time you point Hostwarden at any machine, it
detects the OS, gathers hardware info, and remembers
everything for future sessions.

### DNS alias detection

When multiple DNS names point to the same server,
Hostwarden detects this automatically by comparing IP
addresses. The first hostname becomes the canonical
name; additional names become symlinks that share the
same memory. Each alias can have its own SSH user.

### Memory across sessions

After working on a machine, Hostwarden remembers it.
Next week you start a new session and type:

```
 ❯ Check on web1.example.com.
```

It reads
`memory/servers/web1.example.com/memory.md`, already
knows it's Debian 12 with nginx and PostgreSQL,
checks the local changelog, and picks up right where
it left off.

### Session to-do list

When a multi-step task gets interrupted — connection
drop, conversation ends, laptop closes — Hostwarden
keeps a to-do list in
`memory/servers/<hostname>/todo.md` with checkboxes
for each step. On reconnection it shows what's still
pending and asks whether to continue or start fresh.

### Housekeeping checks

Run routine health inspections on any server:

```
 ❯ Run housekeeping on app.example.com
```

Hostwarden checks disk, memory, load, pending updates,
firewall, SSL certificates, failed services, and
server-specific services. Problems are highlighted
at the top of a concise report.

### Security audit

Check security configuration on any server:

```
 ❯ Run a security audit on app.example.com
```

Hostwarden checks SSH password authentication settings,
firewall status, and reports issues by severity.

### Fleet audit

Compare key policies across every server Hostwarden knows about:

```
 ❯ Run a fleet audit
 ❯ Vergleiche die Policies auf allen Servern
```

Hostwarden probes unattended-upgrades, sshd effective config,
firewall posture, MTA, time sync, and auto-reboot behaviour
on each host in `memory/servers/`, then renders a
side-by-side table that highlights where servers disagree.
It makes no configuration changes on any host (it only
writes one audit-trail line to each journal). Use it after
fixing a config bug on one server to find which others
carry the same bug, or as a periodic consistency check.

### Email reports

Send ad-hoc text or files by email about a managed server:

```
 ❯ Email me the output of "df -h" from app.example.com
 ❯ Mail /var/log/auth.log to ops@example.com
```

The first email per host asks once where to send from
(local workstation or the server itself) and remembers the
answer. On the remote path Hostwarden prefers an existing MTA
(postfix, sendmail, msmtp, mail/mailx) and asks before
installing one. Sends as a non-root user when possible.
Attachments check sender readability, file size, and offer
a content preview before sending.

Every message closes with a two-line greeting from Hostwarden
(`Viele Grüße / Hostwarden`) followed by a short signature
naming Hostwarden, the project URL, and the operator who
requested the send. The operator name comes from
`Operator name:` in `memory/user.md` (with a sensible
fallback chain to git config and the system full name).
Set it once; edit it any time. Both lines are
overridable: a `Greeting:` line in `memory/user.md` or
`memory/servers/<host>/memory.md` replaces the default
wording.

Every Hostwarden email also carries the RFC 3834
`Auto-Submitted: auto-generated` header plus
`Precedence: bulk` and `X-Auto-Response-Suppress: OOF,
AutoReply`, so out-of-office and vacation auto-replies
do not fan back at the operator.

### Plan mode (Claude Code)

For complex or unfamiliar tasks, switch to plan mode
before touching anything:

```
 ❯ /plan Migrate the database from MySQL to
   PostgreSQL on db.example.com
```

Hostwarden explores the server, checks what's running,
reads configs, and drafts a step-by-step plan — but
makes no changes. You discuss the approach, adjust
it, and only when you approve does execution begin.

> **Note:** The `/plan` command is a Claude Code
> feature. OpenCode does not have an equivalent —
> simply ask Hostwarden to plan before acting.

### Local administration

Hostwarden also works on the local machine — no SSH
needed, commands run directly. The same safety rules,
memory, and guardrails apply whether the target is a
remote server or your own laptop.

This works on both Linux and macOS:

```
 ❯ Update all Homebrew packages on this Mac
```

```
 ❯ Check if the firewall is configured on
   this machine
```

## Supported AI Tools

Hostwarden targets Claude Code. Its instruction set is
plain Markdown in the places the wider convention has
settled on, so other tools get most of it for free.
`AGENTS.md` is read by Claude Code, OpenCode, Codex and
Cursor alike, and the `rules/` files are reached by name
from it. Any terminal AI tool that reads project files
and runs shell commands handles the rule layer.

The skills differ by tool. OpenCode, Codex and Cursor
read `.agents/skills/` directly; Claude Code searches
`.claude/` only, and finds them through the
`.claude/skills` symlink — which is why that link is a
prerequisite and not a convenience. Do not remove it
thinking `.agents/skills/` covers Claude Code too; a
checkout without it has no skills at all and says
nothing. On a tool with no Skills support, ask for those
workflows by naming the file —
`.agents/skills/<name>/SKILL.md`.

What is Claude Code only: the taboo guard hook and the
repo conventions in `.claude/rules/`. Elsewhere the
prose rules are the entire safety layer. The fleet
audit's per-host subagents are a capability, not a
brand: a harness that can run agents or parallel tool
calls fans out the same way, and one that cannot walks
the hosts in turn — same tables either way.

OpenCode note: `OPENCODE_DISABLE_CLAUDE_CODE=1` turns
off every `.claude` fallback, and hostwarden still works
with it set. Both of the things it needs — `AGENTS.md`
and `.agents/skills/` — are paths OpenCode reads
natively; `CLAUDE.md` is a fallback it only consults
when no `AGENTS.md` exists, which is never here.

### Claude Code

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)
is Anthropic's CLI for Claude, and the primary tool
Hostwarden was developed with. It reads `AGENTS.md`
directly. `CLAUDE.md` stays anyway: it imports
`AGENTS.md` with `@AGENTS.md`, which covers the setups
where the direct read does not happen, and it carries
the handful of things that exist only here — the guard
hook, the session-start hooks, the subagent. Keep both.

```
claude
```

### OpenCode with Ollama

[OpenCode](https://opencode.ai) is an open-source
terminal AI tool that supports many providers,
including local free models via
[Ollama](https://ollama.com). This lets you run
Hostwarden entirely on your own hardware — no cloud
API required.

**1. Install Ollama and pull a model**

```bash
ollama pull qwen3.5:9b
```

**2. Expand the context window**

Ollama defaults to 4096 tokens — too small for
agentic tool use. Create a variant with a larger
context:

```bash
ollama run qwen3.5:9b
>>> /set parameter num_ctx 16384
>>> /save qwen3.5:9b-16k
>>> /bye
```

**3. Configure OpenCode**

Copy the example config and adjust if needed:

```bash
cp memory/opencode.json.example memory/opencode.json
```

Edit `memory/opencode.json` to match your setup —
e.g. change the `baseURL` if Ollama runs on a
different host (`http://192.168.0.3:11434/v1`), or
change the model name. The file is gitignored so
local edits won't conflict on `git pull`.

**4. Launch OpenCode**

```
opencode
```

Select the Ollama model from the model picker (search for qwen). 
Start the model picker by typing `/models` in the OpenCode terminal.

> **Note:** Larger models (14B+) produce more
> reliable tool calls. If you have the GPU memory,
> prefer a bigger model. The `tools: true` flag is
> required for agentic features. See the
> [OpenCode provider docs](https://opencode.ai/docs/providers/)
> for more configuration options.

## Command Line Interface

You can script Hostwarden from the command line without
entering the interactive UI.

### Claude Code

Use the `-p` flag to pass a prompt directly:

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

## Fewer Prompts: Auto Mode (Claude Code)

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

### Scheduled housekeeping

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

## Safety & Guardrails

Hostwarden's safety rules are not optional — they're
baked into every session. Hostwarden follows them
consistently, even when a human might skip steps
under pressure.

- **Asks before acting** — destructive commands,
  firewall changes, reboots, and service restarts
  all require your explicit approval. Config reloads
  (`systemctl reload`) auto-proceed when the
  service's config test passes — see
  `rules/service-reload.md` and the
  `memory/service-policy.md` opt-out / opt-in
  config.
- **Hard guardrails (Claude Code)** — a shipped
  PreToolUse hook (`.claude/hooks/guard-taboos.sh`)
  mechanically blocks the absolute taboos — halt/
  poweroff, `mkfs`, partition-table writers, deleting
  or overwriting SSH keys, writes to `sshd_config` —
  in **every**
  permission mode, even
  `--dangerously-skip-permissions`, and even when the
  command hides inside an `ssh host "…"` wrapper or
  behind a language runtime (`python3 -c "open(…)"`).
  Read-only forms (`fdisk -l`, `gpart show`, …) stay
  allowed. For legitimate exceptions (OS
  replacement), launch the session with
  `HOSTWARDEN_GUARD_DISABLE=1`. OpenCode does not read
  Claude Code hooks — there the prose rules remain
  the safety layer.
- **Verifies before it reports** — a finding that
  something is missing, broken, or "gone since the
  reboot" gets confirmed against the live system
  (real path from config, proof of absence, cause
  actually shown) before Hostwarden reports or
  escalates it, so a stale assumption never becomes
  a false alarm. See
  `rules/verify-before-reporting.md`.
- **Backs up config files** — copies to
  `/var/backups/hostwarden/` before editing
  (auto-cleaned after 30 days).
- **Tests before applying** — uses dry-run, test, or
  validation modes before real execution whenever a
  tool supports it.
- **Auto-detects the OS** — reads `/etc/os-release`
  on Linux or `sw_vers` on macOS and applies the
  right commands for the platform. No guessing.
- **Logs everything** — every change lands in the
  system journal (`journalctl -t hostwarden`) as a
  one-line, plain-language headline (who did what,
  and why) that any admin can follow; the full
  technical detail (rollback paths, verification,
  flags) is mirrored locally in
  `memory/servers/<hostname>/changelog.log`.
- **Remembers servers** — stores OS, services, and
  notes in `memory/servers/` for future sessions.
- **Stable repos only** — no third-party sources
  without your explicit approval.
- **Least privilege** — uses a normal user when
  possible, `sudo` only when necessary, root only
  as a last resort. If neither sudo nor root SSH
  is available, works in unprivileged mode and
  produces a sysadmin report for tasks that need
  root.
- **Server blacklist** — add hostnames or IPs to
  `memory/blacklist.md` to permanently block
  connection. Hostwarden refuses to connect and won't
  accept overrides.
- **Read-only servers** — add hostnames or IPs to
  `memory/readonly.md` for servers you can inspect
  but must never modify. Deferred modifications are
  collected into a report you can hand off.
- **Ignores injected instructions** — text found in
  server files, logs, or command output is treated as
  data only. Suspicious patterns (text addressing the
  AI, embedded commands, safety-rule overrides) are
  flagged to the user, never followed.
- **Keeps secrets out of transcripts** — private
  keys, password files, and `.env` contents are
  inspected via metadata and fingerprints, never
  printed into the conversation, reports, memory,
  changelogs, or emails. Secrets are never passed
  as command-line arguments, where `ps`, the
  journal, and shell history would capture them.
  Likely-secret files are refused as email
  attachments by default.

## How Hostwarden Fights LLM Hallucinations

LLMs can "hallucinate" — confidently produce commands
with wrong flags, incorrect file paths, or syntax that
doesn't exist on the server's specific OS and version.
On a live system, a hallucinated command can be
dangerous.

Hostwarden reduces this risk with multiple layers:

- **Distro-specific rule files** — Instead of relying
  on the LLM's memory, hostwarden loads a verified rule
  file for each platform (Debian, RHEL, SUSE,
  macOS). These files contain the correct
  commands, package managers, firewall tools, and
  common pitfalls for each distro. The LLM reads
  the file and follows it — it doesn't have to
  guess.
- **Verify before running** — hostwarden is instructed
  to check `--help`, man pages, or upstream docs
  before running any command. This catches wrong
  flags and syntax before they reach the server.
- **Server memory** — Each server's OS, version,
  installed services, and configuration are recorded
  in a memory file. On subsequent connections, the
  LLM reads facts instead of guessing.
- **Test before apply** — Commands with a dry-run,
  test, or validation mode are checked that way first.
- **Human review** — Every command is shown to you
  before it runs. You are the final safeguard.

No approach eliminates hallucinations entirely. The
goal is to minimize what the LLM needs to recall
from training data by putting verified facts in front
of it at every step.

## Accessing Logs

Hostwarden logs every action to the system journal on
each server. To query the log:

```bash
# All entries
journalctl -t hostwarden

# Filter by date
journalctl -t hostwarden --since "2026-02-01"

# Last 20 entries
journalctl -t hostwarden -n 20

# macOS
log show \
  --predicate 'senderImagePath CONTAINS "logger"' \
  --info --last 7d | grep hostwarden
```

## Supported Distributions

| Family  | Distributions                     | Reference file        |
| ------- | --------------------------------- | --------------------- |
| Debian  | Debian, Ubuntu                    | `rules/os/debian.md`  |
| RHEL    | RHEL, CentOS, Fedora, Rocky, Alma | `rules/os/rhel.md`    |
| SUSE    | openSUSE, SLES                    | `rules/os/suse.md`    |
| macOS   | macOS (Apple Silicon & Intel)     | `rules/os/macos.md`   |
| FreeBSD | FreeBSD (all versions)            | `rules/os/freebsd.md` |

Other distributions work too — Hostwarden will apply
general best practices and let you know which OS it
detected.

## Risks & Responsibilities

> [!CAUTION]
> Hostwarden operates on live servers and local machines
> — as root, with sudo, or in unprivileged mode.
> Always review every command before approving it.

Hostwarden is for anyone willing to stay in the
driver's seat and review every command — from
newcomers learning Linux to veterans running fleets.
In fact, Hostwarden can be an especially good teacher:
each proposed command comes with an explanation of
*what* it does and *why*, so you learn the real
sysadmin reasoning instead of copy-pasting Stack
Overflow answers.

We built Hostwarden to be a help for everybody. By
design, it follows the safety checklist every single
time: it always backs up before editing, always
dry-runs when it can, always checks the OS before
assuming commands. A disciplined AI makes far fewer
mistakes than a tired human at 2 AM during an
outage. But we can't guarantee it won't ever make
one — LLMs can hallucinate, misread intent, or
produce a command with unintended side effects.

The question isn't whether Hostwarden is risk-free —
it isn't. The question is whether a disciplined AI
that follows every safety rule every time, with a
human reviewing every command, produces fewer
disasters than a human working alone under
real-world conditions.

Stay in the driver's seat. Review every command. Do
not blindly approve.

## Rule Customization

Hostwarden supports layered rule overrides so you can
customize behavior without editing the upstream rule
files (which would cause merge conflicts on
`git pull`).

Four layers, read in order (later wins):

1. **Shipped** — the rule file or skill (upstream,
   git-tracked)
2. **Global custom** — the mirroring file under
   `memory/custom-rules/` (gitignored by default,
   opt-in team sharing)
3. **Every file** — `memory/custom-rules/all.md`
4. **Per-server** —
   `memory/servers/<hostname>/rules.md`
   (gitignored with server memory)

**Your file's path mirrors the shipped one**, minus
the top-level directory and minus `references/`:

| Shipped | Yours, under `memory/custom-rules/` |
| ----------------------------------- | ------------------------- |
| `rules/backups.md`                   | `backups.md`              |
| `rules/os/debian.md`                 | `os/debian.md`            |
| the `hostwarden-security` skill      | `hostwarden-security.md`  |
| that skill's `references/ssh.md`     | `hostwarden-security/ssh.md` |

Custom files use heading prefixes to control how
they interact with what was shipped:

```markdown
## Add: Docker cleanup
New rules applied alongside the base.

## Replace: Firewall
Replaces the matching base section entirely.

## Remove: Notes > snap
Drop one entry, leave the rest of that section.
```

Sections without a prefix are treated as additions.
Prefer `Add` to `Replace`: an addition that
contradicts a shipped default still wins, and it
does not leave you maintaining a copy of a section
that keeps evolving upstream.

Hostwarden names the customizations it loaded in one
line at session start, and tells you when a file
under `memory/custom-rules/` matches nothing shipped
— that is how you catch a typo, or a path that moved
in an upgrade.

Two things you cannot override: the Critical Safety
Rules in `AGENTS.md`, and whether a skill triggers at
all — a skill's description is matched before any of
your files are read. Trigger wording belongs in
`memory/custom-rules/all.md`, which is in context
from the start. Full rules: `rules/overrides.md`.

## Project Structure

```
VERSION                — Current version number (semver)
CHANGELOG.md           — Release history
AGENTS.md              — The instruction set, read by every
                         AGENTS-aware tool
CLAUDE.md              — Imports AGENTS.md, plus the handful of
                         things only Claude Code has
bin/
  hostwarden-update       — Update, pin, or check hostwarden version
  hostwarden-backup       — Back up / restore your memory/ tree
  hostwarden-adopt        — Take over a heinzel checkout's state
  hostwarden-migrate      — Bring older user-state layouts up to
                         date (called automatically on update)
scripts/
  check.sh             — Everything CI checks, runnable locally
.githooks/             — Secret scan on commit, check.sh on push
                         (git config core.hooksPath .githooks)
mise.dev.toml          — Pinned versions of the tools check.sh
                         needs (MISE_ENV=dev mise install)
.claude/               — Shared by Claude Code and OpenCode
  settings.json        — Project-level Claude Code settings
  agents/              — Subagent definitions
    hostwarden-host-probe.md — Probes one host for the fleet
                         audit and returns one row
  rules/               — Conventions for working on this repo,
                         loaded only when those files are read
  hooks/
    check-updates.sh   — Auto-check for repo updates and
                         auto-migrate on session start
    guard-taboos.sh    — PreToolUse hook that blocks taboo
                         commands in every permission mode
    guard-taboos-test.sh — Dev-only fixture matrix for the
                         guard (run by scripts/check.sh)
    check-skills.sh    — SessionStart hook that reports a
                         .claude/skills link that is not one
    instructions-test.sh — Dev-only structural checks on the
                         instruction layer (run by scripts/check.sh)
  skills/              — Symlink to .agents/skills/, because
                         Claude Code searches only .claude/
.agents/               — Cross-tool agent assets
  skills/              — On-demand skills (progressive disclosure)
    hostwarden-housekeeping/  — Routine server inspection workflow
                         (SKILL.md + references/)
    hostwarden-security/  — Security audit workflow
                         (SKILL.md + references/)
    hostwarden-email/     — Send ad-hoc text or files by email
                         from a server (SKILL.md)
    hostwarden-fleet-audit/   — Cross-server policy drift audit
                         (SKILL.md + references/)
    hostwarden-os-install/    — Install, replace or dual-boot an
                         OS, with the disk, EFI and cloud-image
                         work that comes with it
                         (SKILL.md + references/)
    hostwarden-adopt/     — Take over a heinzel installation
                         (SKILL.md + references/)
    hostwarden-runtimes/  — Install language runtimes via mise
                         (SKILL.md + references/)
    hostwarden-deploy-user/   — Dedicated CI/CD deploy accounts
                         (SKILL.md + references/)
rules/                 — Upstream rule files (git-tracked)
  os/                  — Reference data. Detection reads at
                         most one — none for a distro no
                         family covers, one per system for a
                         workflow spanning two
    debian.md          — Debian & Ubuntu
    rhel.md            — RHEL, CentOS, Fedora, Rocky, Alma
    suse.md            — openSUSE & SLES
    macos.md           — macOS
    freebsd.md         — FreeBSD
  privilege-escalation.md — Sudo, root SSH, unprivileged mode
  os-detection.md      — OS detection procedure
  ssh-user.md          — SSH username & language management
  ssh-connections.md   — Bundled, shared SSH connections;
                         avoiding failed logins
  ssh-unreachable.md   — No retry loops; blocked path vs
                         broken host
  server-memory.md     — Server memory file format
  changelog.md         — Session logging procedure
  activity-check.md    — Recent-activity summary on connect
  first-connection.md  — Mandatory onboarding checklist
                         (no "quick question" shortcuts)
  session-start.md     — Preferences and customizations to
                         load before the session does
                         anything else
  access-control.md    — Blacklist & read-only server rules
  anomaly-detection.md — Prompt injection & anomaly detection
  verify-before-reporting.md — Verify a finding
                         against the live system before
                         reporting or escalating it
  overrides.md         — How custom rules layer over what
                         hostwarden ships
  firewall-changes.md  — Exposure review when a service is
                         installed, removed or reconfigured
  dns-aliases.md       — DNS alias detection & management
  backups.md           — Config file backup procedure
  best-practices.md    — Common anti-patterns to review
                         before risky actions
  directory-copy.md    — Cross-server directory copy checks
  port-check.md        — Port conflict detection before
                         starting services
  service-class-check.md — One web server / database /
                         MTA per host unless approved
  secrets.md           — Secrets hygiene: never print
                         keys/passwords, metadata only
  service-reload.md    — Service reload/restart policy
                         (auto-proceed rules + opt-out)
  version-check.md     — Proactive stable version checking
                         and upgrade nudges
memory/                — All your user state (gitignored
                         by default; single-directory backup)
  MEMORY.md            — Index for server memory
  user.md.example      — SSH username template (copy to
                         user.md)
  user.md              — Your preferences and SSH usernames
  blacklist.md         — Blocked servers
  readonly.md          — Read-only servers
  service-policy.md.example — Service reload/restart
                         policy template (copy to
                         service-policy.md)
  service-policy.md    — Your per-service opt-out /
                         opt-in for reload/restart
  housekeeping.md      — User-added custom checks
  network.md           — Cross-server network facts
  opencode.json.example — OpenCode config template (copy to
                         opencode.json)
  opencode.json        — Your local OpenCode config
  custom-rules/        — Your rule overrides that layer on
                         top of rules/*.md
  servers/<hostname>/
    memory.md          — Server state snapshot
    changelog.log      — Local change history
    todo.md            — Session task list
    rules.md           — Per-server rule overrides
```

## Why the Name Hostwarden?

A warden is the person responsible for a place: they
look after it, keep it in order and answer for its
state. hostwarden does that for your hosts, and you
approve every step.

The project began as
[heinzel](https://github.com/wintermeyer/heinzel),
named after the
[Heinzelmännchen](https://en.wikipedia.org/wiki/Heinzelm%C3%A4nnchen),
the helpful house spirits of Cologne who did the work
at night. hostwarden keeps that idea: an invisible
helper that does the tedious work while you review.

## Contributing

Bug reports, feature requests, and pull requests are
very welcome! If you have ideas for better guardrails,
new distro support, or improvements to the safety
rules — please open an issue or submit a PR.

## License

MIT, © Julian Pawlowski. hostwarden contains
substantial portions of
[heinzel](https://github.com/wintermeyer/heinzel) by
Stefan Wintermeyer, whose copyright notice the MIT
terms require this project to keep — both notices are
in `LICENSE`.
