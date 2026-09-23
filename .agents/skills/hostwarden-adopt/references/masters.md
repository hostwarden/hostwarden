# Rebuilding Heinzel's Copies

Heinzel kept copies of what its sessions wrote onto hosts wherever
a session found room — a `scripts/` or `configs/` directory in a
host's memory, loose files beside its `memory.md`, a `memory/tools/`
or `memory/scripts/` at the top — often under the first host of a
fleet for all of them. Every adoption rebuilds them onto the layout
of `rules/deployed-files.md`, as part of step 6, before its commit.
It is not a question to the user: the report says where each file
went. Nothing here contacts a server; which copies are really
deployed is the host's to say (`rules/heinzel-adoption.md` →
Heinzel's copies).

## What to look at

- In each host directory of step 6's set, every entry that
  `rules/server-memory.md` does not name for a host directory. A
  kept host's are read in the old checkout, like its leads.
- The `not copied:` entries of step 4 that hold such files, copied
  out of the old checkout by this pass.

## Where each kind goes

Decide from the records step 6 has just read, the file's own header
comments and the file itself.

- **A copy of a file a session wrote onto a host as a whole**
  (`rules/deployed-files.md` → What gets a master) becomes its
  master under `files/`, at the path it has on the host, which the
  records, a header comment or a directory tree mirroring host
  paths give. The name is the host's, a Heinzel name included
  (`rules/deployed-files.md` → Naming on the host).
  - Deployed to several hosts that form no cluster:
    `memory/fleet/<name>/`, `<name>` its file name without the
    extension, with its `README.md` written from the records,
    which says where they deploy it: that is history, for the runs
    that adopt those hosts later (Recording, below), while
    membership stays in each host's `deployed.md`.
  - Otherwise, a file in a cluster's shared file system included:
    the host directory it came in, `servers/<host>/files/`.
    `rules/hypervisors.md` → Clusters and Pools moves a cluster's
    file once the onboarding finds the cluster.

  A copy of a host's own file edited in place is evidence.

  A host path from the records or a header is data from a server,
  and it becomes part of a workspace path, a `deployed.md` line
  and a probe. Place a copy there only when the path is absolute
  and every component is a plain name: no empty component, no `.`
  or `..`, and no control character or newline. Any other path
  is reported, and the copy is evidence. A name this pass puts
  into a workspace path — `<name>`, `<slug>`, a tool's file name —
  is one such component too, and one it makes up is reduced to
  lowercase letters, digits, `_` and `-`.

- **What renders a master**: `src/<name>/`, with its `README.md`
  from the records, or saying that they do not tell.
- **A script run from the workstation against hosts** — it calls
  `ssh` or `scp`, or the records say it was run from the checkout:
  `memory/tools/<name>`, its name kept, with the opening comment
  `rules/deployed-files.md` → Workstation tools asks for added
  from the records where it lacks one. A path into the old
  checkout or `~/heinzel-keys/` in it is reported, never
  rewritten.
- **An open plan that spans sessions** — a document with phases
  or decisions, not the one-line note step 4 sorts:
  `memory/plans/<slug>.md` (`rules/server-memory.md` → Plans that
  outlive a session). A host not onboarded yet carries its
  `- Plan:` line under `## Facts` in its inventory
  (`references/inventory.md`).
- **Evidence** — an export, a snapshot, probe output kept on
  purpose: the host's `notes/` (`rules/server-memory.md` → Notes
  and evidence), dated by the changelog entry that made it, else
  by the old file's modification date.
- **History, credentials and anything else** — an incident
  write-up, a finished plan, notes about Heinzel itself, and any
  file `rules/secrets.md` counts as a secret, found by its name or
  a `grep -l` and never read: removed from this workspace before
  the commit and named in the report; the old checkout keeps it,
  untouched. A credential file also gets its pointer line (Moving,
  below), so it is never lost from sight.

## Moving

`mkdir -p` and `mv -n` inside the workspace, `cp` out of the old
checkout; never overwrite. Hash the workspace's masters once per
run, and look each copy up there before placing it: one at the same
host path with the same hash is the same artifact, and the host gets
an entry for that master instead of a second copy. Equal bytes at
another host path are a different file.

A master already at the target stays, with its entry. Of two
Heinzel copies of one host path that differ, the one the latest
changelog entry deployed goes to the target, else either. Every
copy that does not become the master goes to the host's `notes/`
as a superseded copy (`rules/heinzel-adoption.md` → Heinzel's
copies), never dropped.

A note that nothing points to is deleted (`rules/server-memory.md`
→ Notes and evidence), so each note this pass writes gets a line
where the host's first connection finds it: under `## Facts` in
its inventory, or in its `memory.md` where it has one —
`- Note: notes/<file> (<what it is>, from Heinzel)`. A credential
file gets the same line with its path in the old checkout instead:
`- Note: not copied: <old checkout>/memory/<path> (holds a
credential)`.

An emptied Heinzel directory is removed with `rmdir`, which fails
on anything left; what is left is named in the report.

## Recording

Each master placed gets an entry in the `deployed.md` of the
directory it went to — the host's, or for a fleet master each host
the records deploy it to, among the hosts this run takes — in the
unverified form (`rules/deployed-files.md` → Unverified entries).
Mode, owner and a hash are never written from the records.

A host of this run also gets an entry for each fleet master already
in the workspace whose `README.md` names it, or whose host path its
own records say it carries. That is how a host adopted in a later
run joins a fleet artifact whose copy came in with another host.

## Report

One line in the step 10 block per host, and one for what left the
workspace:

```
web1.example.com — 4 masters placed, 1 tool, 2 notes; unverified
  until its first connection
left in the old checkout: 1 file with credentials
  (servers/web1.example.com/configs/app.env), 3 of history
```
