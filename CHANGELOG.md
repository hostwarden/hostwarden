# Changelog

## Unreleased

- **The authoring conventions reach the files they
  govern.** Editing anything under `rules/` or
  `.agents/skills/` names
  `.claude/rules/instruction-authoring.md` once per
  session. A `paths` glob could not do this: it fires on
  a read, and reading a rule to follow it on a server
  looks the same as reading it to change it.
- **The checked corpus is what git would carry.** A new
  instruction file is covered by the guard matrix and
  the layout test the moment it exists, staged or not,
  while everything a user generates stays out because
  it is gitignored. The shipped templates under
  `memory/` are scanned too, and `settings.json` is
  checked for a hook whose script has been renamed
  away.
- **The guard fixture matrix runs in parallel** — 54
  seconds down to 25 on a 12-core machine, same
  fixtures, and a fixture that comes back without a
  verdict fails the run instead of going uncounted. A
  pre-commit check nobody waits for is a pre-commit
  check nobody runs.

- **A `references/` pointer resolves inside its own
  skill.** The fleet audit and the housekeeping baseline
  both sent a reader to
  `references/firewall-nftables-docker.md`, which only
  the security skill ships — a path relative to the
  skill that writes it, pointing at nothing. Both now
  spell the cross-skill path out in full, and
  `instructions-test.sh` checks every such pointer.

- **An MTA hostwarden installs queues the mail.** The
  default was `msmtp`, which has no queue: it connects
  when called and exits non-zero when the relay does not
  answer. Nothing that sends unattended mail on a server
  — cron, unattended-upgrades, hostwarden's own reports —
  retries, so a relay down for a minute lost the message
  with nobody to notice. The install now picks a spooling
  agent from what the host's package manager offers
  (`nullmailer`, `dma`, or postfix as a null client), and
  says which and why. `msmtp` stays the right answer for
  a container or a host that gets recreated rather than
  repaired, and is installed when asked for — with what
  it costs said out loud.

- **The email skill loads in stages.** Everything used to
  arrive at once: transport, MIME construction and the
  attachment gates entered context the moment anyone asked
  to send a mail, before hostwarden knew where it would
  send from or whether there was an attachment. The
  workflow loads first now, and each step reads its own
  part when it gets there. An exchange that stops early —
  the where-to-send-from question the first mail per host
  asks — reads the workflow and nothing else. A full send
  still reads all of it, in three pieces instead of one.

  If you customized one of those topics, it has its own
  override key now — `hostwarden-email/transport.md`,
  `…/compose.md`, `…/send-verify.md` under
  `memory/custom-rules/`. An existing
  `hostwarden-email.md` still applies as a whole; a
  section in it that named one of the moved headings
  matches nothing, and hostwarden says so and asks rather
  than guessing which file you meant
  (`rules/overrides.md`).

- **The fleet audit gives each host its own subagent.**
  A dozen hosts used to mean a dozen `sshd -T` dumps in
  one context; now each `hostwarden-host-probe` returns
  a single comparison row and keeps its raw output to
  itself — and reads the probe list from the skill's own
  `references/`, so the commands are not copied into a
  dozen prompts the main session never needed. The probe
  inherits the project instructions and the taboo guard
  hook applies to its commands, both measured rather
  than assumed, so it runs the first-connection pipeline
  like any other session and cannot change a
  configuration. Parallelism is across different hosts
  only, because rate limits count per host. The probe
  also returns what its criteria say is wrong with its
  own host, so a fleet that agrees on a pending reboot
  or on legacy iptables rules is reported with the
  warning rather than as consistent. Without subagents
  the skill probes one host after another and produces
  the same tables.

- **Taking over heinzel is two mechanisms.** The
  `hostwarden-adopt` skill is asked for by name —
  `/hostwarden-adopt`, or the same request in prose — and
  reads the old checkout. `heinzel-legacy` and
  `heinzel-adoption` are reflexes that fire on a host
  without anyone asking. The skill states that division
  rather than leaving it to be inferred, so it does not
  drift into a third place.

- **Examples name nobody real.** Hostnames and domains
  come from RFC 2606 (`server1.example.com`), addresses
  from RFC 5737 and RFC 3849, and people from the
  Alice-and-Bob convention the field has used for
  decades. `.claude/rules/instruction-authoring.md`
  states it, along with where a new instruction belongs
  and why instruction files never narrate their own
  history, and `instructions-test.sh` enforces the parts
  a pattern can decide: documentation addresses in both
  IP families, example mail addresses, and the target of
  an `ssh` or `scp` command. It also walks every
  instruction pointer — `rules/` paths, skills named in
  prose, and a skill's frontmatter name against its own
  directory — because a pointer that resolves to nothing
  fails silently, which is the failure the whole layout
  is arranged to avoid. Hostnames at large it
  deliberately leaves alone — a command may legitimately
  contact `security.debian.org`, and no pattern tells
  that from a borrowed name.

- **The instruction set is `AGENTS.md`.** That is the
  file name Claude Code, OpenCode, Codex and Cursor all
  read natively, so hostwarden's rules reach a tool
  without it having to know about Claude Code at all.
  `CLAUDE.md` stays as a thin file that imports it and
  adds the handful of things only Claude Code has — the
  taboo guard hook, the SessionStart hooks, the pickers,
  the slash commands. It is not there for old versions:
  Claude Code also declines to read `AGENTS.md` directly
  on Amazon Bedrock, with telemetry off, and in the
  first session after every upgrade, and a session with
  no project instructions at all is not something a tool
  that works on production servers may have.

- **`AGENTS.md` keeps the trigger, the file keeps the
  procedure.** It is down from 668 lines to 337, and
  from 3356 words to about 2250, because a moment and
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
  says so rather than leaving it to be discovered. When
  an upgrade moves a topic between mechanisms,
  `bin/hostwarden-migrate` moves the matching override
  with it instead of leaving it at a path nothing reads
  — which matters for a checkout adopted from heinzel,
  where such files already exist.
- **Repo-development conventions load only when repo
  files are read.** `.claude/rules/repo-release.md`
  carries versioning, tagging, changelog style and the
  heinzel porting trailer, scoped to `VERSION`,
  `CHANGELOG.md`, `.github/` and the hooks, so a
  sysadmin session never pays for them.

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
  2600 lines of instruction load when someone asks
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
  are relocated with them.** An override is found by
  the file name it overrides, and those files left
  `rules/` for the `hostwarden-os-install` skill, so
  a personal `memory/custom-rules/os-replacement.md`,
  `dual-boot.md`, `efi-boot.md`, `cloud-image.md` or
  `partition-staging.md` would stop taking effect at
  its old path. `bin/hostwarden-migrate` moves each
  one into `memory/custom-rules/hostwarden-os-install/`
  under the same name, and keeps a file whose
  destination already exists so nothing is
  overwritten. It runs from the update path, so a
  checkout refreshed with a plain `git pull` keeps the
  old paths until `bin/hostwarden-update` runs once.

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
  (`/hostwarden-adopt <path>`, or the same request in
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
