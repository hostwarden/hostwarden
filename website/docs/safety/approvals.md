---
sidebar_position: 2
description: What Hostwarden asks first, what auto-proceeds, and what
  it refuses to run without you.
---

# What it asks first

Hostwarden asks before any destructive command, before a firewall,
network or storage change, and before restarting or rebooting
anything. This page lists exactly what asks, what auto-proceeds on
its own, and what happens when nobody is there to answer.

| Action | What Hostwarden does |
| --- | --- |
| Destructive command, reboot, restart | asks first |
| Firewall or network change | asks; arms an automatic undo first |
| Config reload | auto-proceeds once the config test passes |
| Stopping or deleting a guest | puts the command to you; blocked otherwise |
| A new guest's SSH server | puts the command to you; guest never booted |
| Growing or rebalancing storage | asks; blocked otherwise |
| Repairing or shrinking a file system | never — hands you the command |

## Destructive commands, reboots and restarts

Destructive commands, firewall and network changes, reboots, and
service restarts all require your explicit approval. Hostwarden
never runs one of these on its own judgment, however confident it
is.

Rule: `AGENTS.md` → Critical Safety Rules.

## Firewall and network changes

A firewall or network change arms its own undo first: it reverts
after five minutes — five to ten on FreeBSD — unless a new SSH
login succeeds. Where no undo can be armed, Hostwarden names the
console it knows for that machine, or tells you there is none, and
you make the change with that console open.

Rule: `rules/ssh-safety-net.md`.

## Config reloads

Config reloads (`systemctl reload`) auto-proceed once the service's
own config test passes. A `memory/service-policy.md` file lets you
opt individual services out of auto-proceeding, or opt a restart
into it.

Rule: `rules/service-reload.md`.

## Stopping or deleting a guest

Stopping or deleting a system container or VM (`pct stop`,
`qm destroy`, `incus delete`, `virsh undefine`, …) powers off or
destroys a server. The taboo-guard hook puts the exact command to
you in a permission prompt, even in auto mode. Where no prompt can
reach you (`bypassPermissions`, `dontAsk`, an unattended `claude -p`
run), it blocks the command instead, and you run it yourself.

Rule: `rules/system-containers.md`.

## Setting up a new guest's SSH server

Writing sshd's configuration or keys into a container that has
never started, or into a disk image through a libguestfs tool, and
clearing a golden image's old host keys with `virt-sysprep`, is the
one place the taboo on sshd bends — and only for a guest that never
ran. The hook puts the command and its path to you in a permission
prompt, and blocks it where no prompt can reach you. The running
host's own `/etc/ssh`, and anything under `/mnt`, stay blocked
either way.

Rule: `hostwarden-new-guest` skill.

## Storage changes

Growing a volume or file system, deactivating a volume, swapping a
disk in an array or pool, rebalancing a whole Btrfs file system, or
deleting a snapshot (`lvextend`, `resize2fs`, `lvchange -an`,
`mdadm --add`, `zpool replace`, `btrfs balance start`,
`zfs destroy pool/fs@snap`, …) gets the same prompt, and the same
block where none can reach you.

Repairing or shrinking a file system stays a taboo: when storage
fails, Hostwarden reads, asks about your backup, and hands the
repair command to you instead of running it. Looking a tool up —
`man fsck`, `which e2fsck`, `--help` — is always free.

Rule: `rules/storage.md`.
