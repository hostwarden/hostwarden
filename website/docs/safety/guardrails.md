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
- **Boot loaders and firmware variables** — `efibootmgr` with a
  write flag (creating, deleting, reordering or timing an entry),
  `grub-install`, `update-grub`, `grub-mkconfig -o`,
  `bootctl install`, `update`, `remove` and `set-*`, `bless`
  beyond `--info` and `--getBoot`, `efivar -w`, and any write
  under `/sys/firmware/efi/efivars`. OS installation lifts them
  the way it lifts the disk writes (see
  [The exception](#the-exception)).
- **The account files, written directly** — `/etc/passwd`,
  `shadow`, `group`, `gshadow`, `master.passwd` and the BSD
  `pwd.db` databases, and `vipw`/`vigr`. Accounts are created
  and changed with `useradd`, `usermod`, `passwd` and `pw`.
  `sudoers` is not on this list: a drop-in is written, backed up
  and checked with `visudo -c -f`, after asking
  ([Accounts](../features/changes/accounts.md)).
- **The same on Windows** — `diskpart`, `mbr2gpt`, `format X:` and
  the Storage cmdlets (`Clear-Disk`, `Remove-VirtualDisk`, …) write
  the partition table or erase a disk; `cipher /w` and
  `wsl --unregister` erase; `bcdedit` beyond `/enum` and `/v`
  rewrites the boot configuration; `Stop-Computer`, `shutdown /s`,
  `/p`, `/h` and `wsl --shutdown`/`--terminate` halt.
  `C:\ProgramData\ssh` holds sshd's config and host keys there.
- **A redirect onto a computed target** — `> $(command -v vim)`, the
  same with backticks, and an arrow in echo text onto any expansion
  or lookup, `echo editor -> $(readlink -f $E)`: to the shell the
  arrow is a redirect, and the next word names the file it
  truncates. A plain `> "$VAR"` stays allowed.
- **Configuration tools** — the same effects through a configuration
  tool count too. `ansible-playbook` runs only a playbook from the
  workspace, `memory/`, named by absolute path together with its
  inventory, and the rule keeps it under `memory/infra/<name>/`
  ([Configuration management](../features/changes/config-management.md));
  an ad-hoc `ansible` call runs only `ping` and `setup`; no
  `ansible-pull` or `ansible-console`; no password, secret, token or
  `key=` in `-e`; `ansible-galaxy` installs only a pinned
  `requirements.yml` from the workspace into the playbook's own
  directory; no `terraform` or `tofu` `apply` or `destroy`.

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
`gpart show`, `diskutil list`, `nvme list`, `hdparm -I`,
`efibootmgr -v`, `bootctl status`, `getent passwd`. Looking a
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

## Attacks

The guard does not judge intent; a rule does. Hostwarden never
recovers a password or key, gets into a system without
authorization, scans hosts it does not administer, watches people,
hides traces or turns your servers against others. That holds on
your own servers too, no story around the request changes it, no
override of yours reaches it, and `HOSTWARDEN_GUARD_DISABLE` does
not lift it. It answers in one sentence, adds a line to
`refusals.log` in your workspace, and keeps the topic closed for the
session. Defensive work stays: reading auth logs, checking your
password policy without touching a hash, resetting a password on
your own host, the security audit.

## Other tools

OpenCode does not read Claude Code hooks — there the prose rules
remain the entire safety layer.

Rule: `.claude/hooks/guard-taboos.sh` (`AGENTS.md` → Critical Safety
Rules).
