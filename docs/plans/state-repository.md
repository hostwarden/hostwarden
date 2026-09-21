# Plan: hostwarden and your state in separate repositories

**Status:** proposal for discussion. Nothing here is implemented,
and every tool behaviour marked *verify* has to be confirmed
before it is built on.

## Why

Today hostwarden and everything a user accumulates share one git
checkout. `memory/` is gitignored in solo mode, and team mode
un-ignores parts of it in `.gitignore` so they can be committed.
That has four costs:

- **Team mode needs a fork of hostwarden.** Team data is
  committed into a checkout of the product, so every team pushes
  to its own copy. Each update is a merge of upstream into that
  copy, and the fork can never be published.
- **The session-start `git pull` can conflict.** It assumes a
  clean checkout. A team fork is not one.
- **A single admin has the same need and no way to meet it.**
  Admins work from more than one machine. The only way to move
  or back up state is `bin/hostwarden-backup`, a tarball copied
  by hand. It has no history and no sync.
- **Own skills have no place.** `memory/custom-rules/` can add
  to, replace or remove sections of a shipped skill
  (`rules/overrides.md`). A new skill, or one that takes a
  shipped skill's place, has to be written into the product tree,
  where the next update overwrites it.

## Goals

- The hostwarden checkout stays exactly as upstream ships it.
  An update is a `git pull` that cannot conflict, and pinning a
  tag keeps working.
- Everything a user owns lives in one directory, which is its own
  git repository. It can be hosted on any forge (GitHub, GitLab,
  Forgejo, Codeberg, a bare repo over SSH) or on none.
- Solo and team use the same layout. The only difference is which
  files the state repository shares.
- Own skills can be added, and can extend or replace a shipped
  skill. This works in Claude Code and OpenCode, and in Codex as
  far as Codex allows.
- No secret ever reaches the state repository. Its commits are
  scanned the same way hostwarden's are.

## Non-goals

- Syncing without git.
- Keeping `memory/` inside the hostwarden history for anyone.
  Team forks are migrated out once (see Migration), not
  supported side by side.

## Proposal

### Layout

    hostwarden/              upstream clone, never committed to
      AGENTS.md, rules/, .agents/skills/, bin/, ...
      templates/memory/      what memory/*.example is today
      memory/                the state repository — own .git,
                             ignored by hostwarden as a whole
        .git/
        .gitignore           written by init, per mode
        .gitattributes       merge=union for changelog.log
        user.md              personal; see Personal files
        servers/<host>/      memory.md, changelog.log, rules.md
        custom-rules/        overrides, unchanged
        skills/<name>/       own skills, SKILL.md + references/
        network.md, blacklist.md, readonly.md, ...

The state repository stays nested at `memory/` rather than moving
elsewhere behind a symlink or an environment variable. Every rule
and skill names `memory/` literally, a symlink is exactly what
native Windows handles worst, and an environment variable is
something an agent can forget to expand. Nested, nothing in the
instruction text changes.

hostwarden's `.gitignore` shrinks to `memory/`. The templates move
out to `templates/memory/`, because a tracked file inside the
nested repository's directory makes both repositories claim it.

### Personal files

`user.md` holds SSH user names, which are per person, and
`opencode.json` holds per-machine tool settings. The state
repository's `.gitignore` depends on the mode `init` was given:

- **solo** — `user.md` is committed, so a second machine gets it
  too. `opencode.json` stays ignored.
- **team** — `user.md` and `opencode.json` are ignored, and so are
  `servers/localhost/` and the directory named after each member's
  own machine, as the team section of today's `.gitignore` says.

### One script to set it up

A new `bin/hostwarden-state`, to be named at implementation time:

- `init [--team]` — `git init` in `memory/` and write
  `.gitignore` and `.gitattributes`. Enable the betterleaks
  pre-commit hook there. Copy `templates/memory/` for anything
  missing.
- `clone <url>` — clone an existing state repository into
  `memory/`, on a second machine or for a new team member.
- `status` — whether there are uncommitted changes, whether a
  remote is set, and whether the branch is ahead or behind.

It creates no remote and pushes nothing on its own. Where the
state lives is the user's decision, and so is making it private.

### Keeping machines in step

- **Session start:** the update hook that pulls hostwarden also
  runs `git pull --rebase` in `memory/` when a remote is set.
  Conflicts are reported and left alone.
- **Session end:** `rules/changelog.md` already ends every
  session with a journal line. It gains a step that commits
  `memory/` with that line as the message, and pushes when a
  remote is set.
- `changelog.log` is append-only, so `merge=union` in the state
  repository's `.gitattributes` lets two machines' entries land
  without a conflict. `memory.md` and `todo.md` merge normally.
  Their conflicts are real and have to be shown to the user.

### Own skills

**Three cases, three mechanisms.** A second skill whose text says
it matters more than the shipped one is not among them. The
harness picks a skill by its description before any text is read,
so the two compete for the same requests. Which one fires is then
up to the model, and a sentence inside a skill cannot stop the
other from loading.

1. **Adjust a shipped skill** — add a step, replace a section,
   drop a check. This exists today:
   `memory/custom-rules/<skill>.md` with `## Add:`,
   `## Replace:` and `## Remove:` (`rules/overrides.md`). It
   moves into the state repository unchanged. It remains the
   recommended way, because the rest of the shipped skill keeps
   receiving updates.
2. **Add a skill** — `memory/skills/<name>/SKILL.md`. It has to
   become visible where each tool looks:
   - *Claude Code* finds skills in `.claude/skills/` (project),
     `~/.claude/skills/` (personal) and in directories passed
     with `--add-dir`. It follows symlinks in all of them
     ([docs](https://code.claude.com/docs/en/skills.md)).
   - *OpenCode* reads further directories listed under skills in
     `opencode.json`, and a later source overrides an earlier one
     ([docs](https://opencode.ai/v2/docs/skills/)).
   - *Codex* reads `.agents/skills/`. Whether it takes more
     locations: *verify*.
3. **Replace a shipped skill** — same `name` as the shipped one.
   Claude Code has a documented precedence for this: enterprise,
   then personal, then project. A skill higher up wins, and
   nothing else lets one skill displace another. OpenCode:
   the explicit config source wins.

**Proposed mechanism for 2 and 3: a generated link directory.**
`.claude/skills` stops being one tracked symlink to
`.agents/skills/` and becomes an ignored directory of links. There
is one link per shipped skill and one per `memory/skills/<name>`.
Where the names collide, the link points into `memory/`, so
replacing a shipped skill is deliberate and visible in one place.
The session-start hook rebuilds the directory, the way
`check-skills.sh` checks the link today. OpenCode gets
`memory/skills` through the `opencode.json` that `init` writes.

- *verify:* Claude Code picks up links added to `.claude/skills/`
  while a session is already running. Otherwise the rebuild has
  to happen before the session reads its skills.
- *verify:* whether nested discovery would do this without any
  links. Claude Code loads `<subdir>/.claude/skills/` as
  directory-qualified skills (`/memory:<name>`). That covers
  case 2 without any machinery, but not case 3, because a
  qualified name never collides with a shipped one.
- A replaced skill no longer receives updates. `status` should
  list every replacement, so a user sees what they have taken
  over maintaining.

### Updates

The update path stays `git pull` in a checkout nobody commits to.
It can no longer conflict. `bin/hostwarden-migrate` keeps moving
overrides when shipped files move, and now does it inside the
state repository, committing the move with a message that says
what moved and why.

### Backups

With a remote, the state repository is the offsite backup, with
history. `bin/hostwarden-backup` stays for anyone without one and
archives the same directory. It includes `.git/`, so a restore
gets the history back as well.

### Security

- The state repository holds hostnames, addresses, topology and
  the blacklist. It must be private. `init` and the README say so.
  hostwarden cannot check it on every forge.
- `rules/secrets.md` already keeps secrets out of memory files.
  The betterleaks pre-commit hook that `init` installs enforces it
  at the commit, so a mistake is caught before it reaches a forge.
- *Open:* whether to offer encryption at rest (git-crypt, age) for
  teams that keep the state on a forge they do not run. It would
  cost readable diffs and the union merge.

## Migration

- **Solo users:** on the first update after the release,
  `bin/hostwarden-migrate` sees a `memory/` without `.git`. It
  explains the change and offers `init`. Files already there stay
  where they are.
- **Team forks:** `git subtree split --prefix=memory` turns the
  fork's `memory/` history into a branch that becomes the state
  repository, history included. The fork is then reset to
  upstream and can be deleted. This is a documented manual step,
  not something a hook does to a team's repository.
- **heinzel adopters:** `bin/hostwarden-adopt` copies into
  `memory/` today. It keeps doing so, followed by `init`.

## Phases

1. Templates to `templates/memory/`. hostwarden's `.gitignore`
   becomes `memory/`. Solo layout otherwise unchanged.
2. `bin/hostwarden-state` with `init`, `clone` and `status`, plus
   the state repository's `.gitignore`, `.gitattributes` and
   betterleaks hook.
3. Session integration: pull at start, commit and push at the end.
4. Own skills: the link directory, `opencode.json`, and the
   replacement listing in `status`.
5. Migration: the solo prompt in `bin/hostwarden-migrate`, the
   documented team-fork split, README and `CONTRIBUTING.md`.

Each phase is a pull request of its own and leaves a working
hostwarden behind.

## Open questions

- Commit and push at session end automatically, or after one
  confirmation per session? Automatic is what makes a second
  machine current. Asking is what a team may want before anything
  leaves the laptop.
- Should the state repository carry its own `AGENTS.md` section
  for team conventions, or is `memory/custom-rules/all.md` enough?
- Does Codex offer an extra skill location, or do own skills stay
  Claude Code and OpenCode only?
- Name of the script and of the directory in user-facing text:
  "memory" is what the agent reads, "state" is what a user backs
  up.
