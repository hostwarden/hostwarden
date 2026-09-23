---
name: hostwarden-adopt
argument-hint: "[path to the old Heinzel checkout]"
description: Take over an existing Heinzel installation — copy its
  memory, access lists, overrides and trusted host keys into this
  Hostwarden clone, rename what is found by name, build a per-host
  inventory of the scripts, configs, units and cron jobs Heinzel left
  on the servers, ask whether those should get Hostwarden's names on
  the hosts too, then onboard each host read-only as on its first
  Hostwarden connection — memory in Hostwarden's form, a
  hypervisor's guests inventoried and registered, the gaps to the
  server baseline listed. Can run host by host, with the shared state
  moved first. Use when the user says "übernimm mein altes Heinzel",
  "migrate my Heinzel setup", "mein Heinzel liegt in <pfad>, mach es
  dir zu eigen", "nimm erstmal nur server X mit", "take pve1 over
  from Heinzel", or points at a Heinzel directory and asks to take it
  over. Makes no change on a server beyond one read-only line in each
  host's journal. Needs an explicit request — a session that merely
  mentions Heinzel is not one.
---

# hostwarden-adopt

Takes hosts over from Heinzel so that each ends where a first
onboarding by Hostwarden would have left it. Two phases:

1. **Copy** (steps 1–8) — this clone and the old checkout, nothing
   else. No server is contacted.
2. **Onboard** (steps 9–12) — each adopted host in turn, through
   `rules/first-connection.md` as its first Hostwarden connection:
   read-only, one `read-only:` journal line per host. This is the
   default; the user does not have to ask for it.

**Only in an operations checkout** (`AGENTS.md` → Development or
Operations). Adopted access lists and server memory are operations
state, and a development checkout can neither keep them nor onboard
a host: there, say so, name the operations checkout — the main
checkout of a worktree, or one `bin/hostwarden-init` sets up — and
stop. `bin/hostwarden-adopt` refuses to copy there as well.

**Only on an explicit request** — the user naming their old checkout,
or `/hostwarden-adopt <path>` in Claude Code. A session that merely
mentions Heinzel is not a request, and neither is a question about
what adoption would do: answer it, don't start.

What makes this safe is not the trigger but the gates: the old
checkout is only read, anything this clone already holds is reported
before it would be overwritten, the copy contacts no server,
onboarding only reads, and the one write into the old tree (step 7)
needs its own yes.


## Why an inventory instead of a migration

Heinzel's own rules cover config backups, scratch directories and the
journal tag. They do not cover what agents improvised on the way —
the shapes are listed in `rules/heinzel-legacy.md` § "What to look
for", which is also what the first connection probes for, so the two
sides cannot drift apart. Those artifacts differ per host, and the
only local trace is what the session wrote into
`memory/servers/<host>/` and its changelog.

Memory says what was true when it was written. It is a lead, not a
finding (`rules/verify-before-reporting.md`) — this skill collects the
leads, the host confirms them.

## Workflow

1. **Locate the old checkout.** Take it from the argument, or ask for
   the path. Verify it is one: a `VERSION` file, a `memory/`
   directory, and `bin/heinzel-*` or `rules/`. If `memory/` is empty,
   say so and stop — there is nothing to adopt.

2. **Never write into the old tree.** The old checkout is the user's
   fallback. Read from it, copy out of it, change nothing in it. Say
   this once, so the user knows the original stays intact. The single
   exception is step 7, which the user approves explicitly.

3. **Ask once, before the copy.** Name the hosts the run takes and
   what follows the copy:

       Adopt 11 hosts from /Users/alice/heinzel?
         [1] Adopt and onboard each host now, read-only (Recommended)
         [2] Only copy — each host is onboarded on its first connection

   `[2]` defers onboarding, it does not skip it: a copied host has no
   `memory.md`, so whichever session reaches it first onboards it the
   same way.

4. **Copy the state.** `bin/hostwarden-adopt <path>` does it: shared
   state — access lists, service policy, overrides, network and
   housekeeping notes, and `memory/known_hosts` with its host-key
   records only, no comments — then every server's memory, then
   `bin/hostwarden-migrate` for the `heinzel-<skill>.md` →
   `hostwarden-<skill>.md` renames. It
   keeps this clone's version of anything that already holds user
   data and says so; `--list` shows the plan without copying. A
   `user.md` of this clone's own is the exception: it gains the lines
   it lacks — language, operator name and handle, per-server SSH
   users — and a
   key the two set differently is kept here and reported. Put each
   of those to the user in the report; change `user.md` only on
   their answer.

   **Host by host** if the user wants to move gradually:
   `--server <host>` (repeatable) takes single hosts,
   `--shared` takes only the shared state. The shared state comes
   along on the first run either way — the blacklist and the
   read-only list decide whether a host may be touched at all, so
   moving a host without them is not a partial migration but an
   unsafe one. Say which hosts are still in the old checkout after a
   partial run, and that the old one stays authoritative for them.

   **Files an override needs.** An adopted override can name a file
   under `memory/` — `memory/known_hosts` for `UserKnownHostsFile`,
   an SSH config, a key list. List the `memory/…` paths the files in
   `memory/custom-rules/` name, and report each one this clone does
   not have: the override fails, or falls back to something weaker,
   wherever it applies. A `known_hosts` the script left in the old
   checkout — it held a private key — is one of them; name the path,
   never its content (`rules/secrets.md`).

   **Host keys.** An adopted override that adds
   `UserKnownHostsFile=…/memory/known_hosts` to the SSH options, or
   says how that file is filled, repeats `rules/host-keys.md`. It keeps
   working as it is. Point it out in the report, and offer to cut it
   down to what still differs, such as forbidding first use, in
   `memory/custom-rules/host-keys.md`. Change it only on a yes.

   **What the copy leaves behind.** Each `not copied:` line names
   something in the old `memory/` that has no place here as it is —
   most often Claude's own auto-memory from Heinzel sessions (a
   directory of topic files with `name`, `description` and a `type`
   in their front matter, and a `MEMORY.md` index), besides notes and
   plans. Copying it whole would leave a second memory beside this
   one that no rule reads. Sort it instead, item by item, into the
   one target its kind has below; never into a file of your own
   making. Read the index and each file's front matter, and the body
   only where those do not say what it is. The `type` is a first
   hint, not the answer: `feedback` is mostly how the agent should
   work, `project` a standard, a fact or a plan, `reference` a
   pointer that goes with the host or network it names. An item that
   holds two kinds is split. Propose every item's target in one list, grouped
   by target, and ask once; the user moves items between groups or
   drops them in the answer. A later run lists the same entries
   again, since the old checkout never changes: an item whose content
   its target already holds is not proposed again.

   - **A standard every server should meet** — packages, updates,
     time zone, mail route, what a new host always gets:
     `memory/custom-rules/baseline.md`, which `hostwarden-baseline`
     measures against (`rules/baseline.md`).
   - **How the agent should work** — a correction, a preference:
     an override (`rules/overrides.md`), in the file of the rule or
     skill it changes, `memory/custom-rules/all.md` where it changes
     none.
   - **A decision the user made**, with its reason — "no SNAT
     anywhere", "do not propose SSO for the UniFi devices again": an
     entry in the place and form `rules/decisions.md` gives, carried
     over from Heinzel, its longer reasoning in the entry's
     `Details:` file. A host still in the old checkout gets nothing
     yet: its decisions are sorted again when it is adopted.
   - **A fact about one host** or an open plan for it: under
     `## Facts` in that host's `heinzel-inventory.md`
     (`references/inventory.md`), which its first connection checks
     and carries into `memory.md`, a plan as `- Planned: …`, and then
     removes; it is no lead. A host that already has a `memory.md`
     takes the item there directly. A host still in the old checkout
     gets nothing yet: its items are sorted again when it is adopted.
   - **A fact about the network or several hosts** — sites, VPNs,
     break-glass access, a firewall between sites, which host backs
     up which: `memory/network.md` (`rules/server-memory.md` →
     Cross-server facts).
   - **About the operator** — language, full name as
     `Operator name:`, how they want to be written to:
     `memory/user.md`, under `# Preferences`, where
     `rules/session-start.md` reads it; the rest is dropped. The
     handle, `Operator:`, is the operator's own pick, never derived
     from a name (`rules/ssh-user.md` → Operator).
   - **A lesson that belongs in the shipped rules**: a proposal for
     Hostwarden itself, named in the report for a pull request from a
     development checkout. Nothing is written here.
   - **Anything else** — history, a finished or estate-wide plan,
     anything about Heinzel itself, and whatever is no memory at all,
     such as brand assets: it stays in the old checkout and the
     report names it.

   Never read a file that looks like it holds credentials; name it
   (`rules/secrets.md`). What is written joins the workspace commit
   of step 6.

5. **Leave the facts in memory alone.** Each host's `memory.md`
   arrives as `heinzel-memory.md`, byte for byte, and stays that way
   until the host's first connection splits it into `memory.md`, the
   host's `rules.md` and `memory/network.md`, from what that
   connection finds, and deletes it (`rules/heinzel-adoption.md` →
   Heinzel's memory). A memory line
   naming `/var/backups/heinzel/` or a `heinzel-backup.sh` is a true
   statement about that host — the path is still there, and it
   carries over as written. Only the greeting line in `user.md`
   (`Greeting: … Heinzel`) is about this tool rather than about a
   host: point it out and ask whether to change it.

6. **Build the inventory.** This is the part no script can do. It
   covers every host the run named: listed as copied,
   `already adopted: memory/servers/<host>`, or
   `kept memory/servers/<host> — …`. A repeat or interrupted run
   copies nothing, and a kept host is one whose leads sit in the old
   checkout's records — both would otherwise end up with no leads at
   all. A selection that is a DNS alias means
   the canonical host it points at (`rules/dns-aliases.md`): take
   that one, drop the alias. Never every host under
   `memory/servers/`, or a `--shared` run builds inventories for
   hosts nothing was adopted for. Skip a host whose inventory already
   holds leads, or whose `heinzel legacy:` line settles the question
   (`rules/heinzel-adoption.md` → Record): its leads were collected or
   checked. `## Facts` from step 4 alone is no reason to skip, and
   neither is a deferral: the check that deferred it knew only the
   fixed paths, not the leads in the records adopted now.

   For each host in that set, read `heinzel-memory.md` and
   `changelog.log` and collect every path, unit, cron job or script
   a Heinzel session created or configured — the shapes are listed
   in `rules/heinzel-legacy.md` § "What to look for",
   `references/inventory.md` has the file format and what does not
   count. Write it to `memory/servers/<host>/heinzel-inventory.md`.
   Its existence is what makes the first connection check the leads;
   no status line is needed for that. Note in passing which hosts'
   memory names a hypervisor — Proxmox VE, libvirt, Incus, LXD, LXC,
   bhyve or jails — for the order in step 9.

   A connection reads only the last seven days of a host's
   `changelog.log` (`rules/changelog.md` → Reading it), so a copied
   host's older `Flags:` and `Rollback:` lines would go unread. In
   the same pass, add each one that no later entry lifts or undoes
   to that host's `memory.md` as a standing line, as
   `rules/changelog.md` → Standing lines says. A host with no
   `memory.md` yet keeps them for its onboarding, which writes them
   into the new file (`rules/heinzel-adoption.md` → Heinzel's
   memory).

   Read the **old checkout's** `memory.md` and `changelog.log`
   whenever this clone kept its own — the leads live in the records
   that were not copied.

   Then commit what the copy and the inventory wrote, as
   `rules/parallel-sessions.md` → The workspace says, with the
   message `Adopted <n> hosts from Heinzel (<path>)`. Name the
   copied files that are not personal (`rules/server-memory.md` →
   Personal versus shared) and each copied host's directory.

7. **Offer the coexistence rules.** Ask whether Heinzel stays in use
   during the transition. If it does, offer to copy the three files
   from `contrib/heinzel-coexistence/` into that checkout's
   `memory/custom-rules/`, the way its README § Install describes —
   never replacing a file, and reporting what has to be merged by
   hand. Without them Heinzel reads only its own journal tag, so
   Hostwarden's work stays invisible to it and its memory drifts.
   This writes into the old tree, so it needs an explicit yes. On a
   no, say the directory is there when they change their mind.

   The answer to "does Heinzel stay in use" is also the one every
   host's Heinzel check needs while onboarding
   (`rules/heinzel-adoption.md` → Not while Heinzel is still in
   use): ask it once, here, never again per host.

8. **Ask how the names on the hosts should end up.** Scripts, units,
   cron files and config directories that Heinzel sessions created
   carry names like `heinzel-backup.sh` or `/etc/heinzel/`. Ask once
   which way the user leans:

   - **Rename** — on each host, give them Hostwarden's name and
     rewrite every reference to them. A missed reference would break
     a job on its next run, which is why every reference is searched
     for first and the next connection checks the run.
   - **Keep** — the names stay. Heinzel's own backup and scratch
     directories are still offered for the move.
   - **Per host** — decide on each host's first connection.

   Record `Heinzel names on hosts: rename` or `keep` in
   `memory/user.md`; per host records nothing. What the line does on
   a host is `rules/heinzel-adoption.md` → Report, then ask. A line
   already there is shown, and replaced only when the user changes
   the answer.

9. **Onboard, host by host.** After `[1]` in step 3. The hosts are
   those of the run that have no `memory.md` after the copy — a kept
   host is already this clone's own, and an alias is its canonical
   host. Take the hypervisors
   step 6 noted first: a guest they register is onboarded by that
   and has a `memory.md` when its own turn comes, which then skips
   it.

   Announce each host in one line before its first command:

       Onboarding 3/11: pve1.example.com — first connection, read-only

   Then run `rules/first-connection.md` for it in full, as its first
   connection: the full probe of `rules/first-detection.md`, never the
   short form of a known host, and `memory.md` and the address check
   as `rules/heinzel-adoption.md` → Heinzel's memory says. A
   blacklisted host is not reached; its report line says so. A
   hypervisor adds step 10, and every host ends with step 11.

   Nothing on the host changes. A question whose answers only get
   recorded — stopped guests, Heinzel's decisions and the overrides
   offered with them, Heinzel's finds answered "leave" or "later" —
   is asked once that host's steps have run, in the order its rules
   give, so the answers are in its memory before the next host
   starts. Moving
   or renaming Heinzel's state is a change: an answer that adopts is
   recorded as `heinzel legacy: deferred <date> (answered at
   onboarding: <answer>)` and asked again after the report. Then
   write its `read-only:` journal line and changelog entry and commit
   its files
   (`rules/changelog.md`); the journal line names the adoption:
   `read-only: onboarded after adoption from Heinzel`.

   A host that cannot be reached gets what
   `rules/ssh-unreachable.md` allows and no more, keeps its
   `heinzel-memory.md` without a `memory.md`, and the run moves on to
   the next one: its first connection onboards it later.

10. **A hypervisor gets the hypervisor onboarding.** Where OS
   detection finds one (`rules/first-detection.md` → Hypervisors, and
   the appliance file, `rules/appliance/proxmox-ve.md` for Proxmox
   VE), its first connection is a hypervisor's first connection:

   - **The full inventory** into `guests.md`
     (`rules/hypervisors.md` → Inventory), or on a member of a
     cluster or pool into `memory/clusters/<name>/`, found or named
     as `rules/hypervisors.md` → Clusters and Pools says — a second
     adopted member finds the one the first created.
   - **Guests still in the old checkout.** Match the inventory
     against the old checkout's `memory/servers/`, as
     `rules/hypervisors.md` → Registering Guests says. Those with a
     directory there and none here are adopted with their host, in
     one question:

         7 guests of pve1.example.com have Heinzel memory in
         /Users/alice/heinzel: web1.example.com, db1.example.com, …
           [1] Adopt them with pve1 (Recommended)
           [2] Leave them in the Heinzel checkout

     `[1]` runs `bin/hostwarden-adopt <path>` once with a
     `--server` for each and builds their inventory as above;
     registration then onboards them through the host. `[2]` leaves
     them unregistered, as Registering Guests says.
   - **Registering Guests** (`rules/hypervisors.md`), with its
     report. An adopted guest's `memory.md` is written there as
     `rules/heinzel-adoption.md` → Heinzel's memory says. An adopted
     guest the manager cannot enter — a VM without an agent — keeps
     its `heinzel-memory.md` alone and is onboarded on its first SSH
     connection.
   - **Stopped Guests** (`rules/hypervisors.md`), asked once.
   - **On Proxmox VE, the baseline template.** An adopted node has
     no `Baseline template:` line (`rules/appliance/proxmox-ve.md` →
     Guests): Heinzel built none. The report names that on the
     node's line, since a container created there would start without
     the baseline until `hostwarden-new-guest` builds one.

11. **Where the host stands.** For each host onboarded over SSH, run
    `hostwarden-baseline` steps 1 and 2 — its overrides and the
    measurement, read-only — and not its question. Heinzel's
    decisions for the host are asked before this measurement, ahead
    of step 9's other questions, so a section one settles is not
    listed as missing. What this
    connection's probes already read counts there like a housekeeping
    run's findings and is not probed again. A guest registered through
    its host is measured on its first SSH connection or by
    housekeeping.

12. **Report.** One block for the run, then the questions.

    After onboarding:

    ```
    Adopted 7 hosts from /Users/alice/heinzel, onboarded 6, read-only
    pve1.example.com — Proxmox VE 9.0.3, 11 guests: 9 registered,
      4 of them adopted with it; 3 leads: 2 confirmed, 1 gone
      baseline: missing automatic security updates, backup;
      no baseline template for containers
    web1.example.com — Debian 13; 4 leads, all confirmed
      baseline: complete
    db1.example.com — not onboarded: SSH timeout; its first
      connection onboards it
    Heinzel: still in use — its state is reported, not moved
    Written: memory.md, network.md and a read-only journal line for
      each onboarded host, guests.md for pve1, the workspace committed
    Nothing on the servers was changed.
    ```

    Copy only:

    ```
    Adopted 7 hosts from /Users/alice/heinzel, copy only
    web1.example.com — Heinzel memory, 3 changelog entries, 4 leads
    db1.example.com  — Heinzel memory, 0 leads
    ...
    Names on the hosts: rename, proposed on each first connection.
    Nothing on the servers was touched. The first connection to
    each host onboards it: memory in Hostwarden's form, its leads
    checked, before anything is moved.
    ```

    Add a line for each file an override needs and this clone lacks,
    each `user.md` key the two checkouts set differently, what was
    left in the old checkout and each proposal for Hostwarden itself
    (step 4), and for each host still in the old checkout after a
    partial run. Say which of the two states the installation is in:
    Hostwarden alone, or both tools in parallel. In the parallel case
    the Heinzel check reports what Heinzel left but does not move it
    (`rules/heinzel-adoption.md`).

    First, per host whose answer to Heinzel's finds adopted them,
    that question once more, now as a change: on a yes, the move and
    any rename run as `rules/heinzel-adoption.md` says, with the
    host's own journal line, and its `heinzel legacy:` line is
    rewritten.

    Then, where a host has gaps, ask which to take on first: one option
    per host with gaps, one per node without a baseline template,
    and "not now". A host starts `hostwarden-baseline` for it, whose
    own question decides what is applied; a node starts building its
    template (`hostwarden-new-guest`).

## Who owns what

Taking over Heinzel is one feature split across mechanisms, because
its halves are triggered by different things:

- **This skill** — the old checkout, and the order in which the
  adopted hosts are onboarded. The user asks for it by name, and
  again for each further piece: a migration moved host by host is
  several requests, one per run. It copies memory, access lists,
  overrides and host keys into this clone, writes down what Heinzel
  appears to have left on each host, and walks each host through its
  first connection.
- **`rules/first-connection.md`** and the files it names — what a
  first connection does on any host, adopted or not. Onboarding here
  adds no step of its own; it runs them early, while the user is
  there, rather than whenever the host is next needed.
- **`rules/heinzel-legacy.md`** — detection on the host. Step 8 of
  the first-connection pipeline, so it fires without anyone asking:
  on the first connection to a machine, while anything is still
  unresolved, and whenever the activity check turns up `heinzel`
  entries — which is what catches Heinzel touching a host again
  after the question was settled. It detects; it never moves.
- **`rules/heinzel-adoption.md`** — what to do about a detection,
  and how Heinzel's memory becomes a Hostwarden `memory.md`. Also a
  reflex. Every path that would *move* something ends in a question,
  because moving files on a live server is a change. The path that
  moves nothing does not ask: while Heinzel is still in use,
  adoption is premature, and that one reports and records a deferral
  instead.
- **`rules/hypervisors.md`** → Registering Guests — which guests are
  registered, and why one still in the Heinzel checkout is not.

Nothing is stated twice: this file describes the checkout and the
run, the rules describe the hosts, and each names the other rather
than summarizing it.

## What this skill does not do

- **No server contact in the copy phase.** Onboarding reads, and
  writes one `read-only:` line into each host's journal.
- **Nothing in a development checkout.** Not the copy either.
- **No change on a host.** Moving or renaming Heinzel's state,
  closing a baseline gap, starting a stopped guest — each is its own
  question under its own rule, after the report.
- **No renaming on hosts from here.** Step 8 only records which way
  the user leans. The rename runs on each host after its own
  question — `rules/heinzel-adoption.md` § "Rename to Hostwarden's
  name".
- **No scheduled runs.** Heinzel's cron lines and timers on the
  workstation are reported under `rules/heinzel-adoption.md` § "On
  the workstation (local mode)", and change only with explicit
  approval.
- **No secrets.** If the old tree holds key material or a file with
  credentials, report the path and leave it (`rules/secrets.md`).
