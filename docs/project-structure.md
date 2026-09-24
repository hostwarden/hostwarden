# Project structure

```
README.md              — What Hostwarden is and how to start
LICENSE                — The licence
VERSION                — Current version number (semver)
CHANGELOG.md           — Release history
changelog.d/           — One entry per unreleased change,
                         folded into CHANGELOG.md at a release
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
  hostwarden-ssh-config   — Write memory/ssh_config, the file
                            every SSH call passes with -F
  hostwarden-fleet-run    — An operations host's nightly
                            housekeeping through fleet read
  hostwarden-mirror       — Keep a mirror of hostwarden current
                            (for CI or cron)
  hostwarden-heinzel-takeover — Take over a Heinzel
                            checkout's state
  hostwarden-migrate      — Bring older user-state layouts up to
                         date (called automatically on update)
  hostwarden-doctor       — Check the workstation for the tools
                         Hostwarden runs locally
  hostwarden-lab          — Disposable containers to try commands
                         on during development, and lab VMs
                         for a test clone
scripts/
  changelog-release.sh — Folds changelog.d/ into CHANGELOG.md
                         at a release; checks its form in CI
  changelog-release-test.sh — Fixture matrix for
                         changelog-release.sh (run by
                         scripts/check.sh)
  check.sh             — Everything CI checks, runnable locally
  codex-quota.sh       — What is left of the Codex usage limit,
                         read without spending any
  review-record.sh     — Whether a pull request body records
                         the second review of its head
  review-record-test.sh — Its fixture matrix (run by
                         scripts/check.sh)
  fleet-read-test.sh   — Fixture matrix for the fleet-read
                         wrapper (run by scripts/check.sh)
  fleet-run-test.sh    — Fixture matrix for
                         bin/hostwarden-fleet-run (run by
                         scripts/check.sh)
.githooks/             — Opt-in: the cheap checks on commit,
                         check.sh on push
mise.dev.toml          — Pinned versions of the tools check.sh
                         needs
.github/               — CI, review-record and release
                         workflows, and the ruleset for main
contrib/
  heinzel-coexistence/ — Overrides that teach a Heinzel
                         checkout about Hostwarden
.claude/               — Shared by Claude Code and OpenCode
  settings.json        — Project-level Claude Code settings
  agents/              — Subagent definitions
    hostwarden-host-probe.md — Probes one host for the fleet
                         audit and returns one row
    hostwarden-host-task.md — Runs one task on one host when a
                         request spans several
    hostwarden-reviewer.md — Reviews a change to Hostwarden
                         for defects before a second reviewer does
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
    mode.sh            — Development or operations, defined
                         once for the hooks and bin/
    json.sh            — The hook input read as text, and a
                         deny or ask written, defined once
                         for the hooks
    guard-mode.sh      — PreToolUse hook that holds a session
                         to its mode: no server from
                         development, no edit to shipped files
                         in operations
    guard-mode-test.sh — Dev-only fixture matrix for the mode
                         guard (run by scripts/check.sh)
    session-mode.sh    — SessionStart hook that announces the
                         mode, a linked worktree included, and
                         puts the shim on PATH in development
    shim.sh, shim/     — Stand-ins for ssh, sudo and the other
                         tools that reach a server, in a
                         development session
    git-ssh.sh         — GIT_SSH_COMMAND in development, so
                         git push reaches the real ssh
    check-skills.sh    — SessionStart hook that reports a
                         .claude/skills link that is not one
    check-session.sh   — SessionStart hook that records and
                         reports a guard that is off
    authoring-conventions.sh — PostToolUse hook that names the
                         authoring rules when an instruction
                         file or a bin/ script is edited
    corpus.sh          — The instruction corpus the two test
                         matrices walk, defined once
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
    hostwarden-multi-host/ — One question, check or change
                         on several servers (SKILL.md)
    hostwarden-os-install/    — Install, replace or dual-boot an
                         OS, with the disk, EFI and cloud-image
                         work that comes with it
                         (SKILL.md + references/)
    hostwarden-new-guest/     — Create a VM or container on a
                         hypervisor, with the baseline
                         (SKILL.md + references/)
    hostwarden-onboard/   — Onboard a host explicitly: its
                         first connection, read-only (SKILL.md)
    hostwarden-baseline/  — Bring an existing server up to
                         the baseline (SKILL.md)
    hostwarden-heinzel-takeover/ — Take over a Heinzel
                         installation (SKILL.md + references/)
    hostwarden-runtimes/  — Install language runtimes via mise
                         (SKILL.md + references/)
    hostwarden-deploy-user/   — Dedicated CI/CD deploy accounts
                         (SKILL.md + references/)
    hostwarden-fleet-read/    — An operations host and its
                         least-privilege access: a forced
                         command that runs operator-signed
                         bundles (SKILL.md + references/)
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
    qnap.md            — QNAP QTS and QuTS hero (no base)
    zimaos.md          — ZimaOS (no base)
  busybox.md           — Busybox applets and flags on Alpine
                         and OpenWrt
  firewalld.md         — firewalld commands and safety net
                         for the RHEL and SUSE families
  appliance-api.md     — Reading and changing an appliance
                         through its web API
  tls-pinning.md       — Pinning a self-signed appliance
                         certificate for API calls
  management-controller.md — How any host is reached when
                         SSH is gone: a BMC or Intel AMT where
                         there is one, the node or provider
                         console otherwise
  platform/            — Reference data on top of whichever
                         family was detected. Detection reads
                         at most one
    wsl.md             — Windows Subsystem for Linux
  role/                — What a machine is expected to have
                         instead of baseline.md. Server is the
                         default and has no file
    workstation.md     — A machine a person works at
  baseline.md          — What every server is expected to
                         have
  privilege-escalation.md — Sudo, root SSH, unprivileged mode
  accounts.md          — A host's account model, team
                         accounts, certificate logins and
                         account or sudo changes
  accounts-probe.md    — The read-only probe behind
                         accounts.md: account source, sudo
                         rules, local accounts
  accounts-on-demand.md — Accounts for people who come
                         through an identity provider and
                         short-lived certificates
  borrowed-rights.md   — No other session, job or token for
                         what this session may not do
  os-detection.md      — OS detection on every connection:
                         the first call, Windows, layers
  first-detection.md   — What detection settles once:
                         family, appliance, platform,
                         virtualization, hypervisor, role
  ssh-user.md          — SSH username & language management
  ssh-connections.md   — Bundled, shared SSH connections;
                         avoiding failed logins
  ssh-unreachable.md   — No retry loops; blocked path vs
                         broken host
  host-keys.md         — memory/known_hosts: getting a key,
                         a changed key, certificates
  ssh-ca.md            — An existing SSH CA: host and user
                         certificates, CA trust, revocation
                         list, using it everywhere
  ssh-ca-issuing.md    — What a CA hands out, per product;
                         a login that fails on the principal
  ssh-config.md        — memory/ssh_hosts: other ports,
                         addresses, jump hosts; finding
                         a new host's port; port
                         forwardings per session
  ssh-safety-net.md    — Timed revert armed before a
                         firewall or network change
  server-memory.md     — Server memory file format
  storage-inventory.md — Disks, ZFS and btrfs settings
                         recorded once per host
  changelog.md         — Session logging procedure
  activity-check.md    — Recent-activity summary on connect
  config-management.md — Hosts managed by Ansible or
                         another tool: the probe on
                         every connection
  config-management-leads.md — The first-connection
                         probe, what a lead means, and
                         the question that records it
  config-management-changes.md — A change on a managed
                         host: through the tool or by
                         hand
  first-connection.md  — Mandatory onboarding checklist
                         (no "quick question" shortcuts)
  multi-host.md        — One task on several hosts: one
                         subagent each, grouped answers,
                         a canary for changes
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
  decisions.md         — Your standing decisions: where
                         they go, how audits rate what
                         they settle
  firewall-changes.md  — Exposure review when a service is
                         installed, removed or reconfigured
  dns-aliases.md       — DNS alias detection & management
  mdns.md              — mDNS or DNS for a .local name, and
                         what disagreeing answers mean
  backups.md           — Config file backup procedure
  deployed-files.md    — Files a session writes onto a
                         host: master, marker, deploy and
                         drift
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
  hypervisors.md       — Guest inventory and linking guest
                         and host
  system-containers.md — LXC, Incus, LXD, Proxmox and jails
                         as servers: reaching and changing
                         them
  parallel-sessions.md — The session register that shows who
                         else is changing a host
  server-check-handoff.md — How a development session gets
                         a live server's answer
  network.md           — A host's network profile and what
                         counts as a finding there
  network-probe.md     — The read-only probes behind
                         network.md
  mesh-vpn.md          — Mesh VPNs and tunnels: membership,
                         login expiry, what cuts a host off
  file-naming-changes.md — Renames, moves and retention
                         changes: find what matches on them
  heinzel-legacy.md    — Finding the state Heinzel left on a
                         host
  heinzel-takeover.md  — Taking over what that check found,
                         and hosts taken over from Heinzel
  version-check.md     — Proactive stable version checking
                         and upgrade nudges
templates/workspace/   — What bin/hostwarden-init puts
                         into a new workspace
                         (.gitattributes, .gitignore,
                         .hostwarden-workspace)
templates/fleet-read/  — fleet-read, the forced command an
                         operations host's key runs on each
                         host
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
  known_hosts          — The SSH host keys of your servers
  ssh_hosts            — How a server is reached when its
                         name alone does not say it
  ssh_config           — Written for this machine by
                         bin/hostwarden-ssh-config
  opencode.json        — Your local OpenCode config
  custom-rules/        — Your rule overrides that layer on
                         top of rules/*.md
  decisions/           — Your decisions about a group of
                         hosts or all of them, and beside
                         each file a directory of the same
                         name with their longer reasoning
  servers/<hostname>/
    memory.md          — Server state snapshot
    changelog.log      — Local change history
    todo.md            — Session task list
    rules.md           — Per-server rule overrides
    decisions.md       — Your decisions about this host
    decisions/         — Their longer reasoning
    guests.md          — A hypervisor's guest inventory
    storage.md         — Disks, ZFS pool and btrfs settings,
                         compared by housekeeping
    files/             — Masters of the files deployed
                         there, at their paths on the host
    src/               — What renders a master: generators,
                         upstream copies, patches
    deployed.md        — What was deployed, with hashes
    notes/             — Evidence and snapshots, never
                         deployed
  clusters/<name>/
    cluster.md         — Members, quorum, HA, pool master
    guests.md          — The cluster's guest inventory
    files/             — Masters every member carries
    decisions.md       — Your decisions about the cluster
  fleet/<name>/        — One artifact deployed to several
                         hosts, and its README.md
  tools/               — Scripts you run from the
                         workstation against hosts
  plans/               — Work that spans sessions
```
