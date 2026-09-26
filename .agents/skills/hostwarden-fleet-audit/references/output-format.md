# Fleet Audit Output Format

Render one Markdown table per probe category, then a "Drift
detected" section, a "Warnings" section, "Decided" where it
applies, and a "Memory" section. Keep the text scannable.

## Header

```
## Fleet Audit

Date: YYYY-MM-DD HH:MM
Hosts in scope: host1, host2, host3, pve1, web1, db1
On pve1: web1, db1 (via host)
Skipped: host4.example.com (no SSH user known)
```

One `On <host>:` line per group from the skill's step 1,
naming its guests in scope and marking those reached through
the host. A group whose host is skipped or outside this run
keeps its line.

## One table per category

Hosts are columns, sorted alphabetically, except that each
group's guests follow their host in alphabetical order, with
`↳` in front of the name. They stand where their host would,
whether or not it has a column in this table. Settings are
rows. Use the literal value where short enough; otherwise
abbreviate to `(see drift below)` and detail it in the drift
section.

```
### Unattended-upgrades

| Setting                              | host1   | host2   | host3   |
|--------------------------------------|---------|---------|---------|
| Update-Package-Lists                 | 1       | 1       | 1       |
| Unattended-Upgrade                   | 1       | 1       | 1       |
| Origins covers -security pattern     | yes     | yes     | yes     |
| Mail                                 | ops@…   | ops@…   | ops@…   |
| MailReport                           | only-on-error | only-on-error | only-on-error |
| Automatic-Reboot                     | true    | true    | true    |
| Automatic-Reboot-Time                | (unset) | (unset) | (unset) |
| Remove-Unused-Kernel-Packages        | true    | true    | true    |
```

Mark rows that differ across columns with a `!` prefix in
the row label and keep the literal value in each cell — so
the eye lands on it:

```
| ! Automatic-Reboot-Time              | (unset) | (unset) | 05:30   |
```

## Cells without a comparable value

Three sentinels mark a cell that holds nothing to compare, and
none of them is drift:

- `unknown(needs-root)` — the probe could not run for lack of
  privileges, sudo's covered reruns included (see "Privilege
  handling" in
  `references/probes.md`). Render it as `needs root`.
- `unknown(sshd-failed)` — sshd refused to print its
  configuration although the probe ran as root
  (`references/probes.md` → sshd effective config). Render it as
  `sshd failed`.
- `n/a (<reason>)` — the host's OS family has no such setting,
  such as the unattended-upgrades keys on Alpine, or a row only
  another family has, or a value a container takes from its
  host (see "Containers" in `references/probes.md`). Render it
  as `n/a`.

```
| Setting             | host1             | host2      |
|---------------------|-------------------|------------|
| PermitRootLogin     | prohibit-password | needs root |
```

```
| Setting              | host1  | pve1    | ↳ db1   |
|----------------------|--------|---------|---------|
| Active timesync unit | chrony | chrony  | n/a     |
```

Both are **excluded from drift detection**: an unreadable or
missing value is not a disagreement. Never mark such a row
with the `!` prefix or list it in "Drift detected" solely
because one cell reads `needs root` or `n/a` — the other
hosts' values may still drift against each other. A host
that has no firewall or time service while others have one
is still drift, whatever its family. Instead, mention
the affected hosts once in a one-line note under the table,
e.g.:

```
host2: sshd and firewall state unreadable (no root, and no
sudo or doas that runs everything without a password) —
re-run with a privileged user for full coverage.
```

## DNS resolver sets

One table per set (`references/probes.md` → DNS resolver sets), its
members as columns and a row per name space, each cell the record
count. The names that differ go to the drift entry, not into cells:

```
### DNS resolver sets — pihole1, pihole2

| Name space  | pihole1    | pihole2    |
|-------------|------------|------------|
| ! home.arpa | 14 records | 13 records |
```

```
4. **home.arpa**: pihole1 answers nas.home.arpa A 192.168.1.20,
   pihole2 does not know the name — clients of pihole2 get
   NXDOMAIN. Suggested fix: add the record on pihole2 as
   `rules/dns.md` → The proposal lists it.
```

## Naming

One row, computed from memory alone — `memory/naming.md`, each
host's directory name and `- FQDN:` — with no probe on the host
(`rules/naming-scheme.md`). Render it as its own single-row table
after the probed categories, with a column for **every** host of
step 1, skipped and unreachable ones included: unlike every other
table here, this row needs no connection, so none of the reasons
that drop a host from the probed tables (skipped, unreachable,
`blocked:`) drop it from this one.

```
### Naming

| Setting  | host1     | host2                  | ↳ db1     | nas1    |
|----------|-----------|------------------------|-----------|---------|
| ! Naming | on scheme | off scheme → fsn-web02 | on scheme | exempt  |
```

Four values, never abbreviated:

- `on scheme` — the name checks out against the block that applies
  to it, label and domain both (`rules/naming-scheme.md` → Checking
  a name).
- `off scheme → <name>` — a block applies and the name does not
  check out; `<name>` is the name that block would give it now, or
  `off scheme, name not proposed` where its role token cannot be
  derived (`rules/naming-scheme.md` → Existing hosts: gradually,
  never forced).
- `exempt` — the host is on that block's `Exempt:` line.
- `no scheme` — no block's `Applies to:` selector reaches the host.

A host two blocks would govern is resolved into one of these four
before its cell is filled in, never left as a fifth value
(`rules/naming-scheme.md` → Which block applies to a host).

Mark the row with `!` and list it in "Drift detected" whenever it
is not the same value on every host, `no scheme` and `exempt`
included: a fleet split between a scheme and no scheme is drift
like any other. A range whose observed DNS suffix
(`rules/network-topology.md` → Ranges) differs from the applicable
block's domain gets a line of its own in "Drift detected" for that
range's hosts, distinct from the per-host row above.

## Drift detected

After all tables, a numbered list. Each entry: which hosts
disagree, what the setting means, suggested fix.

```
### Drift detected

1. **Automatic-Reboot-Time**: host3 sets "05:30", others
   leave it unset. Deferring the kernel reboot by ~22h
   leaves new userland running on the old kernel
   (vulnerability + ABI risk). Suggested fix: comment out
   the line on host3 to match the rest of the fleet.

2. **PasswordAuthentication**: host2 has it set to "yes",
   host1 and host3 have "no". Suggested fix: confirm
   intent on host2; if no policy reason, disable.

3. **Firewall tool**: host1 uses ufw, host2 has no
   firewall installed. Suggested fix: install ufw on
   host2, or record why it has none as a decision
   (`rules/decisions.md`).
```

## Empty drift

If every probe agrees across the fleet, replace the section
with a single line:

```
### Drift detected

None — fleet is consistent across all audited categories.
```

Consistent is not the same as healthy, and this line only ever
claims the first. The Warnings section below still gets rendered.

## Warnings

Every `warnings:` line the probes returned, grouped by host.
These judge one host against the criteria in
`references/probes.md`, not against the other hosts, so a fleet
that agrees on a bad value produces no drift and every warning:

```
### Warnings

- **host1**: 14 legacy iptables rules alongside nf_tables —
  `nft list ruleset` does not show them, so the effective policy
  is not what the firewall tool reports.
- **host1, host2, host3**: pending kernel reboot, uptime 31d —
  automatic reboot has not fired.
- **host2**: `nftables.service` enabled next to an active ufw —
  the unit flushes ufw's rules on start.
```

If no probe returned a warning, say so in one line rather than
dropping the heading — an absent section reads as an oversight,
and the reader cannot tell it from one nobody rendered:

```
### Warnings

None.
```

## Decided

After Warnings, only when a decision settled a disagreement or a
warning: one line per decision, its heading, who and when, and the
hosts it covered in this run.

```
### Decided

- **host2**: no firewall — No local firewall (user, 2026-09-18)
- **host1, host3**: needrestart restarts services itself —
  Needrestart stays automatic (user, 2026-08-19)
```

A decision whose `Revisit:` date has passed gets `— revisit due`
at the end of its line.

## Memory

After Decided, from the memory files alone: one line for the
hosts without an `Onboarded:` line, and one per host whose lines
housekeeping refreshes are stale, naming those its memory has and
the date they go by (`rules/machine-memory.md` → Onboarded and
stale lines). Each names the run that brings it up to date.

```
### Memory

- Not onboarded: db1.example.com (registered through
  pve1.example.com), mail1.example.com — onboard them
  (`hostwarden-onboard`) or log in to the guest once
- **web1**: stale — USB, Passthrough, disks (last housekeeping
  2026-05-01) — run housekeeping
```

Where every host is onboarded and nothing is stale, the section
is one line, `None.`

## Skipped hosts

Mention skipped hosts at the top of the report (in the
header), and again at the bottom in a one-line footer so
they are not forgotten:

```
Skipped: host4.example.com (no SSH user known),
         host5.example.com (unreachable)
```
