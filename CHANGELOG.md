# Changelog

## Unreleased

- **Proxmox VE, OPNsense, pfSense and Home Assistant OS are
  recognised as appliances.** Detection finds them by a marker,
  records `Appliance:` in server memory, and reads a file under
  `rules/appliance/` on top of the family file that replaces what
  would be wrong there — `dist-upgrade` on Proxmox, the web UI and
  `configctl` instead of `sysrc` on the firewalls, the `ha` CLI on
  Home Assistant, where Hostwarden also installs the ha-mcp app on
  request so an AI client can work on the configuration.
  Housekeeping, the audits and the activity check follow the merged
  file, and an override can target an appliance file like any other.
- **Detection is one SSH call.** OS, version, login shell, hardware
  and appliance markers come back from a single probe that runs in
  sh, bash, zsh, csh and tcsh alike; later connections send only a
  short version check. It stops at a console menu
  instead of answering it, and every later command goes through
  `sh -s`, so a csh login works too.
- **Housekeeping checks Home Assistant on a normal Linux
  host.** It tells Container, Supervised and Core apart,
  reports the running version and runs the config check
  each install type has. Supervised and Core are reported
  once as unsupported since 2025.12; migrating stays your
  decision.
- **The README is back to getting started.** Install,
  first steps, what Hostwarden does and how it keeps you
  safe fit on one page; everything deeper — native
  Windows, mirrors and teams, updates, the AI tools,
  automation, overrides — lives under `docs/`, with
  the optional parts folded away until you open them.
- **A development session that needs a live server hands
  the question over** to a session in your operations
  checkout, which runs the access lists and the full
  pipeline and answers back; the refusal and the session
  start name that checkout. `docs/operations.md` shows how
  to validate a branch from a second, test-only clone.
- **Parallel sessions on one machine keep out of each
  other's workspace changes.** `bin/hostwarden-sync
  commit` takes the files a session names and nothing
  another session changed or staged, and waits out a
  moment when another session holds the index. A session
  commits when it is done with a host, not at a session
  end it rarely sees. `pull` no longer stashes
  uncommitted changes from under a running session: it
  fast-forwards past them where git can, and otherwise
  leaves the workspace alone and says so. Changes a
  deleted or crashed session left behind are found
  through the host's session register and committed on
  their own after you say so.
- **Sessions that change the same host see each
  other.** Before its first change a session registers on
  the managed host itself, in `/tmp/hostwarden/`, without
  root: who, from which workstation, doing what, with a
  heartbeat. Another live entry — a second window or a
  teammate — makes Hostwarden say so and ask whether the
  two collide; a session on the same machine can be
  messaged directly. Read-only sessions register nothing,
  and a stale entry can be removed by anyone.
- **Personal Claude Code files stay out of git**, the
  ones Claude Code adds later included: everything under
  `.claude/` except the shared configuration is ignored,
  and so is `CLAUDE.local.md`. The layout test fails when
  a tracked file matches the ignore rules.
- **A checkout either operates servers or develops
  Hostwarden.** `bin/hostwarden-init` turns `memory/`
  into the workspace, a git repository of its own, and
  only a checkout with a workspace reaches a server. One
  without it — a fresh clone, a fork, and every git
  worktree — is for changing Hostwarden and refuses
  `ssh`, `scp`, `sudo` and the other tools that reach a
  server, however they are started: in Claude Code a
  shim that fails in their place comes first on the
  `PATH` of every command, rsync's own `ssh` included,
  while `git push` still reaches the real one. In an
  operations checkout Hostwarden's own files are
  read-only, so a local edit cannot stop the
  auto-update. A team shares the workspace through a
  remote of its own (`bin/hostwarden-init --clone`),
  which also keeps one admin's machines in step:
  `bin/hostwarden-sync` pulls at session start, commits
  at the end and asks once before it pushes. Changelogs
  from two machines merge on their own, and a workspace
  commit is scanned for secrets — with betterleaks
  required once the workspace has a remote, so nothing
  unscanned can be pushed. A skill of your own goes
  into `memory/.claude/skills/` and travels with the
  workspace.
  Claude Code announces the mode at session start and
  enforces it with a hook; `AGENTS.md` carries the same
  rule for every other tool. The templates live in
  `templates/memory/`.
- **Hostwarden runs in the Claude desktop app.**
  `docs/ai-tools.md` has a section for the app's Code
  tab: open the folder with the worktree option off,
  set environment variables in
  `.claude/settings.local.json`, pick the
  permission mode from the menu, and use the app's own
  scheduled tasks where the CLI would use cron.
- **A git worktree no longer hides the blacklist.**
  `memory/` is gitignored, so a session in a linked
  worktree — the desktop app can make that the default
  — had no blacklist, no read-only list and no server
  memory, and lost whatever it learned with the
  worktree. Hostwarden now refuses to reach any machine
  from one, and a session-start hook says so at once.
- **The taboo guard can only be switched off before a
  session starts.** The `env` key of a Claude Code
  settings file reaches the guard mid-session, so a
  write there could switch it off without any shell
  command. The guard now honours the variable only for
  a session that started with it, which a session-start
  hook records; a new hook keeps the variable out of
  settings files for the next session, and every session
  that starts with the guard off opens with a note
  saying so.
- **A checkout can follow a release line.**
  `bin/hostwarden-update --follow 1` takes every 1.x.y
  release, `--follow 1.2` only 1.2.x fixes; the
  auto-update then moves to the newest matching
  `vX.Y.Z` tag instead of pulling `main`. The line is
  kept in the checkout's own git config, so each
  machine picks its own. `--pin` still sets one exact
  version, and `--unpin` returns to `main` from either.
- **Your own mirror of Hostwarden stays current
  unattended.** `bin/hostwarden-mirror` fast-forwards a
  mirror's `main` and carries the tags from any CI or
  cron job, and fails instead of overwriting commits
  the mirror has of its own. `docs/operations.md`
  explains when production should clone a mirror
  rather than GitHub, why a GitHub fork is only for pull requests, and has
  job examples for GitHub Actions and GitLab CI.

- **`bin/hostwarden-doctor` says what your workstation is
  missing**, and which feature each missing tool switches
  off, with the install command for your package manager.
  It runs quietly at session start, so the agent knows its
  limits before it hits them, and never installs anything.
- **The taboo guard no longer depends on bash.** Without
  bash the hook could not start, which Claude Code does not
  treat as a block, so the guard silently did not run. Every
  hook now starts with `sh`, and the layout test fails on
  one that does not.
- **The update check names the real cause** when the
  checkout is not a clone, and `bin/hostwarden-update`
  also when git is missing, instead of reporting a detached
  HEAD. At session start a missing git is the doctor's to
  report.
- **Email only counts `sendmail` or `msmtp` as a
  transport**, on the workstation and on the server. A host
  with only `mail` or `mailx` goes on to the install
  question, since neither can carry the headers Hostwarden
  writes.
- **Native Windows: `docs/install.md` lists the three settings
  symlinks need** and how to repair a clone made without
  them. Without them Git Bash copies where it should link,
  so a DNS alias got its own drifting copy of the server
  memory; Hostwarden and `bin/hostwarden-adopt` now make
  sure a link is a link.
- **For contributors: `sh scripts/check.sh` runs
  everything CI runs**, now including a secret scan of the
  whole history, workflow linting and the 80-column wrap.
  Opt-in git hooks run it before each push.
- **Every text file checks out with LF**, on Windows too
  and whatever `core.autocrlf` says — the rule files and
  skills as well as the shell scripts, which were the only
  files pinned so far. An
  `.editorconfig` carries the same settings and the
  80-column wrap into the editor.

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
  `templates/memory/` are scanned too, and `settings.json` is
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

- **An MTA Hostwarden installs queues the mail.** The
  default was `msmtp`, which has no queue: it connects
  when called and exits non-zero when the relay does not
  answer. Nothing that sends unattended mail on a server
  — cron, unattended-upgrades, Hostwarden's own reports —
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
  to send a mail, before Hostwarden knew where it would
  send from or whether there was an attachment. The
  workflow loads first now, and each step reads its own
  part when it gets there. An exchange that stops early —
  the where-to-send-from question the first mail per host
  asks — reads the workflow and nothing else. Transport is
  split again by the answer to that question, because the
  two sides share no step: sending from your workstation
  no longer loads the consent gates, the MTA choice and the
  privilege-dropping that only a server has.

  If you overrode one of those topics, it has its own
  override key now — `hostwarden-email/transport-local.md`,
  `…/transport-remote.md`,
  `…/compose.md`, `…/send-verify.md` under
  `memory/custom-rules/`. An existing
  `hostwarden-email.md` still applies as a whole; a
  section in it that named one of the moved headings
  matches nothing, and Hostwarden says so and asks rather
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

- **Taking over Heinzel is two mechanisms.** The
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
  read natively, so Hostwarden's rules reach a tool
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
  procedure.** It is down from 668 lines to 315, and
  from 3356 words to about 2000, because a moment and
  the file that covers it is one line — not a
  paragraph that restates what the file already says.
  Nothing that has to fire unasked left: the taboos,
  the first-connection pipeline with its no-quick-
  question clause, least privilege, the ask-before
  list, port 22, secrets, untrusted server output. The
  four sections describing skills are gone, because a
  skill's description is in context every turn anyway.
  `rules/firewall-changes.md`, `rules/overrides.md`
  and `rules/session-start.md` now hold procedures
  that used to sit inline — the last of those is the
  preferences and overrides to load before a
  session does anything, which is a moment like any
  other and not the thing that keeps you off a
  blacklisted host.
- **Overrides mirror the path of what they
  change.** `rules/os/debian.md` is overridden in
  `memory/custom-rules/os/debian.md`, a skill's
  `references/ssh.md` in `<skill>/ssh.md` — one rule,
  and two skills can ship a `report-format.md` without
  their overrides colliding. Hostwarden names the
  overrides it loaded at session start (`Overrides: all,
  backups`), and says
  when one matches nothing shipped instead of ignoring
  it silently. Where the shipped file has since split —
  your `transport.md` against a shipped
  `transport-local.md` and `transport-remote.md` — it
  names both siblings and asks which one you meant,
  rather than calling your override a stale name
  or picking the nearer of the two. A skill's *trigger*
  cannot be overridden per file and belongs in
  `all.md`; `rules/overrides.md` says so rather than
  leaving it to be discovered. When an upgrade moves a
  topic between mechanisms, `bin/hostwarden-migrate`
  moves the matching override with it instead of
  leaving it at a path nothing reads — which matters
  for a checkout adopted from Heinzel, where such files
  already exist.
- **Repo-development conventions load only when repo
  files are read.** `.claude/rules/repo-release.md`
  carries versioning, tagging, changelog style and the
  Heinzel porting trailer, scoped to `VERSION`,
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
  files they override, so an override does not
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

- **Heinzel is now Hostwarden.** The project
  continues Heinzel 2.22.0 as an independent
  project under a new name. Scripts, skills,
  environment variables, the journal tag, the
  backup directory on servers and the SSH socket
  directory are renamed. The activity check still
  reads `heinzel` journal entries, and
  `HEINZEL_NO_UPDATE` still works. `hostwarden-migrate`
  renames skill overrides in `memory/custom-rules/`.
  See "Moving over from Heinzel" in `docs/operations.md`.
- **Both tools can work on the same hosts during a
  transition.** `contrib/heinzel-coexistence/` holds
  three custom rules for a Heinzel checkout: Heinzel
  then reads both journal tags instead of only its
  own, treats its server memory as a lead rather than
  a fact, leaves Hostwarden's files alone, and stops
  reading an adopted backup directory as data loss.
  Hostwarden warns in the other direction when a
  Heinzel entry is minutes old, and does not adopt a
  host that Heinzel still uses.
- **A Heinzel installation can be taken over
  wholesale.** `bin/hostwarden-adopt <path>` records
  the move once in `memory/user.md`, which is what
  lets an installation that never ran Heinzel skip
  the per-host legacy check entirely. It copies
  memory, access lists and overrides out of an old
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
- **Hostwarden adopts what Heinzel left on a
  host.** The first connection reports Heinzel's
  config backups and scratch directories, and offers
  to move them under the new name — after naming
  which of them the retention cleanup would then
  delete, because `/var/backups/heinzel/` was never
  cleaned by Hostwarden. In local mode it reports
  scheduled runs that still point at `bin/heinzel-*`
  and would fail silently. The answer is recorded in
  server memory, so the check runs once.
- **A backup restores into a fresh clone.**
  `--restore` took the templates the repo ships in
  `memory/` for user data and refused without
  `--force`, and restoring overwrote them with the
  archive's older copies. Tracked templates now
  count as empty and keep the checked-out version.

Hostwarden starts its own versioning at 1.0.0. The
releases before the fork were Heinzel's, their numbers
do not continue here, and their notes are not repeated
— they are in git history and at
[wintermeyer/heinzel](https://github.com/wintermeyer/heinzel).
