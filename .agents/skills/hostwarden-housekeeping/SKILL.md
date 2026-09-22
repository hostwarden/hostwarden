---
name: hostwarden-housekeeping
argument-hint: "[hostname]"
description: Run a Hostwarden housekeeping (health) inspection on a
  server — disk, memory, load, pending updates, firewall, SSL
  certs, failed systemd units or OpenRC services, logs, kernel
  reboot status, and service-specific checks. Use when the user
  asks to "run housekeeping", "housekeeping report", "run a
  health check on <host>", or "do routine inspection". Do NOT
  auto-invoke for ambiguous requests like "check server <host>"
  — that's reserved for quick queries. Covers Linux (Debian,
  Ubuntu, RHEL, CentOS, Fedora, SUSE, Alpine), FreeBSD, macOS
  and Windows Server (read-only). Also use it for "schedule
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
   runs on every host, independent of `memory.md` entries — on
   a host whose OS file is not `sh`, in the form that file's
   `## Housekeeping and Audits` section gives.
3. **Run the version check** procedure from
   `rules/version-check.md` for all Tier 1 software and include the
   "Versions" section in the report — where the OS file uses the
   `sh -s` bundle (Scope and limits below).
4. **Run checks in 2–3 parallel batches** for speed — not one
   massive batch. If a single parallel tool call errors, Claude
   Code cancels sibling calls, so grouping limits blast radius.
5. **Emit the report** using the format in
   `references/report-format.md`.
6. **Update `memory.md`** immediately after, if the checks
   revealed changed facts (disk usage shifted significantly, a
   new service appeared, a service was removed).
7. **Log the summary** to the system journal and mirror to the
   local changelog per `rules/changelog.md`, which names the
   writer; on a host with `logger`:

       logger -t hostwarden "Housekeeping: 1 CRITICAL, 2 WARN, \
       all services OK"

## References

Read on demand, only when the relevant section applies:

- `references/report-format.md` — required output format and
  severity rules (CRITICAL / WARN / INFO).
- `references/baseline-linux.md` — disk, memory, load, uptime,
  updates, firewall, NTP, logs, SSL certs, kernel.
- `references/baseline-freebsd.md` — disk and ZFS pools, memory
  with the ARC, load, base and package updates, pkg audit,
  release support, pf or ipfw, enabled services, NTP, logs, SSL
  certs, kernel.
- `references/baseline-macos.md` — disk, memory, load, updates
  and restarts, Homebrew, Application Firewall, SMART, time sync,
  failed launchd jobs, kernel panics, local snapshots.
- `references/backup-presence.md` — generic "any backup at
  all?" probe, the provider-snapshot question, and the
  `Backup:` acknowledgment line in `memory.md`.
- `references/smart.md` — the `smartctl` probe, how to read
  SATA, SAS and NVMe output, and its findings. Only when an
  appliance's section sends you there.
- `references/service-checks.md` — PostgreSQL, backups, nginx,
  Docker, Home Assistant, Ollama, node_exporter, NVIDIA GPU,
  MariaDB/MySQL, WireGuard, Pi-hole, AdGuard Home. Only run the
  ones the server's `memory.md` mentions.
- `references/unprivileged.md` — which checks work without root
  and how to report skipped ones.
- The `## Housekeeping and Audits` sections of the host's
  family, appliance, platform and role files, already loaded
  by the pipeline (`rules/os-detection.md` → Layers).
- `references/scheduled.md` — running this inspection from cron
  or a systemd timer with no human at the keyboard, and mailing
  the result. Only when the user asks to schedule it.

## Scope and limits

- Linux (Debian, Ubuntu, RHEL, CentOS, Fedora, SUSE, Alpine),
  FreeBSD and macOS are covered by the baseline references
  above. On an appliance, its `## Housekeeping and Audits`
  section replaces the update checks.
- An appliance file with `Base: none` replaces the baseline
  probes, not its thresholds: disk use, load and memory are
  judged by `references/baseline-linux.md` unless the appliance
  file gives a number of its own.
- A reference written for `sh` — the baselines, the version
  check, `references/service-checks.md` — runs only where the
  loaded OS file uses the `sh -s` bundle
  (`rules/ssh-connections.md` → Bundle commands); elsewhere,
  as on Windows Server, the OS file's `## Housekeeping and
  Audits` section is the whole check.

## Custom checks

Users add their own checks in `memory/housekeeping.md`
(gitignored, free-form Markdown). The file describes what to
check, what commands to run, and what thresholds to use. Do not
pre-create an empty file — it is created when needed.
