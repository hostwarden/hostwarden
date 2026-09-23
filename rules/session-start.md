# Session Start Preflight

What to load before the session does anything else, and what to
say about it. This is preference and override state, not an
access gate: the blacklist and the read-only list are checked
again as steps 1 and 2 of `rules/first-connection.md`, on every
connection, whether or not this ran.

It runs in an operations checkout only. A development checkout —
`AGENTS.md` → Development or Operations — loads none of this and
asks nothing.

## What to load

Run `bin/hostwarden-sync pull` first. It brings a workspace
with a remote up to date, and writes `memory/ssh_config`
(`AGENTS.md` → SSH Options) either way. Claude Code's
session-start hook has already run it. When it names a failing
line of `memory/ssh_hosts`: `rules/ssh-config.md`. When it
reports that the workspace could
not be updated, say so before any server work: its server
memory may be older than another machine's. When it names
uncommitted changes: `rules/parallel-sessions.md` → Changes a
session left behind.

Quietly load `memory/user.md`, `memory/blacklist.md`,
`memory/readonly.md`, `memory/service-policy.md`, and
`memory/custom-rules/all.md` (if present), `memory/operators.md`
where the workspace has a remote, and glance at
`memory/servers/` and `memory/custom-rules/` to see what's there.

**How:** read each file on its own, with whatever your harness
offers for reading a file, and list directories with a plain `ls`
— all in one message so they run together. Do **not** use a shell
`for`-loop with `cat`: it asks for a shell permission that reading
files does not need, and looks alarming to new users.

`ls -R memory/custom-rules/` for that one: an override can sit a
level down (`os/debian.md`, a skill's reference), and a top-level
listing shows the directory rather than the file in it — which is
the thing that has to be named below.

## Workstation tools

Where SessionStart hooks run, `bin/hostwarden-doctor --quiet` has
already run and said what is missing, or said nothing because
nothing is. Where they do not, run it yourself, once, in the same
message as the reads above.

Take its output as the limits of this session: a feature it lists
as not available is not attempted — say so when the user asks for
it, and give the install command it printed. Never install a
missing tool on the workstation yourself; it is the user's machine,
not a managed host.

## What to say

Missing files are normal on a fresh install; "No such file" is not
an error.

Once the reads are in, name the overrides that are in force,
in one line — *"Overrides: all, backups, os/debian."* — or say
nothing when there are none. An override path that names nothing
shipped is not an override in force: `rules/overrides.md` says
what to do with it, and it is not "carry on".

## The operator handle

Where `rules/ssh-user.md` → Operator requires the `Operator:` line
and `memory/user.md` has none, ask for it once the reads are in,
before anything else, in one question of its own and in that
file's interview format:
*"Which short handle should Hostwarden record as yours? It goes
into the journal of every server you change and into the shared
workspace, so initials or a code will do."* Offer the current OS
user where it fits the handle's format, and `Other…`.

`memory/operators.md` is the team's shared list of handles in use,
one `- <handle>` line each. Where the answer is on it, ask whether
it is theirs; if not, it is taken, and ask again. A new handle is
reserved before it is used: add its line, commit that file alone
(`bin/hostwarden-sync commit "Operator: <handle>"
memory/operators.md`) and push it (`rules/changelog.md` → The
Workspace). A push the remote turns down means someone else pushed
first: pull, check the list again, and push again.

Only once a push has carried the reservation to the remote, write
`Operator: <handle>` under `# Preferences` in `memory/user.md`,
creating the file or the heading where it lacks them. Where the
user declines the push or it cannot get through, write nothing
there and say so: the session records `user` until then, and the
next one asks again. A handle the list already holds as theirs,
their own unpushed reservation included, still needs the list on
the remote to carry it before it is written. An `Operator:` line
the user wrote themselves that the list lacks is reserved the same
way, without a question.

## What not to ask

**Do not improvise setup questions.** If `memory/user.md` has no
`Default:` line *and* the session is about to reach a machine,
follow the three-option interview in `rules/ssh-user.md` exactly,
one question at a time.

An operations session that only reads or discusses the instruction
set reaches no machine, so it gets no interview.
