---
sidebar_position: 6
description: Hostwarden's own terms, each in a sentence or two, with
  the page that explains it.
---

# Glossary

## Checkouts and the workspace

- **Workspace** — `memory/`, a git repository of its own beside the
  Hostwarden checkout that holds everything Hostwarden learned and
  everything you told it. [The workspace](../memory/workspace.md)
- **Operations checkout** — a checkout whose `memory/` is the
  workspace. It administers servers; Hostwarden's own files are
  read-only there. [The operations checkout](../running-it/setup/checkouts.md)
- **Development checkout** — a checkout without a workspace, and every
  git worktree. It works on Hostwarden itself and reaches no server.
  [Working on Hostwarden](../development/index.md)
- **Shared workspace** — a workspace with a private git remote, shared
  by a team or by one person on several machines.
  [A shared workspace](../running-it/team/shared-workspace.md)
- **Operator handle** — the short name, such as `alice`, that opens
  every journal line you cause and every decision you record.
  [A shared workspace](../running-it/team/shared-workspace.md)
- **Operations host** — an always-on machine that runs the fleet's
  housekeeping unattended and reads your servers only through fleet
  read. [An operations host](../running-it/team/operations-host.md)

## What it records

- **Host memory** — a host's directory under `memory/machines/`, with
  `memory.md` at its heart. [A host's memory](../memory/host-memory.md)
- **Journal line** — the one-sentence headline of a change, written
  into the server's own journal under the tag `hostwarden`.
  [Journal and changelog](../memory/journal.md)
- **Local changelog** — `changelog.log` in the host's memory: each
  journal headline with the detail, verification and rollback.
  [Journal and changelog](../memory/journal.md)
- **Activity check** — the read of a host's journal on every
  connection, which shows you what happened there in the last seven
  days. [Journal and changelog](../memory/journal.md)
- **Watcher** — a script that logs under a session tag
  (`hostwarden`, `heinzel`); reported apart from the work of people.
  [Journal and changelog](../memory/journal.md)
- **Decision** — a choice you made about your servers, with the
  reason, which stops Hostwarden from proposing what it rules out.
  [Decisions](../memory/decisions.md)
- **Plan** — work that spans sessions, in `memory/plans/`; deleted
  once done. [To-do lists and plans](../memory/todo-and-plans.md)
- **Master** — the copy in the workspace of a file Hostwarden wrote
  onto a server, kept at the same path it has on the host.
  [Files Hostwarden deploys](../features/changes/deployed-files.md)
- **Map** — a Mermaid diagram under `memory/maps/`, drawn from memory
  by `bin/hostwarden-map`, never by hand.
  [Infrastructure maps](../memory/maps.md)

## How it works on a host

- **First-connection pipeline** — the ordered steps before the first
  command on any host: access lists, DNS aliases, SSH user, host key,
  OS detection, machine memory, activity check, Heinzel legacy.
  [Your first session](../getting-started/first-session.md)
- **Onboarding** — a full, read-only first probe of a host, on
  request, ending with what it lacks against the baseline.
  [Onboarding a host](../features/hosts/onboarding.md)
- **Local mode** — administration of the machine Hostwarden runs on,
  without SSH, as your own user.
  [Local administration](../features/systems/local-mode.md)
- **Unprivileged mode** — work as the current user where neither sudo
  nor root SSH is available, with a report of what needs root.
  [Access control](../safety/access.md)
- **Via-host mode** — reaching a guest that has no SSH server of its
  own through its hypervisor's manager.
  [Hypervisors and their guests](../features/guests/hypervisors.md)
- **Appliance** — a system with its own updater, configuration and
  firewall, such as Proxmox VE or OPNsense, which gets a rule file of
  its own. [Appliances](../features/systems/appliances.md)
- **Platform** — what the OS runs inside when something outside owns
  part of the machine; WSL is one.
  [WSL and workstations](../features/systems/workstations.md)
- **Role** — what a machine is expected to have. A Mac, a WSL instance
  and the machine Hostwarden runs on are workstations, held to other
  expectations than a server.
  [WSL and workstations](../features/systems/workstations.md)
- **Guest** — a VM, system container or jail on a hypervisor.
  [Hypervisors and their guests](../features/guests/hypervisors.md)

## Checks

- **Baseline** — what every server is expected to have, written down
  in `rules/baseline.md`, plus your own additions.
  [Server baseline](../features/checks/baseline.md)
- **Housekeeping** — the routine health inspection of a host; it
  changes nothing. [Housekeeping checks](../features/checks/housekeeping.md)
- **Security audit** — findings on SSH, firewall, accounts, services
  and hardening, by severity.
  [Security audit](../features/checks/security-audit.md)
- **Fleet audit** — a side-by-side comparison of key policies across
  every host, to show drift.
  [Fleet audit](../features/checks/fleet-audit.md)
- **Fleet read** — the way an operations host reads a server: its key
  may run a bundle of read-only checks you signed and write one
  journal line, nothing else. [Fleet read](../features/fleet/fleet-read.md)

## Changes and safety

- **Override** — a file you write under `memory/custom-rules/` or in a
  host's `rules.md` to add to, replace or remove part of a shipped rule
  or skill. [Overrides](../running-it/tailoring/overrides.md)
- **Taboo** — a command Hostwarden never runs without your explicit
  request, such as writing a partition table or touching a running
  sshd's configuration. [Hard guardrails](../safety/guardrails.md)
- **Taboo guard** — the Claude Code hook that blocks the taboos in
  every permission mode. [Hard guardrails](../safety/guardrails.md)
- **SSH safety net** — the automatic undo a firewall or network change
  arms first; it reverts the change unless a new SSH login succeeds.
  [What it asks first](../safety/approvals.md)
- **Canary** — on a change to several hosts, the one host that runs it
  alone first; the others follow only when its result matches what was
  expected. [One task on many hosts](../features/fleet/multi-host.md)
- **Radius** — the hosts a disruptive step reaches beyond its own: its
  guests, the hosts behind it, the hosts using its services, its
  cluster peers. [What a reboot would hit](../features/fleet/impact.md)
- **Maintenance window** — a planned time for a disruptive step, with
  who to notify by when.
  [Planning a maintenance window](../features/fleet/maintenance-windows.md)
- **Coordinator** — a background session per operations checkout that
  keeps track of which session works on which host and passes
  announced steps on. It never reaches a server.
  [Parallel sessions](../running-it/team/parallel-sessions.md)
