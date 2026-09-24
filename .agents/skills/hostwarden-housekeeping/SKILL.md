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
   server's `memory.md` (e.g. PostgreSQL, nginx, Docker). On a
   Linux host without an `Appliance:` line, `ls -d /etc/casaos`
   runs here too, because CasaOS is often on a host before memory
   names it or Docker: a match selects `references/service-checks.md`
   → CasaOS. The backup-presence check from `references/backup-presence.md`
   runs on every host, independent of `memory.md` entries — on
   a host whose OS file is not `sh`, in the form that file's
   `## Housekeeping and Audits` section gives. So do the USB
   inventory from `references/usb-devices.md`, the guest check
   from `references/guests.md`, on a host with guests the
   passthrough inventory from `references/passthrough.md`, and
   `references/bmc-event-log.md`, which settles the `Management:`
   line on every host and reads the event log where there is a
   BMC. The `@storage` lines of the step-1 probe run in the
   first batch; where they find ZFS or btrfs, or memory has a
   `Storage:` line, `references/zfs-btrfs.md` runs too. On
   Linux and FreeBSD, `references/storage-maintenance.md` runs
   on every host but a system container, and
   `references/smart.md` on bare metal and in a VM its host
   passes a disk to. A host with a `deployed.md`, or a member of
   a cluster with one, gets the drift check from
   `references/deployed-files.md`. An
   override of `rules/baseline.md` changes what the checks
   that measure it expect, and where one fills the sections left
   empty there, `rules/baseline.md` → The Sections an Override
   Fills says how they are checked.
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
   new service appeared, a service was removed). Where every
   probe behind the lines `rules/server-memory.md` → Onboarded and
   stale lines names ran that applies to this host — the USB
   inventory not in a container, the passthrough inventory only on
   a host with guests, the disks only on bare metal and in a VM
   its host passes a disk or a disk controller to — write
   `- Housekeeping: <date>`, or move its date. A run that skipped
   one that applies, for want of root or because the user left its
   section out, leaves the line as it is.
   The probe of `rules/coordination.md` → Dependencies runs in the
   first batch and renews the `Depends on:` line.
7. **Log the summary** to the system journal and mirror to the
   local changelog per `rules/changelog.md`, which names the
   writer; on a host with `logger`:

       logger -t hostwarden "[<operator> as <unix-user>] \
       Housekeeping: 1 CRITICAL, 2 WARN, all services OK"

## References

Read on demand, only when the relevant section applies:

- `references/report-format.md` — required output format and
  severity rules (CRITICAL / WARN / INFO).
- `references/baseline-linux.md` — disk, memory, load, uptime,
  updates, firewall, NTP, network, logs, SSL certs, SSH host
  certificate, kernel.
- `references/baseline-freebsd.md` — disk, memory with the ARC,
  load, base and package updates, pkg audit, release support,
  pf or ipfw, enabled services, NTP, logs, SSL certs, SSH host
  certificate, kernel.
- `references/baseline-macos.md` — disk, memory, load, updates
  and restarts, Homebrew, Application Firewall, SMART, SSH host
  certificate, time sync, failed launchd jobs, kernel panics,
  local snapshots.
- `references/backup-presence.md` — generic "any backup at
  all?" probe, the provider-snapshot question, and the
  `Backup:` acknowledgment line in `memory.md`.
- `references/usb-devices.md` — the USB devices a host depends
  on (UPS, radio sticks, serial lines, dongles), the `USB:` line
  in `memory.md`, and a UPS that nothing watches.
- `references/guests.md` — whether the host became a
  hypervisor, and on one its guest inventory: stopped guests
  without a reason, retired ones past their date, guests that do
  not start with the host.
- `references/zfs-btrfs.md` — ZFS pools and btrfs filesystems:
  health, scrubs, and their settings against `storage.md` — sync,
  dedup, compression, feature flags, TRIM, the ARC beside guests,
  btrfs profiles.
- `references/passthrough.md` — what a host handed to a guest, a
  PCI or USB device or a directory, the `Passthrough:` line, and
  a bind mount whose share is not mounted.
- `references/smart.md` — the `smartctl` probe, how to read
  SATA, SAS and NVMe output, its findings, and whether `smartd`
  watches between runs. On bare metal, in a VM for the disks its
  host passes through, and where an appliance's section sends you
  there.
- `references/storage-maintenance.md` — whether TRIM, the md
  RAID check and ZFS and btrfs scrubs are scheduled, what each
  distribution ships, and the offer to schedule what is
  missing.
- `references/bmc-event-log.md` — the `Management:` line on every
  host, and on a bare-metal one the BMC's System Event Log, which
  carries power supply, fan, memory and thermal failures the OS
  never sees.
- `references/deployed-files.md` — whether the files sessions
  wrote onto the host still match what was deployed, and
  whether their masters changed since.
- `references/service-checks.md` — PostgreSQL, backups, nginx,
  Docker, CasaOS, Home Assistant, Ollama, node_exporter, NVIDIA
  GPU, MariaDB/MySQL, mesh VPNs and WireGuard, UPS (NUT,
  apcupsd), Pi-hole,
  AdGuard Home. Only run the
  ones the server's `memory.md` mentions.
- `references/containers.md` — Docker, Podman and containerd:
  the engine, containers that should run, restart loops, health,
  disk and logs, image age and pending image updates. Whenever an
  engine is present.
- `references/unprivileged.md` — which checks work without root
  and how to report skipped ones.
- The `## Housekeeping and Audits` sections of the host's
  family, appliance, platform and role files, already loaded
  by the pipeline (`rules/os-detection.md` → Layers).
- `references/scheduled.md` — running this inspection from cron
  or a systemd timer with no human at the keyboard, and mailing
  the result. Only when the user asks to schedule it.

## Scope and limits

- Several hosts in one request run as `rules/multi-host.md` says,
  which follows this skill for each host.
- Linux (Debian, Ubuntu, RHEL, CentOS, Fedora, SUSE, Alpine),
  FreeBSD and macOS are covered by the baseline references
  above.
- An appliance file with `Base: none` replaces the baseline
  probes but not the baseline thresholds: disk use, memory and
  load are judged by Disk Usage, Memory and Swap, and System
  Load in `references/baseline-linux.md`, unless the appliance
  file gives a number of its own. The Memory and Swap probe is
  the one baseline probe that still runs, appended to the
  appliance's first call: its limits read what swap is made of,
  which no appliance probe prints. Where the appliance's SSH
  login lands in a container rather than on the host, as on
  Home Assistant OS, it does not run: memory and swap there are
  the container's, and the report shows them `n/a (container)`.
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
