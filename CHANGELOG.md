# Changelog

## Unreleased

- **`CLAUDE.md` keeps the trigger, the file keeps the
  procedure.** It is down from 668 lines to 316, and
  from 3356 words to under 2000, because a moment and
  the file that covers it is one line — not a
  paragraph that restates what the file already says.
  Nothing that has to fire unasked left: the taboos,
  the first-connection pipeline with its no-quick-
  question clause, least privilege, the ask-before
  list, port 22, secrets, untrusted server output. The
  four sections describing skills are gone, because a
  skill's description is in context every turn anyway.
  `rules/firewall-changes.md` and `rules/overrides.md`
  now hold procedures that used to sit inline.
- **Custom rules mirror the path of what they
  override.** `rules/os/debian.md` is customized in
  `memory/custom-rules/os/debian.md`, a skill's
  `references/ssh.md` in `<skill>/ssh.md` — one rule,
  and two skills can ship a `report-format.md` without
  their overrides colliding. hostwarden names the
  customizations it loaded at session start, and says
  when one matches nothing shipped instead of ignoring
  it silently. A skill's *trigger* stays uncustomizable
  per file and belongs in `all.md`; `rules/overrides.md`
  says so rather than leaving it to be discovered.
- **Repo-development conventions load only when repo
  files are read.** `.claude/rules/repo-release.md`
  carries versioning, tagging, changelog style and the
  heinzel porting trailer, scoped to `VERSION`,
  `CHANGELOG.md` and `.github/`, so a sysadmin session
  never pays for them.

- **The OS-family files sit in `rules/os/`.** They
  are reference data, not rules: nothing about a
  situation triggers them, OS detection picks at most
  one per host by the `ID`/`ID_LIKE` it read — a
  distribution no family covers gets none rather than
  the nearest one. The directory now says so, and
  `rules/os-detection.md` names itself as what makes
  them reachable. An existing
  `memory/custom-rules/debian.md` and its four
  siblings move to `memory/custom-rules/os/` with the
  files they override, so a customization does not
  stop applying at the upgrade.

- **Language runtimes and CI/CD deploy users are
  skills.** `hostwarden-runtimes` and
  `hostwarden-deploy-user` carry what used to be two
  rule files nobody needs until they ask for that
  work. Scheduling a housekeeping run joins the
  housekeeping skill as `references/scheduled.md`.
  The policies stay where they fire without being
  asked: no runtime from distro repos or another
  version manager, no pipeline on root or a personal
  account. Both skills route rather than recite:
  `hostwarden-runtimes` is 147 lines with installing
  mise and the non-interactive shell path in
  `references/`, so asking which Node version a host
  runs no longer loads the installer behind it, and
  `hostwarden-deploy-user` is 112, with the SSH key,
  the hardening steps and the removal procedure split
  out — removing an account used to load the whole
  setup workflow to use thirteen lines of it.

- **Skills live in `.agents/skills/`.** That is where
  OpenCode and other AGENTS-style tools look, and it
  no longer matters there whether
  `OPENCODE_DISABLE_CLAUDE_CODE` is set. Claude Code
  searches only `.claude/`, so `.claude/skills` is a
  symlink to the new home. A new skill needs no link of
  its own. That link is load-bearing, and a checkout
  without symlink support turns it into a text file, so
  `.claude/hooks/check-skills.sh` says so from a
  session-start hook — without it a session simply has
  no skill and never mentions it. The test and CI fail
  if the link is wrong, and the README names symlink
  support as a prerequisite — it always was one, because
  DNS aliases are symlinks under `memory/servers/` too.

- **The disk, boot and OS-installation workflows are
  a skill.** `hostwarden-os-install` carries OS
  replacement, dual-boot, EFI boot management, cloud
  images and partition staging behind one trigger, so
  2452 lines of instruction load when someone asks
  for that work and not before. The destructive-work
  gate — explicit request, understood loss, verified
  backup, guard disabled by the operator — is stated
  once in the skill instead of per file. OS
  replacement routes further: the generic path is
  under 300 lines, and the console-less paths — the
  SSH-only rescue, filling a root filesystem nothing
  can run inside, and the FreeBSD image — are read
  only when a machine has no console.

- **Rule overrides for the moved disk and boot rules
  are no longer read.** An override is found by the
  file name it overrides, and those files left
  `rules/`, so a personal
  `memory/custom-rules/os-replacement.md`,
  `dual-boot.md`, `efi-boot.md`, `cloud-image.md` or
  `partition-staging.md` stops taking effect with
  this release. Merge what you still want into
  `memory/custom-rules/hostwarden-os-install.md` and
  delete the old file. `bin/hostwarden-migrate` names
  the ones it finds and repeats the notice until they
  are gone — but it runs from the update path, so a
  plain `git pull` never shows it.

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
