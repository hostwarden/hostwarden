# Running Hostwarden in production

How a checkout becomes the one that administers your
servers, where it comes from, and how a team or
several machines share what it learns.

## Operations and development

A Hostwarden checkout does one of two jobs, and the
workspace decides which:

- **Operations** — `memory/` is the workspace
  (`bin/hostwarden-init`). Hostwarden administers
  servers. Its own files are read-only here, so the
  auto-update keeps working and every change to
  Hostwarden goes through review.
- **Development** — no workspace. The session changes
  Hostwarden itself and reaches no server, not even
  the local machine. Every git worktree counts as
  development, whatever its main checkout is.

In Claude Code a hook announces the mode at session
start and another enforces it. In development the
first also puts a shim in front of `ssh`, `scp`,
`sudo` and the rest on the `PATH` of every command
the agent runs, so they refuse however they are
started; `git push` still reaches the real `ssh`.
Other tools follow the same rule from `AGENTS.md`.

When development needs to know something about a
live server, the agent hands the question to a
session in your operations checkout — a message to
one already running, or one command that starts it —
and reads the answer. That session runs the access
lists and the full first-connection pipeline as
always, a one-line question included. Details:
`rules/server-check-handoff.md`.

**Validating a branch** needs the branch's own
instructions on a server, and those never go near
production. Keep a second operations clone for test
servers only:

```
git clone <hostwarden-url> hostwarden-test
cd hostwarden-test
git switch <branch>
bin/hostwarden-init
```

Give it a workspace of its own — never `--clone` of
the production one — and list your production hosts
in its `memory/blacklist.md`. Off `main` it does not
auto-update; `git pull` brings the branch's next
push, and `bin/hostwarden-update --unpin` returns it
to `main`.

## Where production comes from

Production runs a **clone** — of
`jpawlowski/hostwarden` itself, or of a mirror of your
own.

- **Straight from GitHub** is the default and needs
  nothing else.
- **A mirror of your own** is optional. It is worth it
  when Hostwarden has to come from your internal git
  hosting, when an update should reach production only
  once your mirror has taken it (the mirror job is the
  gate), or when you carry local patches. Name it
  `hostwarden-mirror`. Its `main` stays an exact copy of
  upstream's so the job below can keep it current;
  patches of your own go on a branch of their own, and
  a checkout on that branch gets no auto-update.
- **A GitHub fork is not a production copy.** It exists
  to send pull requests: a fork of a public repository
  cannot be private, and an owner gets one fork of a
  repository, which pull requests need.

These names are recommendations. Nothing checks them:
the workspace alone decides whether a checkout runs
production (see
[Operations and development](#operations-and-development)).

## Keeping a mirror current

`bin/hostwarden-mirror` fast-forwards the mirror's
`main` to upstream's and pushes every tag it lacks. It
needs git and nothing else, so it runs from any CI or
cron job — not from an operator's machine: it refuses
to run in an operations checkout. It never overwrites:
when the mirror's `main` has commits of its own, or a
tag of the mirror names another commit, it lists them,
pushes nothing and fails the job.

The token goes into `HOSTWARDEN_MIRROR_TOKEN`, the user
into the URL, so the token never lands on a command
line. Run the job from a repository other than the
mirror, whose `main` has to stay upstream's. Give the
token write access to the mirror's contents — on
GitHub also to its workflows, since Hostwarden ships
some — and turn Actions off in a GitHub mirror, which
would otherwise run Hostwarden's own.

<details>
<summary>GitHub Actions (also Gitea and Forgejo Actions)</summary>

```yaml
name: hostwarden mirror
on:
  schedule:
    - cron: "17 3 * * *"
  workflow_dispatch:
permissions: {}
jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - run: git clone --depth 1 https://github.com/jpawlowski/hostwarden.git
      - run: >-
          hostwarden/bin/hostwarden-mirror
          https://x-access-token@github.com/<org>/hostwarden-mirror.git
        env:
          HOSTWARDEN_MIRROR_TOKEN: ${{ secrets.HOSTWARDEN_MIRROR_TOKEN }}
```

</details>

<details>
<summary>GitLab CI</summary>

A pipeline schedule runs it, with the token as a
masked CI/CD variable:

```yaml
hostwarden-mirror:
  image:
    name: alpine/git
    entrypoint: [""]
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
  script:
    - git clone --depth 1 https://github.com/jpawlowski/hostwarden.git
    - hostwarden/bin/hostwarden-mirror
      "https://oauth2@gitlab.example.com/<group>/hostwarden-mirror.git"
```

</details>

Production then clones the mirror instead of GitHub.

## Team setup and several machines

A team — or one admin on several machines — shares
the workspace, `memory/`, through a git remote of its
own. **Keep that remote private:** the workspace
holds hostnames, addresses, the blacklist and the
layout of your network. Create it private; the
recommended name is `hostwarden-workspace`, and nothing
checks it. Hostwarden itself stays an unmodified clone
that keeps updating.

1. Set the workspace up as the
   [README](../README.md#steps) describes, then
   publish it once:
   ```
   bin/hostwarden-sync commit "Start the shared workspace"
   git -C memory remote add origin <private-repo-url>
   git -C memory push -u origin main
   ```
2. On every other machine, clone Hostwarden and
   join:
   ```
   bin/hostwarden-init --clone <private-repo-url>
   ```
3. From then on it keeps itself in step. Every
   session starts with `bin/hostwarden-sync pull`
   (Claude Code runs it for you) and ends with a
   commit of the files it changed — only those, so
   parallel sessions on one machine keep out of each
   other's work. It asks once per session before
   pushing. A changelog both machines
   added to merges on its own; two different edits
   of the same `memory.md` stop the pull and are left
   for you.
4. Personal files never reach the remote:
   `memory/.gitignore` names `user.md`,
   `blacklist.md`, `readonly.md` and `opencode.json`.
   Add your own machine's hostname directory there
   (e.g. `/servers/my-laptop/`). Alone on several
   machines, you may want your SSH usernames on all
   of them: delete the `/user.md` line.
5. Every workspace commit is scanned for secrets by
   [betterleaks](https://github.com/betterleaks/betterleaks),
   and every push scans the whole history again. A
   push without it is refused, and so is a commit once
   the workspace has a remote; without one, a commit
   only says it was not scanned.

## Parallel sessions

Sessions that change the same host — two windows, or
teammates on different workstations — see each other.
Before its first change a session registers on the
host itself, in `/tmp/hostwarden/` (no root needed),
with who it is, where it runs and what it is doing.
Another live entry makes Hostwarden say so and ask
whether the two get in each other's way; a session on
the same machine can be messaged directly. Sessions
that only read — housekeeping, audits — register
nothing. Details: `rules/parallel-sessions.md`.
