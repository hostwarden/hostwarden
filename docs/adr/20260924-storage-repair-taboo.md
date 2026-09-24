---
id: 20260924-storage-repair-taboo
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [storage, guard]
---

# Storage repair and destroy commands are a taboo

## Context

Decided 2026-09-22 during the home-NAS appliance series (ZimaOS
#104, UGOS #108, then DSM, QNAP). Vendor NAS volumes carry flags a
stock repair tool does not know and can damage. Before this, a
repair command was governed by prose alone: "ask before storage
changes", with the session left to recognize one. Refined in Codex
review on #146: `zpool`/`btrfs` scrub moved from free to ask (heavy
I/O, self-heals from checksum-verified copies), and further
repair-of-a-sync forms moved to deny.

## Decision drivers

- Vendor NAS volumes carry flags a generic repair tool can damage.
- A remount after a crash is when a repair looks most tempting and
  does the most damage if the array can still reassemble.
- Repair and destroy need stricter handling than routine growth.

## Considered options

### Tiered guard enforcement: deny repair/destroy, ask for growth — chosen

`fsck`/`e2fsck`/`xfs_repair` without a dry-run flag, `btrfs check
--repair`, `mdadm --create`/force-assemble, LVM `pvcreate`/
`vgremove`/`lvreduce`, a ZFS rewind or `zfs destroy` of a dataset,
and the disk-level TrueNAS deletes are denied outright by the
guard. Routine build-out (`lvextend`, `mdadm --add`) asks. Read-only
inspection stays free.

### Prose-only taboo, no guard support

Keep the AGENTS.md rule and trust the session to recognize a repair
command. Rejected: a repair command is reached for exactly when a
prose rule is least reliable, right after a reboot looks wrong.

### Deny every storage-modifying command, including growth

Treat any write to storage as an absolute taboo. Rejected: routine
capacity growth is ordinary, safe work; blocking it would put the
guard in the way of it.

## Decision

Repair and destroy commands are an absolute taboo enforced by the
guard, wherever the family spells them (fsck family, `btrfs check
--repair`, forced `mdadm`, LVM `pvcreate`/`vgremove`, a ZFS rewind
or dataset `destroy`); routine build-out asks; inspection is
always free.

## Consequences

`AGENTS.md` → Critical Safety Rules and `rules/storage.md` carry the
tiering; `.claude/hooks/guard-taboos.sh` enforces the deny tier
mechanically. A review asking for a repair command to run
unattended, or for growth to be blocked too, is answered with this
record.

## Confirmation

`rules/storage.md` and the guard's own test matrix would have to
change together. A proposal to run a repair automatically, or to
deny routine growth, is the moment to reread this record.
