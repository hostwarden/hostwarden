# Running Hostwarden in production

How a checkout becomes the one that administers your
servers, where it comes from, how it stays current,
how a team or several machines share what it learns,
how to back that up, and how to move over from
Heinzel.

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
`sudo`, `ansible`, `terraform` and the rest on the
`PATH` of every command the agent runs, so they
refuse however they are started; `git push` still reaches the real `ssh`.
Under WSL the shim also covers the Windows programs
that reach a server or administer the machine:
`ssh.exe`, `wsl.exe`, `powershell.exe` and the rest.
Other tools follow the same rule from `AGENTS.md`.

The taboo guard knows the mode as well. In
development it judges a command in full only when
the command can reach past your own files — it
names `ssh`, `sudo`, a container, VM or cloud tool —
or when the session runs as root or in the `disk`
group. Otherwise a commit message, a pull request
title or a search that names `mkfs` or `fdisk` is
text and goes through. SSH keys, `sshd_config`,
`diskutil` and the Windows taboos stay guarded in
every mode, and so does power off on a machine
running systemd, which lets you power off without
root.

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

**Trying a command** needs no server at all when a
container answers it: whether a flag exists in this
release, what a package is called, what a config
test prints. `bin/hostwarden-lab` runs one per
family — debian, ubuntu, rhel (AlmaLinux), fedora,
suse (openSUSE Leap), alpine — from the official
image of the current stable release, with docker or
podman (OrbStack brings docker on macOS):

```
bin/hostwarden-lab exec debian -- apt-get -s install nginx
bin/hostwarden-lab list
bin/hostwarden-lab down
```

A lab container is neither a server nor local mode,
so a development session uses it directly. Each
worktree gets its own, labelled with the worktree's
name and a checksum of its path, and `down` removes
by that label alone. They run without a published
port, a host path, the engine's socket or any extra
privilege. In development the mode guard lets
`docker`, `podman` and `nerdctl` read, pull, build,
run and create on the local engine. It denies a run
that asks for host access or publishes a port — on
Linux the engine is root, on macOS a bind mount
reaches your home — a build that writes its result
to this machine, and another engine by `--context`,
`--host` or `DOCKER_HOST`. It also denies `exec` and
every command that changes containers, images or
volumes: `bin/hostwarden-lab exec` and
`bin/hostwarden-lab down` are the way in and out,
and touch the lab's own containers only. The lab
never starts the engine; start OrbStack, Docker
Desktop or `podman machine` yourself.

A container cannot answer for systemd services, the
firewall, kernel parameters, a reboot or the SSH
pipeline, and there is no container for FreeBSD or
macOS. For the Linux cases, a **lab VM** is a test
server of the test clone above:

```
bin/hostwarden-lab vm up debian --ops ~/hostwarden-test
```

It uses OrbStack or Lima, whichever is installed,
and refuses a `--ops` that is not an operations
clone, is the checkout the worktree came from, or
has no host on its blacklist. OrbStack machines
mount your Mac's home by default; the lab creates
them `--isolated`, without that mount, and installs
sshd with your public key for root, so the host is
`<name>.orb.local`. Lima's templates mount your home
too; the lab creates them `--mount-none`, and the
host is `lima-<name>` once `~/.ssh/config` has
`Include ~/.lima/*/ssh.config`. The development
session never uses the VM — the mode guard denies
`orb`, `limactl shell` and `lima` commands inside
one — and hands its question to a session in the
test clone (`rules/server-check-handoff.md`). The
guard also denies creating, starting, stopping,
deleting or changing a VM directly:
`bin/hostwarden-lab vm up` creates and starts one
without your home mounted, and
`bin/hostwarden-lab vm down` deletes the VMs that
worktree created, and no other.

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

## Updates and versioning

Hostwarden uses [semantic versioning](https://semver.org).
The current version is in the `VERSION` file; changes
are listed in `CHANGELOG.md`.

**Auto-update (Claude Code):** On every session start
in an operations checkout, a hook runs `git pull` —
or, on a release line, moves to its newest release —
and reports version changes. No action needed.
Auto-update is skipped in a development checkout,
when pinned to a tag (see below), when on a
non-`main` branch, or when `HOSTWARDEN_NO_UPDATE=1`
is set.

**Manual update (OpenCode / any tool):**

```bash
bin/hostwarden-update           # pull latest
bin/hostwarden-update --check   # check without pulling
```

**Follow a release line** instead of `main`:

```bash
bin/hostwarden-update --follow 1     # every 1.x.y release
bin/hostwarden-update --follow 1.2   # 1.2.x fixes only
```

The line is kept in this checkout's own git config
(`hostwarden.follow`), so each machine chooses its own
and an update never changes it. The auto-update checks
out the highest `vX.Y.Z` tag on the line;
pre-releases do not count.

**Pin to a stable version** (skip auto-updates):

```bash
bin/hostwarden-update --pin vX.Y.Z   # pin
bin/hostwarden-update --unpin        # back to main
```

A pin replaces a release line, and `--unpin` clears
both.

**Opt out of auto-update** without pinning:

```bash
export HOSTWARDEN_NO_UPDATE=1
```

In the desktop app, set it in the `env` of
`.claude/settings.local.json` instead — see
[Claude Code Desktop](ai-tools.md#claude-code-desktop).

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
the same machine can be messaged directly, to share
what each has seen, never to have one do what the
other may not (`rules/borrowed-rights.md`). Sessions
that only read — housekeeping, audits — register
nothing. Details: `rules/parallel-sessions.md`.

## Backup and restore

Everything the workspace holds is in `memory/`, so a
backup is one `tar` command. The tree is text and
typically well under a megabyte. No database, no
hidden dotfiles, no scattered config. Claude Code's
own personal files (`.claude/settings.local.json`,
`CLAUDE.local.md`) are not Hostwarden state and not in
the backup.

### What lives in `memory/`

- `user.md` — SSH usernames and language
  preference
- `blacklist.md`, `readonly.md` — access policies
- `service-policy.md` — per-service opt-out /
  opt-in for auto-reload and auto-restart
- `servers/<hostname>/` — per-server memory,
  changelog, todo, and per-server rule overrides
- `clusters/<name>/` — a hypervisor cluster or pool:
  its members, HA state and guest inventory
- `custom-rules/` — your global rule overrides
- `opencode.json` — your OpenCode config
- `network.md`, `housekeeping.md` — cross-server
  facts and custom checks

### Back up

```bash
bin/hostwarden-backup
```

Writes
`hostwarden-backup-<hostname>-<timestamp>.tar.gz` to
the current directory. Use `--list` for a dry run,
`-o <path>` to write somewhere specific.

### Restore

```bash
bin/hostwarden-backup --restore <file.tar.gz>
```

Refuses to overwrite existing `memory/` content
unless `--force` is passed. The archive is validated
before any files are written: all entries must live
under `memory/`, and symlink or hardlink entries are
rejected.

### In a team

With a shared workspace, most of `memory/` lives on
its remote already. The personal files that
`memory/.gitignore` keeps off it still need this
backup. The archive leaves out `memory/.git`; a
restore sets the workspace up first.

## Moving over from Heinzel

Hostwarden is a new clone, not an update of your
Heinzel checkout. Your state moves with the backup
script, which both projects share:

```bash
cd /path/to/heinzel && bin/heinzel-backup
cd /path/to/hostwarden && \
  bin/hostwarden-backup --restore /path/to/heinzel-backup-<host>-<ts>.tar.gz
bin/hostwarden-migrate
```

The migration renames skill overrides in
`memory/custom-rules/` from `heinzel-<skill>.md` to
`hostwarden-<skill>.md`. What else changed:

- Environment variables are now `HOSTWARDEN_*`.
  `HEINZEL_NO_UPDATE` still works; the guard only
  honours `HOSTWARDEN_GUARD_DISABLE`.
- New journal entries on your servers use the tag
  `hostwarden`. The activity check reads `heinzel`
  entries as well, so earlier work stays visible.
- Point Hostwarden at your old checkout — "my
  Heinzel is in ~/heinzel, take it over", or
  `/hostwarden-adopt ~/heinzel` in Claude Code. The copy
  itself is a script — `bin/hostwarden-adopt <path>`
  moves access lists, overrides, the host keys in
  `memory/known_hosts` and every server's memory
  across and renames what is found by name. Heinzel's
  memory of a host arrives as `heinzel-memory.md`,
  unchanged, until the host's onboarding splits it up;
  the workspace's history keeps the original. A
  `user.md` you already have gains the lines it lacks,
  and a value the two set differently is shown to you,
  not chosen. Whatever else your old `memory/` holds —
  Claude's auto-memory from Heinzel sessions, notes —
  is sorted item by item into overrides, the network
  notes or a host's memory, with one question. The skill
  then reads it and the changelogs into a per-host
  list of leads: the scripts, configs, units and cron
  jobs your sessions improvised, and asks whether
  those should get Hostwarden's names on the servers
  too: rename, keep, or decide per host. None of that
  contacts a server.
- Then, unless you choose "only copy", the skill
  onboards each host the way a first connection would
  have: read-only, host by host. It writes the host's
  memory in Hostwarden's form from what it finds, with
  your earlier decisions and notes carried over, runs
  the network profile, checks the leads, and on a
  hypervisor inventories and registers the guests —
  and adopts the guests still in your Heinzel
  checkout together with it, if you say so. It ends
  with what each host lacks against the baseline and
  asks which to take on first. With "only copy", the
  first connection to each host does the same later.
- Keeping Heinzel around during the switch?
  `contrib/heinzel-coexistence/` holds three custom
  rules for your Heinzel checkout so it reads both
  journal tags, treats its server memory as a lead
  rather than a fact, and leaves Hostwarden's files
  alone. Hostwarden warns in the other direction when
  a Heinzel journal entry is minutes old, and leaves
  a host alone that Heinzel still uses.
- On the first connection to a host, Hostwarden
  reports what Heinzel left there — config backups,
  scratch directories, and the scripts, units, cron
  files and config directories your sessions created
  — and offers to move it under the new name. It asks
  first, and it says which old backups the retention
  cleanup would then delete. On a hypervisor whose
  guests it registers, it asks once for the host and
  the guests together; a guest answered with "adopt"
  is moved on its next connection that may change
  it, after one more question. New config backups go
  to `/var/backups/hostwarden/`, or the directory an
  appliance's rules name.
- Renaming a script or unit also rewrites every
  reference to it on that host. Hostwarden keeps a
  rename map and backups to go back by, and checks
  on a later connection that each job ran under its
  new name.
- SSH sockets live in `~/.cache/hostwarden`.
- Scheduled runs (cron, systemd timers) need the new
  path and script names.
- Heinzel's version tags are not carried over.
  `--pin` only knows Hostwarden releases.
