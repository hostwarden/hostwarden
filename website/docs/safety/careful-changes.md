---
sidebar_position: 5
description: How Hostwarden avoids mistakes on a live server —
  verifying findings, backing up, testing first, and detecting the OS.
---

# Careful changes

Beyond asking permission, Hostwarden works carefully by default: it
checks its own conclusions, keeps a way back, and never guesses at a
platform's commands.

## Verifies before it reports

A finding that something is missing, broken, or "gone since the
reboot" gets confirmed against the live system — the real path from
config, proof of absence, a cause actually shown — before Hostwarden
reports or escalates it, so a stale assumption never becomes a false
alarm.

Rule: `rules/verify-before-reporting.md`.

## Backs up config files

Copies a config file to `/var/backups/hostwarden/`, or the directory
an appliance's rules name, before editing it. Backups are
auto-cleaned after 30 days.

## Tests before applying

Uses a tool's dry-run, test, or validation mode before real
execution, whenever the tool supports one.

## Auto-detects the OS

Reads `/etc/os-release` on Linux or `sw_vers` on macOS and applies
the right commands for the platform. No guessing.

## Stable repos only

No third-party package sources without your explicit approval.

## Remembers servers

Stores OS, services, and notes in `memory/machines/` for future
sessions. See [How Hostwarden remembers](../memory/index.md).
