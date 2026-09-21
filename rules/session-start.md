# Session Start Preflight

What to load before the session does anything else, and what to
say about it. This is preference and customization state, not an
access gate: the blacklist and the read-only list are checked
again as steps 1 and 2 of `rules/first-connection.md`, on every
connection, whether or not this ran.

It runs in an operations checkout only. A development checkout —
`AGENTS.md` → Development or Operations — loads none of this and
asks nothing.

## What to load

If the workspace has a remote, bring it up to date first:
`bin/hostwarden-sync pull`. Claude Code's session-start hook
has already run it. When it reports that the workspace could
not be updated, say so before any server work: its server
memory may be older than another machine's. When it names
uncommitted changes: `rules/parallel-sessions.md` → Changes a
session left behind.

Quietly load `memory/user.md`, `memory/blacklist.md`,
`memory/readonly.md`, `memory/service-policy.md`, and
`memory/custom-rules/all.md` (if present), and glance at
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

The greeting comes before any of this, and `AGENTS.md` → Session
Start has the words: it has to be said before the first read, and
this file is itself a read. Do not repeat it here.

Missing files are normal on a fresh install; "No such file" is not
an error.

Once the reads are in, name the customizations that are in force,
in one line — *"Custom rules: all, backups, os/debian."* — or say
nothing when there are none. An override path that names nothing
shipped is not a customization in force: `rules/overrides.md` says
what to do with it, and it is not "carry on".

## What not to ask

**Do not improvise setup questions.** If `memory/user.md` is
missing *and* the session is about to reach a machine, follow the
three-option interview in `rules/ssh-user.md` exactly, one question
at a time.

A session in a development checkout reaches no machine and needs
no SSH user, so it never gets here. Nor does an operations session
that only reads or discusses the instruction set: no machine, no
interview.
