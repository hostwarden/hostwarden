# Rebuilding Heinzel's Copies

Heinzel kept copies of what its sessions wrote onto hosts wherever
a session found room — a `scripts/` or `configs/` directory in a
host's memory, loose files beside its `memory.md`, a `memory/tools/`
or `memory/scripts/` at the top — often under the first host of a
fleet for all of them. Every adoption rebuilds them onto the layout
of `rules/deployed-files.md`, as part of step 6, before its commit.
It is not a question to the user: the report says where each file
went. Nothing here contacts a server; which copies are really
deployed is the host's to say, on its first connection
(`rules/heinzel-adoption.md` → Heinzel's copies).

## What to look at

- In each host directory of step 6's set, every entry other than
  Hostwarden's own: `memory.md`, `heinzel-memory.md`,
  `changelog.log`, `todo.md`, `rules.md`, `heinzel-inventory.md`,
  `guests.md`, `storage.md`, `deployed.md`, `files/`, `src/`,
  `notes/`. A kept host's are read in the old checkout, like its
  leads.
- The `not copied:` entries of step 4 that hold such files. They
  are copied out of the old checkout by this pass, not proposed
  in step 4's list.

A host whose directory holds nothing beyond those names was
rebuilt before or never had any; there is nothing to do.

## Where each kind goes

Decide from the records — `heinzel-memory.md`, `changelog.log` and
the file's own header comments — and from the file itself. Never
read one that looks like it holds a credential (last kind below).

- **A copy of a file a session wrote onto a host as a whole** — a
  script, a unit or timer, a cron file, a config drop-in, a
  rendered template — becomes its master
  (`rules/deployed-files.md` → What gets a master): under
  `files/` at the path it has on the host, which the records, a
  header comment or a directory tree mirroring host paths give.
  The name is the host's, so a Heinzel name stays
  (`rules/deployed-files.md` → Naming on the host).
  - Deployed to one host, or the records do not say where: the
    host directory it came in, `servers/<host>/files/<path>`.
  - Deployed to several hosts that form no cluster:
    `memory/fleet/<name>/files/<path>`, `<name>` its file name
    without the extension, with a `README.md` saying what it is
    and how it was deployed, in the records' words. A host whose
    copy differs keeps its variant under its own `files/`, named
    in the `README.md`.
  - In a cluster's shared file system (`/etc/pve/` on Proxmox VE):
    `memory/clusters/<name>/files/<path>` once that directory
    exists; before the onboarding creates it, the host's
    `files/`, which the onboarding moves
    (`rules/heinzel-adoption.md` → Heinzel's copies).

  A copy of a host's own file that a session edited in place —
  `nginx.conf` before or after — is no master; it is evidence.
- **What renders a master** — a template and its variables, an
  upstream file and patches, a payload for an API:
  `src/<name>/` beside the `files/` it feeds, with a `README.md`
  saying what it produces and how, from the records, or that they
  do not say.
- **A script run from the workstation against hosts** — it calls
  `ssh` or `scp`, or the records say it was run from the checkout:
  `memory/tools/<name>`, its name kept. Where it does not open
  with the comment `rules/deployed-files.md` → Workstation tools
  asks for, add one from the records. A path into the old
  checkout or `~/heinzel-keys/` in it is reported, never
  rewritten.
- **An open plan that spans sessions** — a document with phases
  or decisions, not the one-line note step 4 sorts:
  `memory/plans/<slug>.md`, in the form of
  `rules/server-memory.md` → Plans that outlive a session, and a
  `- Plan:` line for each host it names — in
  `memory.md`, or under `## Facts` in the inventory
  (`references/inventory.md`) for a host not onboarded yet. A
  finished plan is history.
- **Evidence** — an export, a snapshot for comparison, probe
  output kept on purpose, a copy of an edited host file:
  `servers/<host>/notes/`, its name ending in the date of the
  changelog entry that made it, else the old file's modification
  date, and that entry named in the host's changelog line for the
  adoption.
- **History and anything else** — an incident write-up, a
  finished plan, notes about Heinzel itself: removed from this
  workspace before the commit; the old checkout keeps it, and the
  report names it.
- **A credential**, by the file's name or a `grep -l` with the
  anchored patterns of `rules/secrets.md`: never read, never a
  master or a note. Removed from this workspace before the commit
  and named in the report; the old checkout keeps it. The host
  file it copies is the host's own until its master is rebuilt
  under `rules/deployed-files.md` → Secrets, on request.

## Moving

`mkdir -p` and `mv -n` inside the workspace, `cp` out of the old
checkout; never overwrite. Before placing a master, compare its
hash with the masters the workspace already holds: an equal one is
the same artifact, and the host gets an entry for that master
instead of a second copy — which is how a host adopted in a later
run joins a fleet artifact placed earlier. A master already at the
target stays, with its entry, and Heinzel's copy of it is history.
Of two Heinzel copies of one host path that differ, the one the
latest changelog entry deployed goes to the target, the other is
history; where the records do not tell, either one — the host's
check replaces it with the host's file where that differs.

An emptied Heinzel directory is removed with `rmdir`, which fails
on anything left; what is left is named in the report.

## Recording

Each master placed gets an entry in the `deployed.md` of the
directory it went to — the host's, or for a fleet master each host
the records deploy it to, among the hosts this run takes:

```markdown
- /usr/local/bin/heinzel-backup.sh
  servers/web1.example.com, adopted 2026-09-20
  sha256 unverified
```

`unverified`, because only the host can say what is deployed, and
the adoption does not contact it. Mode, owner and a hash are never
written from the records. The host's first connection settles the
entry.

## Report

One line in the step 12 block per host, and one for what left the
workspace:

```
web1.example.com — 4 masters placed, 1 tool, 2 notes; unverified
  until its first connection
left in the old checkout: 1 file with credentials
  (servers/web1.example.com/configs/app.env), 3 of history
```
