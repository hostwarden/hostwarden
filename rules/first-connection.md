# First-Connection Checklist

The ordered pipeline that runs on **every** remote
connection — and on every local-mode session, with
the remote-only steps skipped — before any
user-requested command.

**There is no "quick question" exception.** `df -h`,
`uptime`, `uname -a`, and every other "one-liner"
runs this pipeline first. If following the pipeline
will visibly delay the answer, say so up front
("first-contact onboarding on this host — one
moment") — don't skip.

## Order

0. **Worktree check.** Once per session: refuse
   to reach any machine from a linked git
   worktree. See `rules/access-control.md` →
   Linked Worktrees.
1. **Blacklist check.** Refuse if listed. See
   `rules/access-control.md`.
2. **Read-only check.** Switch to read-only mode if
   listed. See `rules/access-control.md`.
3. **DNS check.** New hostname (no
   `memory/servers/<hostname>/` yet): run alias
   detection. Known hostname: verify the current IP
   still matches the `- IP:` field in server memory.
   See `rules/dns-aliases.md` for both.
4. **SSH user lookup** (first connection only). See
   `rules/ssh-user.md`.
5. **OS detection.** See `rules/os-detection.md`.
6. **Server memory file.** Create on first
   connection, read on every subsequent connection.
   See `rules/server-memory.md`.
7. **Activity check.** Every connection, not just
   the first. See `rules/activity-check.md`.
8. **Heinzel legacy check.** Only in an installation
   that has something to do with Heinzel: an
   `Adopted from heinzel:` line in `memory/user.md`,
   a `heinzel legacy:` line or an unresolved
   `heinzel-inventory.md` in this host's memory, or
   `heinzel` entries in the activity check above —
   that last one catches a host Heinzel touched even
   though this installation never ran it. Otherwise
   skip the step and read nothing.

   When it does apply: first connection, plus every
   connection while a `deferred` line or an
   unresolved inventory is there. One batched probe,
   folded into step 5 where possible, silent unless
   it finds something. See `rules/heinzel-legacy.md`.
9. **Then** execute the user's request.

## Local mode

In local mode (`localhost`, the user's own
hostname), run step 0, then skip steps 1–4 — they
are remote-only (see `AGENTS.md` → How It Works →
Local mode). Still run OS detection, server memory,
activity check, and the Heinzel legacy check — on
the workstation the latter looks at scheduled runs
instead of backup directories
(`rules/heinzel-adoption.md`).

## Why it's mandatory

Skipping steps has caused real incidents: stale
memory files masking ownership changes, activity
checks missing concurrent teammate work, and
blacklisted hosts getting commands they should
never receive. The overhead of a few extra commands
is acceptable; silent skipping is a bug.
