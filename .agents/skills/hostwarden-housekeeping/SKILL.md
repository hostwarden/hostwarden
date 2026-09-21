---
name: hostwarden-housekeeping
argument-hint: "[hostname]"
description: Run a Hostwarden housekeeping (health) inspection on a
  server — disk, memory, load, pending updates, firewall, SSL
  certs, failed systemd units, logs, kernel reboot status, and
  service-specific checks. Use when the user asks to "run
  housekeeping", "housekeeping report", "run a health check on
  <host>", or "do routine inspection". Do NOT auto-invoke for
  ambiguous requests like "check server <host>" — that's
  reserved for quick queries. Covers Linux (Debian, Ubuntu, RHEL,
  CentOS, Fedora, SUSE) and macOS. Also use it for "schedule
  housekeeping", "run a nightly check", or "email me a weekly
  report automatically".
---

# hostwarden-housekeeping

Routine health inspection for a server or the local machine.
**Never run automatically** — only on explicit user request. The
whole of the Hostwarden first-connection onboarding pipeline still
applies before any of this runs.

## Workflow

1. **Load overrides**, key `hostwarden-housekeeping`, per
   `rules/overrides.md`. Read
   `memory/servers/<hostname>/memory.md` for the service list,
   last-known state and per-server quirks, and
   `memory/housekeeping.md` if present for cross-server custom
   checks (free-form Markdown, gitignored by default).
2. **Select checks.** Run all baseline checks for the detected OS
   plus any service-specific checks triggered by entries in the
   server's `memory.md` (e.g. PostgreSQL, nginx, Docker). The
   backup-presence check from `references/backup-presence.md`
   runs on every host, independent of `memory.md` entries.
3. **Run the version check** procedure from
   `rules/version-check.md` for all Tier 1 software and include the
   "Versions" section in the report.
4. **Run checks in 2–3 parallel batches** for speed — not one
   massive batch. If a single parallel tool call errors, Claude
   Code cancels sibling calls, so grouping limits blast radius.
5. **Emit the report** using the format in
   `references/report-format.md`.
6. **Update `memory.md`** immediately after, if the checks
   revealed changed facts (disk usage shifted significantly, a
   new service appeared, a service was removed).
7. **Log the summary** to the system journal and mirror to the
   local changelog per `rules/changelog.md`:

       logger -t hostwarden "Housekeeping: 1 CRITICAL, 2 WARN, \
       all services OK"

## References

Read on demand, only when the relevant section applies:

- `references/report-format.md` — required output format and
  severity rules (CRITICAL / WARN / INFO).
- `references/baseline-linux.md` — disk, memory, load, uptime,
  updates, firewall, NTP, logs, SSL certs, kernel.
- `references/baseline-macos.md` — disk, memory, load, updates,
  Homebrew, Application Firewall, SMART, time sync.
- `references/backup-presence.md` — generic "any backup at
  all?" probe, the provider-snapshot question, and the
  `Backup:` acknowledgment line in `memory.md`.
- `references/service-checks.md` — PostgreSQL, backups, nginx,
  Docker, Ollama, node_exporter, NVIDIA GPU, MariaDB/MySQL,
  WireGuard. Only run the ones the server's `memory.md` mentions.
- `references/unprivileged.md` — which checks work without root
  and how to report skipped ones.
- On an appliance, its `## Housekeeping and Audits` section,
  already loaded by the pipeline (`rules/os-detection.md` →
  Appliances).
- `references/scheduled.md` — running this inspection from cron
  or a systemd timer with no human at the keyboard, and mailing
  the result. Only when the user asks to schedule it.

## Scope and limits

- Linux (Debian, Ubuntu, RHEL, CentOS, Fedora, SUSE) and
  macOS are fully covered by the baseline references above.
- FreeBSD baselines are not yet covered. On a FreeBSD host,
  do not silently skip: run the closest read-only
  equivalents — `pkg audit -F`, `pkg upgrade -n`,
  `freebsd-update fetch` without `install`, the read-only
  firewall commands of the loaded OS file's `## Firewall`
  section, `df -h` / `swapinfo` / `uptime` for the basics,
  `service -e` for enabled services — and state in the report
  that FreeBSD has no baseline reference yet. On an appliance,
  its `## Housekeeping and Audits` section replaces the update
  commands.

## Custom checks

Users add their own checks in `memory/housekeeping.md`
(gitignored, free-form Markdown). The file describes what to
check, what commands to run, and what thresholds to use. Do not
pre-create an empty file — it is created when needed.
