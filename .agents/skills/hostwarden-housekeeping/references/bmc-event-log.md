# BMC Event Log

The BMC's System Event Log records power supply failures, fan
failures, memory errors and thermal events, often before the OS
notices and always while the OS was not running. Read it on a
host whose `memory.md` has a `Management:` line naming a BMC
this host can reach; a host with no line yet is settled first by
`rules/management-controller.md` → Detection. A line that names
no BMC, or a BMC the host cannot reach, has no device node for
`ipmitool` to open: list the check under "Skipped".

## Probe

```
ipmitool sel info
ipmitool sel elist last 20
```

`sel info` gives `Entries`, `Percent Used` and `Overflow`;
`elist` resolves each entry's sensor name through the SDR, which
`list` does not. `last 20` keeps a log with thousands of entries
out of the conversation.

## Reading the output

**The SEL is a history, not a state.** An entry that reads
`Asserted` is a condition that began; the same sensor later
`Deasserted` is that condition ending. A failure from two years
ago whose part was replaced still stands in the log. So a finding
needs an `Asserted` entry with no later `Deasserted` for the same
sensor, and nothing else counts as a fault now.

An entry whose timestamp reads `Pre-Init Time-stamp` was written
while the BMC's clock was unset: the event happened, its age is
unknown. Setting that clock is a write and is out of scope, as is
clearing the log.

## Findings

Severities as in `references/report-format.md`:

- **CRITICAL:** an asserted and not deasserted failure of a power
  supply, a fan, a processor or a voltage rail, and an
  uncorrectable memory error.
- **WARN:** any other asserted and not deasserted entry,
  correctable memory errors, a thermal event, and a log that
  reports `Overflow` or `Percent Used` at 90 or more — a full SEL
  stops recording, so the next failure is not logged at all.
  Clearing it is the user's call, never Hostwarden's.
- **INFO:** entries dated after the previous housekeeping entry
  in the host's `changelog.log` (`rules/changelog.md`) that are
  none of the above, by count. Not `Last connected:`, which this
  session has already moved to today, and not a stored record
  number: record IDs restart at 1 when a user clears the log, and
  a stored high-water mark would then hide every later entry.
- **Named as not checked**, never as passing: no root, no
  `ipmitool`, or no device node to reach the BMC through.
