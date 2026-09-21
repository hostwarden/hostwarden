# Safety and guardrails

Hostwarden's safety rules are not optional — they're
baked into every session. Hostwarden follows them
consistently, even when a human might skip steps
under pressure.

- **Asks before acting** — destructive commands,
  firewall changes, reboots, and service restarts
  all require your explicit approval. A firewall or
  network change arms its own undo first: it reverts
  after five minutes unless a new SSH login succeeds
  (`rules/ssh-safety-net.md`). Config reloads
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
  `HOSTWARDEN_GUARD_DISABLE=1` — in the desktop app,
  through `.claude/settings.local.json`
  ([Claude Code Desktop](ai-tools.md#claude-code-desktop)).
  OpenCode does not read
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

## How Hostwarden fights LLM hallucinations

LLMs can "hallucinate" — confidently produce commands
with wrong flags, incorrect file paths, or syntax that
doesn't exist on the server's specific OS and version.
On a live system, a hallucinated command can be
dangerous.

Hostwarden reduces this risk with multiple layers:

- **Distro-specific rule files** — Instead of relying
  on the LLM's memory, Hostwarden loads a verified rule
  file for each platform (Debian, RHEL, SUSE,
  Alpine, FreeBSD, macOS). These files contain the correct
  commands, package managers, firewall tools, and
  common pitfalls for each distro. The LLM reads
  the file and follows it — it doesn't have to
  guess.
- **Verify before running** — Hostwarden is instructed
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

## Accessing logs

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

# Alpine and FreeBSD (syslog)
grep hostwarden /var/log/messages
```

