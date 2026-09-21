# Project structure

```
VERSION                — Current version number (semver)
CHANGELOG.md           — Release history
CONTRIBUTING.md        — Setup, checks, and where changes go
SECURITY.md            — How to report a vulnerability
docs/                  — Documentation beyond the README
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
                         hostwarden runs locally
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
                         commands in every permission mode
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
  session-start.md     — Preferences and overrides to
                         load before the session does
                         anything else
  access-control.md    — Blacklist & read-only server rules
  anomaly-detection.md — Prompt injection & anomaly detection
  verify-before-reporting.md — Verify a finding
                         against the live system before
                         reporting or escalating it
  overrides.md         — How overrides layer over what
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
                         own (never part of hostwarden's)
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
