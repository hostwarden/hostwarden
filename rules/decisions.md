# Decisions

A decision is a choice the user made about their estate — how a
host is built, reached, backed up or secured — with the reason for
it. It shapes what later sessions propose and how audits rate what
they find. It is neither of the two other kinds of memory:

- **A current fact** — `memory.md`, `network.md`, `guests.md`,
  `memory/network.md` — says what is there now. A decision says
  what is meant to be there, or not, and why.
- **An override** (`rules/overrides.md`) changes what Hostwarden
  does. A decision on its own changes no procedure; where one has
  to change, the decision gets an override as well (Decisions and
  overrides, below).

## What counts as one

Only the user's explicit word: "pve1 never gets a local firewall",
"do not propose SSO for the UniFi devices again", "that key stays,
I will not rotate it". Never inferred — not from a host's
configuration, not from a finding the user left unfixed, not from
a pattern across hosts, not from another tool's notes that do not
attribute the choice to the user. A missing firewall is a finding
until the user says it is meant.

Not a decision:

- what the host shows by itself: a fact for `memory.md`;
- a constraint that follows from a change: a `Flags:` line
  (`rules/changelog.md` → Standing lines);
- how a task is done on a host, step by step: an override;
- how Hostwarden itself is built: its developers decide that, in
  its repository;
- what was done and when: `changelog.log`.

## Where it goes

One file per scope, one `##` entry per decision:

| Scope | File |
| --- | --- |
| One host | `memory/servers/<hostname>/decisions.md` |
| A cluster or pool | `memory/clusters/<name>/decisions.md` |
| A group, or every host | `memory/decisions/<name>.md` |

A cluster's file applies to each host whose `memory.md` has its
`Cluster:` line (`rules/hypervisors.md` → Clusters and Pools).

A file under `memory/decisions/` names its group in its second
line, `Applies to:`, with exactly one of:

- `Applies to: all` — every host.
- `Applies to: <Field>: <value>` — every host whose `memory.md`
  has that field with a value that begins with the one given,
  ignoring case: `Appliance: Proxmox VE`, `Appliance: UniFi OS`,
  `Role: workstation`, `OS: Debian`. Any field
  `rules/server-memory.md` → Who writes which line lists.
- `Applies to: hosts <name>, <name>, …` — the hosts named, by
  their directory under `memory/servers/`: a site, or any set no
  field describes.

The `Applies to:` line is one line however long, the one line in
a memory file that is never wrapped: the search at pipeline step 6
reads that line alone, and a host named on a continuation line
would never be selected. One selector per file. A group that two
would describe is two files, since a line of each would leave open
whether a host must match one or both. Hostname patterns are not
selectors: a new host that happens to match a pattern has not been
decided about.

```markdown
# Decisions — Proxmox VE nodes
Applies to: Appliance: Proxmox VE

## Backups by pool
- Decided: user, 2026-08-19
- Why: guests are grouped into pools by how much a loss
  would cost; one job per pool keeps retention apart.
- Settles: a guest outside the pools' backup jobs is
  not a gap when its pool is `backup-none`
```

## The entry

```markdown
# Decisions — pve1.example.com

## No local firewall
- Decided: user, 2026-09-18
- Why: the host is reached only through the provider's
  firewall and the router guest; a ruleset on the bridges
  broke guest traffic.
- Settles: baseline → Firewall; the security audit's
  firewall check; proposals to enable one
- Revisit: 2027-03-01
```

- **The heading** names the decision and is its identifier, with
  the file's path below `memory/` after it:
  `No local firewall (servers/pve1.example.com/decisions.md)`.
- **`Decided:`** who and when. Who is `<operator>`
  (`rules/ssh-user.md` → Operator). A decision carried over from
  Heinzel names the operator who carries it over and keeps the
  date of Heinzel's record: `alice, 2026-09-18, from Heinzel`.
- **`Why:`** the user's reason, in their words, one or two lines.
  Never invent one; where the user gives none, write
  `Why: not given`.
- **`Settles:`** what it answers for: the finding, the check, the
  proposal. Name a shipped section where one fits
  (`baseline → Firewall`), so an audit can tell what is covered.
- **`Revisit:`** optional. A date on which the user wants to be
  asked again.
- **`Details:`** optional. The path below `memory/` of a file
  with the reasoning the entry has no room for (Details, below).

Wrap at 80 characters like every memory file. No status line: an
entry in the file is in force.

## Details

The entry stays short, whatever the decision weighed. Where the
user's reasoning runs past what `Why:` holds in two lines — the
options considered and why each lost, the numbers behind it, the
incident that led to it — it goes into a file of its own, and the
entry names it. The group example above would end in:

```markdown
- Details: decisions/proxmox-ve/backups-by-pool.md
```

The file lives beside the decision file it belongs to, in a
directory of the same name without `.md`, and is named after the
heading:

- `servers/<hostname>/decisions/<slug>.md` for a host's,
- `clusters/<name>/decisions/<slug>.md` for a cluster's,
- `decisions/<name>/<slug>.md` for a group's.

So what belongs to one host stays in that host's directory, and
moves or goes with it. The step-6 search over
`memory/decisions/*.md` does not reach into these directories. It
opens with the heading and the decision file it belongs to, holds
the user's reasoning in prose, and wraps at 80 characters. It is
never a second place for the decision itself: what is decided, for
which hosts, and what it settles stay in the entry.

It is read only when the decision is in play: the user asks about
it, asks for something it rules out, or revisits it, and before a
change that would touch what it settles. The entry is enough for
every other purpose, a rating in an audit included.

## When it is read

Step 6 of `rules/first-connection.md` finds the files that apply
to the host. This file is read once one does.

Two decisions for the same host that contradict each other: the
narrower scope wins — the host's own over its cluster's, a
cluster's over a group's, a group's over `Applies to: all`. Two
group files that contradict each other for one host cannot both be
meant: name both and ask before relying on either.

## Proposing

Never propose what a decision rules out, and never raise again what
it settles — in a report, a recommendation or the answer to a
one-line question alike. This holds over `rules/best-practices.md`
→ Always Suggest as well: the user has heard the suggestion and
answered it.

When the user asks for something a decision rules out, name it in
one line — heading, who, date, why — and ask whether it still
stands. A no retires or rewrites it (Revisiting and retiring) in
the same step as the change.

## Rating findings

A finding a decision settles is not an issue. It stays out of a
report's Issues section, and its check line is marked `DECIDED`
in the shape the report's format gives. It is not drift in a
fleet audit, and not missing from the baseline
(`rules/baseline.md` → Rendered Versions). A network finding it
settles is not written into the profile's `## Findings`.

A decision settles exactly what it names, on the hosts it applies
to. Everything past that is reported as usual, with the decision
named beside it, since it is what the user will want to weigh the
finding against:

- a finding that goes further — another port, a key other than
  the one accepted, a severity above the one it accepted;
- a host that no longer matches what was decided — the firewall
  the decision says is absent is running, the setting it keeps is
  changed: `WARN` in the audit that finds it, reported as
  `contradicts decision <heading>`.

While a decision's `Revisit:` date is past, its `DECIDED` line
ends in `— revisit due`, and the first session that reads it asks
the user once, after answering their request: keep it with a new
date or none, change it, or retire it. It stays in force until the
user retires it; a session that did not ask leaves the question to
the next one.

## Decisions and overrides

A decision on its own is enough to stop a proposal and to settle a
finding. It needs an override as well only when it changes what
Hostwarden does — a command, a route to the host, a schedule, a
setting it writes. The decision then holds the why, who, when and
scope; the override block holds the instruction and names the
decision in its first line. How such a block applies is
`rules/overrides.md` → An override for a decision. In
`memory/custom-rules/os/debian.md`:

    ## Add: Automatic Security Updates
    Decision: Reboots by hand only (decisions/databases.md)
    Leave Automatic-Reboot off; name a pending reboot instead.

**No decision reaches `AGENTS.md` → Critical Safety Rules**, which
no override reaches either (`rules/overrides.md` → Precedence). A
choice that would need one — port 22 closed, an sshd that already
runs reconfigured — is not recorded: say which part cannot be, and
record the rest.

## Writing one

Only on the user's explicit word. Offer to record one when the user
turns a proposal down with a reason, or states a standing choice;
write it on a yes. Ask as `rules/service-reload.md` → Prompt Shape
When Asking says, with the entry as it would be written and the
scopes to choose from:

    Record as a decision for pve1.example.com?
      No local firewall — because the router guest filters
      [1] Yes, for this host   [2] For all Proxmox VE nodes
      [3] No

For a group, name the hosts the selector matches now, so a
selector that matches none is seen before it is written. Name an
existing decision the new one repeats or contradicts.

A host's or cluster's decision is an entry of its own in the
`changelog.log` of each host it applies to, and a headline in the
journal of each of them this session is connected to
(`rules/changelog.md`); it is committed with them:

    [alice as root] Decided: pve1 keeps no local firewall
    — because the router guest filters

A group's has no host to ride on: commit its file on its own
(`rules/changelog.md` → The Workspace), with
`Decision: <heading>` as the message.

## Revisiting and retiring

Only on the user's word, never because a date passed.

- **Retire:** delete the entry, its `Details:` file, and every
  override block whose `Decision:` line names it, in one step. Log it as above:
  `Retired decision: <heading> — because <why>`. The workspace
  history keeps the old entry; the file is a picture of now.
- **Change:** rewrite the entry with the new date and reason, and
  its `Details:` file and override blocks in the same step.
- **Move to another scope:** write it at the new one and delete it
  at the old one, in one commit.

## Shared workspace

Decision files are shared, like the rest of a host's memory
(`rules/server-memory.md` → Personal versus shared). A decision
another person made binds this session as the user's own does;
`Decided:` names whose it was.
