# Changelog

## Unreleased

- **The disk, boot and OS-installation workflows are
  a skill.** `hostwarden-os-install` carries OS
  replacement, dual-boot, EFI boot management, cloud
  images and partition staging behind one trigger, so
  2452 lines of instruction load when someone asks
  for that work and not before. The destructive-work
  gate — explicit request, understood loss, verified
  backup, guard disabled by the operator — is stated
  once in the skill instead of per file. OS
  replacement routes further: the generic path is 319
  lines, and the console-less paths — the SSH-only
  rescue, filling a root filesystem nothing can run
  inside, and the FreeBSD image — are read only when
  a machine has no console.

- **heinzel is now hostwarden.** The project
  continues heinzel 2.22.0 as an independent
  project under a new name. Scripts, skills,
  environment variables, the journal tag, the
  backup directory on servers and the SSH socket
  directory are renamed. The activity check still
  reads `heinzel` journal entries, and
  `HEINZEL_NO_UPDATE` still works. `hostwarden-migrate`
  renames skill overrides in `memory/custom-rules/`.
  See "Moving over from heinzel" in the README.
- **Both tools can work on the same hosts during a
  transition.** `contrib/heinzel-coexistence/` holds
  three custom rules for a heinzel checkout: heinzel
  then reads both journal tags instead of only its
  own, treats its server memory as a lead rather than
  a fact, leaves hostwarden's files alone, and stops
  reading an adopted backup directory as data loss.
  hostwarden warns in the other direction when a
  heinzel entry is minutes old, and does not adopt a
  host that heinzel still uses.
- **A heinzel installation can be taken over
  wholesale.** `bin/hostwarden-adopt <path>` records
  the move once in `memory/user.md`, which is what
  lets an installation that never ran heinzel skip
  the per-host legacy check entirely. It copies
  memory, access lists and custom rules out of an old
  checkout; the `hostwarden-adopt` skill around it
  (`/adopt-heinzel <path>`, or the same request in
  prose) reads its memory files and changelogs into a
  per-host inventory of what sessions improvised on
  the servers — scripts,
  config files, units, cron jobs that no rule
  prescribed and that no name identifies reliably.
  It contacts no server; each first connection
  verifies the leads. Adopting such an artifact means
  recording it in server memory, not renaming it: a
  rename breaks whoever calls it and only happens
  under `rules/file-naming-changes.md`.
- **hostwarden adopts what heinzel left on a
  host.** The first connection reports heinzel's
  config backups and scratch directories, and offers
  to move them under the new name — after naming
  which of them the retention cleanup would then
  delete, because `/var/backups/heinzel/` was never
  cleaned by hostwarden. In local mode it reports
  scheduled runs that still point at `bin/heinzel-*`
  and would fail silently. The answer is recorded in
  server memory, so the check runs once.
- **A backup restores into a fresh clone.**
  `--restore` took the templates the repo ships in
  `memory/` for user data and refused without
  `--force`, and restoring overwrote them with the
  archive's older copies. Tracked templates now
  count as empty and keep the checked-out version.

hostwarden starts its own versioning at 1.0.0. The
releases before the fork were heinzel's, their numbers
do not continue here, and their notes are not repeated
— they are in git history and at
[wintermeyer/heinzel](https://github.com/wintermeyer/heinzel).
