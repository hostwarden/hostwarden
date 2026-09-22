# Project structure

```
VERSION                — Current version number (semver)
CHANGELOG.md           — Release history
CONTRIBUTING.md        — Setup, checks, and where changes go
SECURITY.md            — How to report a vulnerability
docs/                  — Documentation beyond the README;
                         docs/README.md indexes it
AGENTS.md              — The instruction set, read by every
                         AGENTS-aware tool
CLAUDE.md              — Imports AGENTS.md, plus the handful of
                         things only Claude Code has
bin/
  hostwarden-update       — Update, pin, or check hostwarden version
  hostwarden-backup       — Back up / restore your memory/ tree
  hostwarden-init         — Set up (or join) the workspace
  hostwarden-sync         — Keep the workspace in step with
                            its remote
  hostwarden-mirror       — Keep a mirror of hostwarden current
                            (for CI or cron)
  hostwarden-adopt        — Take over a heinzel checkout's state
  hostwarden-migrate      — Bring older user-state layouts up to
                         date (called automatically on update)
  hostwarden-doctor       — Check the workstation for the tools
                         Hostwarden runs locally
  hostwarden-lab          — Disposable containers to try commands
                         on during development, and lab VMs
                         for a test clone
scripts/
  check.sh             — Everything CI checks, runnable locally
.githooks/             — Opt-in: secret scan on commit, check.sh
                         on push
mise.dev.toml          — Pinned versions of the tools check.sh
                         needs
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
    follow.sh          — The release line a checkout follows,
                         shared with bin/hostwarden-update
    release-test.sh    — Dev-only fixture matrix for mirror,
                         update and release lines (run by
                         scripts/check.sh)
    guard-taboos.sh    — PreToolUse hook that blocks taboo
                         commands, and edits of SSH keys and
                         sshd_config, in every permission mode
    guard-taboos-test.sh — Dev-only fixture matrix for the
                         guard (run by scripts/check.sh)
    guard-settings.sh  — PreToolUse hook that keeps the
                         guard's off switch out of settings
                         files and its session records
    check-skills.sh    — SessionStart hook that reports a
                         .claude/skills link that is not one
    check-session.sh   — SessionStart hook that reports a
                         linked worktree, and records and
                         reports a guard that is off
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
    alpine.md          — Alpine Linux (apk, OpenRC, busybox)
    macos.md           — macOS
    freebsd.md         — FreeBSD
    windows.md         — Windows Server (read-only; PowerShell 7 setup)
  appliance/           — Reference data on top of one family
                         file, or none. Detection reads at
                         most one
    proxmox-ve.md      — Proxmox VE (on os/debian.md)
    openmediavault.md  — OpenMediaVault (on os/debian.md)
    opnsense.md        — OPNsense (on os/freebsd.md)
    pfsense.md         — pfSense CE and Plus (on os/freebsd.md)
    xcp-ng.md          — XCP-ng (on os/rhel.md)
    truenas.md         — TrueNAS (on os/debian.md)
    truenas-core.md    — TrueNAS CORE, end of life (on os/freebsd.md)
    haos.md            — Home Assistant OS (no base)
    synology-dsm.md    — Synology DSM 7.2+ (no base)
    ugos.md            — UGREEN UGOS Pro (no base)
    unifi-os.md        — UniFi OS consoles: gateways, Cloud Keys,
                         UNAS (no base)
    unraid.md          — Unraid (no base)
    openwrt.md         — OpenWrt (no base)
    zimaos.md          — ZimaOS (no base)
  busybox.md           — Busybox applets and flags on Alpine
                         and OpenWrt
  platform/            — Reference data on top of whichever
                         family was detected. Detection reads
                         at most one
    wsl.md             — Windows Subsystem for Linux
  role/                — What a machine is expected to have.
                         Server is the default and has no file
    workstation.md     — A machine a person works at
  privilege-escalation.md — Sudo, root SSH, unprivileged mode
  os-detection.md      — OS detection procedure
  ssh-user.md          — SSH username & language management
  ssh-connections.md   — Bundled, shared SSH connections;
                         avoiding failed logins
  ssh-unreachable.md   — No retry loops; blocked path vs
                         broken host
  ssh-safety-net.md    — Timed revert armed before a
                         firewall or network change
  server-memory.md     — Server memory file format
  changelog.md         — Session logging procedure
  activity-check.md    — Recent-activity summary on connect
  config-management.md — Hosts managed by Ansible or
                         another tool: detect, record,
                         change through it or by hand
  first-connection.md  — Mandatory onboarding checklist
                         (no "quick question" shortcuts)
  session-start.md     — Preferences and overrides to
                         load before the session does
                         anything else
  access-control.md    — Blacklist & read-only server rules
  anomaly-detection.md — Prompt injection & anomaly detection
  verify-before-reporting.md — Verify a finding
                         against the live system before
                         reporting or escalating it
  overrides.md         — How overrides layer over what
                         Hostwarden ships
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
  containers.md        — Docker, Podman and containerd:
                         find, read and change a container
  secrets.md           — Secrets hygiene: never print
                         keys/passwords, metadata only
  service-reload.md    — Service reload/restart policy
                         (auto-proceed rules + opt-out)
  version-check.md     — Proactive stable version checking
                         and upgrade nudges
templates/workspace/   — What bin/hostwarden-init puts
                         into a new workspace
templates/memory/      — Templates to copy into memory/
  MEMORY.md            — Index for server memory
  user.md.example      — SSH username template (copy to
                         memory/user.md)
  service-policy.md.example — Service reload/restart
                         policy template
  opencode.json.example — OpenCode config template
memory/                — The workspace: all your user
                         state, a git repository of its
                         own (never part of Hostwarden's)
  .hostwarden-workspace — Marks an operations checkout
  .gitignore           — Files that stay personal even
                         in a team
  user.md              — Your preferences and SSH usernames
  blacklist.md         — Blocked servers
  readonly.md          — Read-only servers
  service-policy.md    — Your per-service opt-out /
                         opt-in for reload/restart
  housekeeping.md      — User-added custom checks
  network.md           — Cross-server network facts
  opencode.json        — Your local OpenCode config
  custom-rules/        — Your rule overrides that layer on
                         top of rules/*.md
  servers/<hostname>/
    memory.md          — Server state snapshot
    changelog.log      — Local change history
    todo.md            — Session task list
    rules.md           — Per-server rule overrides
```
