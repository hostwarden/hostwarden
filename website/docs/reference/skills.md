---
sidebar_position: 3
description: Slash-command workflows in Claude Code for Hostwarden tasks
---

# Skills

Workflows you invoke by name in Claude Code. Use `/skillname` — for
example, `/hostwarden-housekeeping web1.example.com` — or ask by the
description.

- **hostwarden-onboard** (`/hostwarden-onboard`) — Onboard a host
  into Hostwarden and read its memory, network, guests and baseline
  compliance.
- **hostwarden-housekeeping** (`/hostwarden-housekeeping`) — Run
  routine health checks: disk, memory, load, updates, firewall,
  certificates, service status.
- **hostwarden-security** (`/hostwarden-security`) — Audit SSH,
  firewall, accounts, sudo rules, listening services and kernel
  hardening.
- **hostwarden-baseline** (`/hostwarden-baseline`) — Bring a server
  up to the Hostwarden baseline: firewall, updates, time sync,
  key-only SSH, journal, storage maintenance.
- **hostwarden-fleet-audit** (`/hostwarden-fleet-audit`) — Compare
  policies across all servers for silent drift in unattended-upgrades,
  sshd, firewall, MTA, accounts and resolver.
- **hostwarden-fleet-read** (`/hostwarden-fleet-read`) — Set up an
  operations host that runs fleet housekeeping unattended with
  read-only access to each host.
- **hostwarden-multi-host** (`/hostwarden-multi-host`) — Run one
  question, command or change on several servers and group the
  answers so outliers stand out.
- **hostwarden-new-guest** (`/hostwarden-new-guest`) — Create a
  virtual machine or container on a hypervisor, starting from the
  distribution's official image.
- **hostwarden-os-install** (`/hostwarden-os-install`) — Install,
  replace or dual-boot an operating system, managing disk and EFI
  work.
- **hostwarden-runtimes** (`/hostwarden-runtimes`) — Install, upgrade
  or remove Node.js, Python, Ruby, Go, Java and other language
  runtimes via mise.
- **hostwarden-deploy-user** (`/hostwarden-deploy-user`) — Set up,
  audit or remove a dedicated account for automated deployments with
  restricted shell and sudo.
- **hostwarden-email** (`/hostwarden-email`) — Send an email about a
  managed server with ad-hoc text and file attachments.
- **hostwarden-heinzel-takeover** (`/hostwarden-heinzel-takeover`) —
  Copy an existing Heinzel installation into Hostwarden: memory,
  access lists, overrides and host keys.
- **hostwarden-coordinator** (`/hostwarden-coordinator`) — Control
  the operational coordinator (the background session that tracks
  which session works where).

## Finding and using skills

In Claude Code, skills show in the command palette when you type `/`.
In other tools, find the skill's file under `.agents/skills/<name>/SKILL.md` and
ask for the workflow by name or by
pointing at the file. A skill's description — the words a user would
say to invoke it — is in its front matter.
