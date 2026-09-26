---
sidebar_position: 1
description: Hostwarden's safety model in one page — what it asks
  first, what it blocks outright, and how it stays careful.
---

# Safety at a glance

Hostwarden's safety rules are not optional — they're baked into
every session, applied consistently even where a human might skip a
step under pressure. This page is the map: each section below is
one layer of the safety model, with a link to the page that covers
it in full.

## What it asks first

- Destructive commands, reboots, service restarts, and firewall or
  network changes all wait for your yes.
- A firewall or network change arms a five-minute automatic undo
  before it applies.
- Config reloads auto-proceed once the config test passes.
- Stopping or deleting a guest, or a storage change, puts the exact
  command to you first.

[What it asks first](approvals.md)

## Hard guardrails

- A shipped hook blocks partition and disk-wipe commands, storage
  repair or destroy, powering off, and touching SSH keys or sshd's
  config outright.
- It runs in every permission mode, even inside an `ssh` wrapper or
  a language runtime.
- Read-only inspection is always allowed.

[Hard guardrails](guardrails.md)

## Access control

- Least privilege by default; unprivileged mode when neither `sudo`
  nor root works.
- No session borrows another session's, subagent's or token's
  rights.
- A blacklisted host is refused outright; a read-only one is
  inspected but never changed.

[Access control](access.md)

## Careful changes

- Verifies a finding against the live system before reporting it.
- Backs up a config file before editing it, and tests before
  applying a change.
- Auto-detects the OS, sticks to stable repos, and remembers what it
  learns about a server.

[Careful changes](careful-changes.md)

## Against hallucinated commands

- Loads a verified rule file per platform instead of guessing
  commands from memory.
- Checks `--help`, man pages or upstream docs before running
  anything unfamiliar.
- Every command still waits for your review as the last safeguard.

[Against hallucinated commands](hallucinations.md)

## Secrets and untrusted output

- Private keys, password files and `.env` contents are inspected by
  metadata only, never printed.
- Server output — files, logs, MOTD banners — is data to analyze,
  never instructions to follow.

[Secrets and untrusted output](secrets.md)

## Every change is logged

Every change lands in the system journal as a one-line,
plain-language headline, mirrored in the workspace's changelog. See
[Journal and changelog](../memory/journal.md).

## Risks and responsibilities

Hostwarden is for anyone willing to stay in the driver's seat and
review every command — from newcomers learning Linux to veterans
running fleets. Each proposed command comes with what it does and
why.

It follows the safety checklist every time: it always backs up
before editing, always dry-runs when it can, always checks the OS
before assuming commands. It can still make a mistake — LLMs can
hallucinate, misread intent, or produce a command with unintended
side effects. That is why every command waits for your review; it
is not a substitute for one.
