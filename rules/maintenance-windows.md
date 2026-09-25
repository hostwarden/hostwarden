# Maintenance Windows

A blast radius known in advance answers the planning questions too:
what a reboot would hit, whom to tell, and how much lead time that
takes. `rules/coordination.md` computes the radius and answers
what-if on the spot; this file plans ahead from the same answer and
carries the plan for a session that runs it weeks later, with none
of the planning conversation behind it.

## Downtime notice

`- Downtime notice: 7 days, shop customers (status page)` in
`memory.md` names who must hear about a window on this host and by
when: an audience, a lead time and a channel, never a personal
address — the admin's own notice below (→ Telling IT) is a
different thing. A host may carry several. Written only from the
user's answer, the way `Depends on:` entries for `DB`, `LDAP`,
`auth` and `other` are (`rules/coordination.md` → Dependencies) —
never inferred from a service the host runs. It stays until the
user drops it or the host leaves memory.

## The window plan

`memory/plans/<slug>.md`
(`rules/server-memory.md` → Plans that outlive a session), with
these lines above the steps:

    # pve1 kernel update
    - Hosts: pve1.example.com
    - Window: 2026-10-05 22:00–23:30 Europe/Berlin
    - Kind: reboot
    - Affected: web1.example.com, db1.example.com (radius of 2026-09-24)
    - Notify by: 2026-09-28 (shop customers, 7 days)
    - Notice: IT email sent 2026-09-27 by jpa
    - Status: planned
    - Updated: 2026-09-24

- **`Hosts:`** the origins — what `bin/hostwarden-impact radius`
  took as its argument. Several at once cover a rolling cluster
  plan.
- **`Window:`** the date, the time span and the timezone the user
  gave. Two windows in the same plan — a rolling cluster — get one
  `Window:` line each, in order.
- **`Kind:`** what `rules/coordination.md` → Blast radius took:
  `reboot`, `network`, `firewall` or `restart:<unit>`.
- **`Affected:`** the radius's hosts, comma-separated, with the date
  the radius was read. Recomputed when the plan is run (→ Running a
  window); this line is the snapshot from planning.
- **`Notify by:`** the latest date a `Downtime notice:` inside the
  radius needs the news out, with which notice drove it. Absent
  where the radius carries none.
- **`Notice:`** absent until the notice went out; then its form,
  chat text or email, the date, and who sent it.
- **`Status:`** `planned`, or `run` once the window has been run
  (→ Running a window), before the plan and its lines are deleted.

Below `Updated:` come the steps, each with its expected result and
the backups it needs, in the shape `rules/multi-host.md` → Changes
on several hosts gives a rollout's steps, then the checks to run
before the window, the rollback, and the checks after it. Write it
for a reader with none of the planning conversation: no "as
discussed", every command, expected result and approval spelled
out.

**Building the plan.** Run `bin/hostwarden-impact radius --report`
for the hosts and kind (`rules/coordination.md` → What-if) and turn
its grouped output into `Affected:`. The report's own fields are
role and service lines only — read each affected host's `memory.md`
directly for its `Downtime notice:` lines, for `Notify by:`. Ask the
user for `Window:`, confirm the canary and the steps the way a
multi-host rollout does (`rules/multi-host.md` → Changes on several
hosts, step 2), and write the plan. Nothing runs yet — planning
only writes memory.

**Memory lines.** The origin hosts get the plan's `Plan:` line
(`rules/server-memory.md` → Plans that outlive a session). Each
affected host gets
`- Downtime: 2026-10-05 22:00–23:30 (plan pve1-kernel)`, one per
window that reaches it. Both kinds of line are deleted together
with the plan, once it is done or dropped.

**A new window's radius overlapping an existing one** in time, on
any host, is put to the user before the plan is written: two
windows that touch the same host at once are one incident waiting
to happen, whichever session catches it.

## What other sessions do with it

- **Before a change on a host with a `Downtime:` line:** a change
  that would run into the window, or land within 24 hours before
  it, is put to the user first, as information — reschedule, go
  ahead anyway, or reconsider the window. The user decides.
- **Session start** names, in one line each: every window whose
  `Window:` starts within 24 hours, and every `Notify by:` date that
  has passed with no `Notice:` line recorded yet.
- **The activity check**, on a host with a `Downtime:` line, says
  so as part of what it reports for that host.
- **`hostwarden-impact status`** also reports a window that covers
  the current time. Losing SSH during it has the window as its
  likely explanation, never its proven cause: a plan runs only when
  a session is asked to run it (`rules/ssh-unreachable.md`).

## Running it later

A session runs a window only when its user asks — "run plan
pve1-kernel" — never by itself, and never because the window's time
arrived:

1. Read the plan, run `bin/hostwarden-impact radius --report` again
   for its `Hosts:` and `Kind:`, and show what changed since
   `Affected:` was written — a guest added since may still need a
   notice.
2. Name a `Notify by:` that passed with no matching `Notice:` line.
3. Put the steps to the user once. The plan is not an approval: a
   yes given while planning weeks ago covers nothing now, exactly as
   a multi-host yes covers only its own run
   (`rules/multi-host.md` → Changes on several hosts).
4. At the start, announce (`rules/coordination.md`) with the
   window's end as `<until>`.
5. As each step finishes, record it the way
   `rules/multi-host.md` → On each host does. Once every host is
   done, the facts go into `memory.md`, and the plan and its
   `Plan:` and `Downtime:` lines are deleted.

## Telling IT

On request, for a planned window or for a step announced right now
(`rules/coordination.md`), Hostwarden writes a notice for other
admins to pass on or agree with — never a notice to end users,
whose channels and wording are the admin's own call.

- **Chat text**, for short notice: at most three lines — what,
  where, when, how long, what goes with it (the radius as services
  and host names), and who to ask or object to (the operator).
  Hostwarden posts nothing itself; the user pastes it.

      pve1 reboots today 22:00, about 2 min. web1, db1 and shop go
      with it. Questions or objections: jpa.

- **An IT-internal email**, when there is time: the same facts plus
  the steps, rollback and radius from the plan, through
  `hostwarden-email` (`.agents/skills/hostwarden-email/SKILL.md`),
  within the ceiling `AGENTS.md` → Talking to Humans gives an email
  body. Its recipient defaults to `Notice email:` under
  `# Preferences` in `memory/user.md` — the user's own address, so
  they can forward it — never a per-server `Alert email:`, and never
  an end user's address (`rules/secrets.md` and personal data both
  argue against writing one down). Missing, it is asked once and
  written there, the way `rules/ssh-user.md` → Operator records a
  handle.
- **The proposal** is chat text for a window less than a day away,
  an email otherwise; the user picks either way.
- **Once sent,** the plan's `Notice:` line records the form and the
  date. A window run without ever sending a notice keeps that line
  absent; nothing requires one.

Admins who read Hostwarden's own memory get the window through the
`Downtime:` line the moment their work touches the radius, notice or
not.

## Automatic restarts

Automatic updates reboot hosts and restart services at times that
can be predicted roughly — a window nobody planned. `memory.md`
records it as one line:

    - Auto restarts: reboot when needed, 06:00–07:00
      (apt-daily-upgrade + 60 min delay); services after each run
      (needrestart auto); last reboot 2026-09-20 06:14 1m
      (3 measured, 1–2m)

- **When it reboots:** the reboot setting and the update timer's
  schedule together — `Unattended-Upgrade::Automatic-Reboot` and
  `-Time` on Debian and Ubuntu, `reboot =` in `/etc/dnf/automatic.conf`
  on RHEL and Fedora (`never`, `when-changed` or `when-needed`),
  `rebootmgr`'s window on SUSE. Where the OS file names these
  settings (`rules/os/debian.md`, `rules/os/rhel.md`) they are named
  there for this line too. Where reboot is off, or the setting
  cannot be read, this half of the line reads `off` or `unknown`
  rather than guessing a slot.
- **When services restart:** the needrestart mode, or the
  distribution's own apt or dnf hook where there is no needrestart
  (`rules/os/debian.md` → Non-interactive apt runs) — the same
  reading the housekeeping baseline and the fleet audit's
  auto-reboot probe already take.
- **How long a reboot takes:** measured, never estimated, from the
  host's own boot history —
  `journalctl --list-boots -n 4` where the journal reaches back that
  far, `last -x` without one — the gap between a `shutdown` entry
  and the `reboot` entry right after it, for the last three reboots
  the history holds. `last reboot <date> <time> <duration>` names
  the most recent one by its full boot timestamp, `<time>` in the
  host's own local 24-hour clock — a date alone cannot tell a
  second same-day reboot from the one already recorded, and that
  timestamp is the comparable marker the next bullet reads back;
  the parenthetical after it is the count measured and their range.
  With no reboot in the history yet, this half of the line
  reads `unknown`.
- **Who writes it:** `hostwarden-housekeeping` owns the line's
  wording and the probes behind it
  (`rules/server-memory.md` → Who writes which line), the way it
  owns `Backup:` although onboarding writes that one first too.
  `hostwarden-onboard` writes `Auto restarts:` first, at the first
  connection; `hostwarden-housekeeping` refreshes it at every run
  after that, from the probes above plus the boot history, the way
  it refreshes `USB:`, `Passthrough:` and `Backup:`
  (`rules/server-memory.md` → Onboarded and stale lines). The fleet
  audit's own auto-reboot probe
  (`.agents/skills/hostwarden-fleet-audit/references/probes.md` →
  Auto-reboot behaviour) reads and compares the same settings across
  hosts but writes nothing, matching every other probe there and the
  same section's "the fleet audit refreshes no line".
- **Kept current without waiting for a run:**
  - `hostwarden-impact done`, once it lands, writes the downtime it
    measured after a reboot Hostwarden itself ran, from the reboot
    command to the host answering again, moving the `last reboot`
    timestamp to that run's.
  - The activity check compares the host's current boot start
    (`uptime -s`, or the equivalent the loaded OS file's `## Logs`
    section gives) against the full `last reboot <date> <time>` the
    line already carries — a date alone cannot tell a second
    same-day reboot from the one already recorded. A later boot
    reads that reboot's duration with the same
    `journalctl --list-boots -n 2` call — or the family's
    boot-history command where there is no journal — and moves the
    timestamp and duration; an equal or earlier one changes
    nothing.
- **A pending reboot** — `reboot-required`, or a kernel newer than
  the running one — turns the next slot into a real window: read
  the host's own `Auto restarts:` line for the measured duration
  and read `reboot-required`/the kernel check the way housekeeping
  does, since `--report` (`rules/coordination.md` → What-if) does
  not carry either — its fields are role and service lines only.
- **Where it counts:** a change that would overlap its own host's
  next self-scheduled slot is mentioned first, the way a
  `Downtime:` line is above; nothing marks the slot as a `Downtime:`
  line of its own, so `hostwarden-impact status` cannot yet name it
  as a cause of SSH loss the way a planned window's `Downtime:` line
  lets it — confirm a self-scheduled reboot's timing by hand, once
  the host answers again and its boot time bears it out
  (`rules/verify-before-reporting.md`).
- **No line** for a host without automatic updates, for macOS, and
  for Windows, which is report-only.

## Proposing a window

Hostwarden sets no fixed patch day; it helps plan the specific one.
Asked "when should pve1's update happen?", propose a time from:
pending updates and how long the reboot has been pending, the
longest `Notify by:` lead time in the radius, windows already
planned that touch the radius, and the radius's own
`Auto restarts:` slots. Say whether it *must*, *should* or *can*
happen earlier:

- **Must** — a security update whose reboot is already pending.
- **Should** — the automatic slot would reboot the host unannounced
  before the proposed window.
- **Can** — no constraint found.

The admin decides. The proposal becomes a plan only on their yes
(→ The window plan, Building the plan).
