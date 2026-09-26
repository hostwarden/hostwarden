---
sidebar_position: 3
description: The taboo guard — a mechanical hook that blocks the
  handful of commands no session should run on a live server.
---

# Hard guardrails

On top of the rules elsewhere on this page, Claude Code runs a
mechanical hook that blocks a short list of absolute taboos
outright, in every session, regardless of what is asked of it.

:::warning
Claude Code only. Elsewhere — OpenCode and other tools — the prose
rules in `AGENTS.md` are the entire safety layer; nothing enforces
them mechanically.
:::

## What it blocks

- **Disks and partition tables** — any partition-table writer,
  whichever tool (`fdisk`, `cfdisk`, `sfdisk`, `gdisk`, `sgdisk`,
  `parted`, `gpart`, `gpt`, `diskutil`, `growpart`), and any command
  that erases a whole disk device while leaving the partition table
  alone: `blkdiscard`, `nvme format`/`sanitize`, `hdparm`
  secure-erase, `badblocks -w`, `shred` on a device, and `dd`, a
  redirect or `tee` onto one.
- **File systems, RAID, LVM, ZFS and Btrfs repair or destroy** —
  `fsck` without `-n`, a ZFS rewind, and the rest that
  `rules/storage.md` lists in full.
- **Power off or halt** — a server is never stopped or rebooted
  through this path (see [What it asks first](approvals.md) for the
  reboots that do reach you).
- **SSH keys and sshd's configuration** — deleting or overwriting an
  SSH key, or deleting, moving or re-permissioning sshd's revocation
  list (`RevokedKeys`); writing `sshd_config` or its
  `sshd_config.d/` drop-ins, wherever sshd keeps them (`/etc/ssh`,
  `/usr/local/etc/ssh`, QNAP's `/etc/config/ssh`, …), or dropbear's
  configuration where dropbear is the SSH server. An sshd that
  already runs is never touched, not in a guest and not through its
  host.
- **The same on Windows** — `diskpart`, `mbr2gpt`, `format X:` and
  the Storage cmdlets (`Clear-Disk`, `Remove-VirtualDisk`, …) write
  the partition table or erase a disk; `cipher /w` and
  `wsl --unregister` erase; `bcdedit` beyond `/enum` and `/v`
  rewrites the boot configuration; `Stop-Computer`, `shutdown /s`,
  `/p`, `/h` and `wsl --shutdown`/`--terminate` halt.
  `C:\ProgramData\ssh` holds sshd's config and host keys there.
- **Configuration tools** — the same effects through a configuration
  tool count too: no playbook, `ansible-pull` or `ansible-console`
  (applying your Ansible code is your step), no ad-hoc `ansible`
  call whose module partitions, formats, powers off, writes SSH keys
  or runs a local script, and no `terraform` or `tofu` `apply` or
  `destroy`.

## Where it applies

- Every permission mode, `--dangerously-skip-permissions` included.
- Inside an `ssh host "…"` wrapper or behind a language runtime
  (`python3 -c`, `node -e`, `perl -e`, `awk`, `powershell.exe`) —
  such a command line cannot be shown to be read-only, so it counts
  as a write and is blocked.
- The agent's own edit tools, judged by the file they write: they
  cannot write an SSH key or `sshd_config` either.
- Subagents too.
- The `PowerShell` tool is denied outright — its commands cannot be
  read, so there is nothing for the hook to judge.

## What stays allowed

Read-only inspection is always allowed: `lsblk`, `fdisk -l`,
`gpart show`, `diskutil list`, `nvme list`, `hdparm -I`. Looking a
tool up — `man`, `--help` — costs nothing either.

## The exception

Legitimate exceptions — OS installation and replacement — need the
operator to export `HOSTWARDEN_GUARD_DISABLE` before launching the
session, set to the one host the disk writes run on — for a guest whose
disk is written from its hypervisor, the hypervisor — or to
`localhost` for this machine. The guard stays off toward that host only: a
command aimed at any other host, or one whose destination it cannot
read, is judged as usual. A value of `1` or a list of hosts is
refused. In the desktop app, that variable goes into
`.claude/settings.local.json`
([Claude Code Desktop](../getting-started/ai-tools.md#claude-code-desktop)).

## Other tools

OpenCode does not read Claude Code hooks — there the prose rules
remain the entire safety layer.

Rule: `.claude/hooks/guard-taboos.sh` (`AGENTS.md` → Critical Safety
Rules).
