# Fleet Audit Output Format

Render one Markdown table per probe category, then a "Drift
detected" section, then a "Warnings" section. Keep the text
scannable.

## Header

```
## Fleet Audit

Date: YYYY-MM-DD HH:MM
Hosts in scope: host1, host2, host3
Skipped: host4.example.com (no SSH user known)
```

## One table per category

Hosts are columns (sorted alphabetically). Settings are
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

Two sentinels mark a cell that holds nothing to compare:

- `unknown(needs-root)` — the probe could not run for lack of
  privileges (see "Privilege handling" in
  `references/probes.md`). Render it as `needs root`.
- `n/a (<reason>)` — the host's OS family has no such setting,
  such as the unattended-upgrades keys on Alpine, or a row only
  another family has. Render it as `n/a`.

```
| PermitRootLogin     | prohibit-password | needs root |
```

Both are **excluded from drift detection**: an unreadable or
missing value is not a disagreement. Never mark such a row
with the `!` prefix or list it in "Drift detected" solely
because one cell reads `needs root` or `n/a` — the other
hosts' values may still drift against each other. Hosts of
different families running different tools is not drift
either; the same tool set up differently is. Instead, mention
the affected hosts once in a one-line note under the table,
e.g.:

```
host2: sshd and firewall state unreadable (no root, no
passwordless sudo or doas) — re-run with a privileged user
for full coverage.
```

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
   host2 or document the exception in
   memory/servers/<host2-fqdn>/memory.md.
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

## Skipped hosts

Mention skipped hosts at the top of the report (in the
header), and again at the bottom in a one-line footer so
they are not forgotten:

```
Skipped: host4.example.com (no SSH user known),
         host5.example.com (unreachable)
```
