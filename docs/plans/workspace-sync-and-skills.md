# Plan: workspace sync and own skills

**Status:** proposal for discussion, nothing implemented. Tool
behaviour marked *verify* has to be confirmed before it is built
on.

**Builds on #28** (pull request #33). That change makes `memory/`
the workspace: a git repository of its own, created by
`bin/hostwarden-init` or joined with `--clone`, ignored by
hostwarden as a whole, with the templates in `templates/memory/`,
personal files ignored inside it, and solo installs migrated on
update. This plan covers what it leaves open: keeping several
machines in step, own skills, and moving a team fork over.

## Why

- **Admins work from more than one machine.** A workspace with a
  remote can be shared, but nothing pulls or pushes it, so the
  second machine is as old as its last manual `git pull`.
- **Own skills have no place.** `memory/custom-rules/` adjusts a
  shipped skill (`rules/overrides.md`). A new skill, or one that
  takes a shipped skill's place, can only be written into the
  product tree, which an update overwrites and which operations
  mode (#33) protects.
- **Teams that followed the old team mode run a fork** with
  `memory/` in its history. They need a way out that keeps that
  history.

## Keeping machines in step

- **Session start:** where the workspace has a remote, the update
  hook runs `git pull --rebase` in `memory/` after updating
  hostwarden. A conflict is reported and left alone.
- **Session end:** `rules/changelog.md` already ends every session
  with a journal line. It gains a step that commits `memory/` with
  that line as the message, and pushes where there is a remote.
- **Merging:** `changelog.log` is append-only, so `init` writes
  `merge=union` for it into the workspace's `.gitattributes`, and
  two machines' entries land without a conflict. `memory.md` and
  `todo.md` merge normally; their conflicts are real and go to the
  user.
- **Personal files:** #33 ignores `user.md` in every workspace. A
  solo admin on two machines wants the SSH user names on both. An
  `init --solo` that commits `user.md` would cover that — or the
  names move to `memory/servers/<host>/` for solo use. To decide.

## Own skills

Three cases, three mechanisms. A second skill whose text claims
to outrank a shipped one is not among them: the harness picks by
description before any text is read, so both compete for the same
requests.

1. **Adjust a shipped skill** — `memory/custom-rules/<skill>.md`
   with `## Add:`, `## Replace:`, `## Remove:`, as today. It stays
   the recommended way, because the rest of the skill keeps
   receiving updates.
2. **Add a skill** — `memory/skills/<name>/SKILL.md`, made visible
   where each tool looks:
   - *Claude Code* reads `.claude/skills/`, `~/.claude/skills/`
     and directories passed with `--add-dir`, and follows symlinks
     ([docs](https://code.claude.com/docs/en/skills.md)). It also
     loads `<subdir>/.claude/skills/` as directory-qualified
     skills (`/memory:<name>`), so `memory/.claude/skills/` might
     need no machinery at all — *verify* when nested discovery
     happens.
   - *OpenCode* reads directories listed under skills in
     `opencode.json`; a later source overrides an earlier one
     ([docs](https://opencode.ai/v2/docs/skills/)).
   - *Codex* reads `.agents/skills/`; further locations: *verify*.
3. **Replace a shipped skill** — same `name`. Claude Code's
   documented precedence is enterprise, then personal, then
   project; nothing else lets one skill displace another. A
   qualified nested name never collides, so nested discovery
   cannot do this case.

**If case 3 is wanted,** `.claude/skills` becomes an ignored
directory with one link per skill, pointing into `memory/skills/`
where a name collides. That costs more than the links:

- `instructions-test.sh` and `check-skills.sh` assert that
  `.claude/skills` is one link to `.agents/skills/`; both change.
- The README → Windows repair restores that one link.
- Every link is one more thing native Windows gets wrong.

So: nested discovery for case 2 if it holds, and case 3 only if
someone needs it. A replaced skill stops receiving updates, and
whatever lists the workspace should name each one.

## Security

- The workspace holds hostnames, addresses, topology and the
  blacklist, so its remote must be private. `init` and the README
  say so; hostwarden cannot check it on every forge.
- `init` installs a pre-commit hook in the workspace that runs
  `betterleaks git --pre-commit --staged`. Not `.githooks/` from
  this repository: its pre-push runs `scripts/check.sh`, which does
  not exist at the workspace's root.
- *Open:* encryption at rest (git-crypt, age) for a remote the
  team does not run. It costs readable diffs and the union merge.

## Moving a team fork over

`git subtree split --prefix=memory` turns the fork's `memory/`
history into a branch that becomes the workspace, history
included. The fork is then reset to upstream and can go. A
documented manual step, never something a hook does to a team's
repository.

## Phases

Each a pull request of its own, each leaving a working hostwarden:

1. Session sync: pull at start, commit and push at the end, union
   merge, the personal-files decision.
2. Workspace pre-commit hook and the private-remote warning.
3. Own skills, case 2; case 3 only on demand.
4. The team-fork move, documented.

## Open questions

- Commit and push at session end automatically, or after one
  confirmation per session? Automatic keeps a second machine
  current; asking is what a team may want before anything leaves
  the laptop.
- Does the workspace carry team conventions of its own, or is
  `memory/custom-rules/all.md` enough?
- Does Codex offer an extra skill location?
