# BMC Event Log

The BMC's System Event Log records power supply failures, fan
failures, memory errors and thermal events, often before the OS
notices and always while the OS was not running. Read it on a
host whose `Management:` line names a BMC this host can reach.

Settle that line first where `memory.md` has none — on any host,
guest included, as `rules/management-controller.md` → When it
applies says, since this run is a calm moment and the rescue path
is not. A scheduled run (`references/scheduled.md`) records
`unknown (not asked)` rather than putting a question to a
console nobody is watching, and names it in the report.

The **check** below then runs only where the line names a
reachable BMC; anything else gives `ipmitool` no device node to
open and is **named as not checked**.

## Probe

```
ipmitool sel info
ipmitool sel elist | grep -E 'Asserted|Deasserted' | tail -n 100
```

`sel info` gives `Entries`, `Percent Used` and `Overflow`.
`elist` resolves each entry's sensor name through the SDR, which
`list` does not, and that resolution is why it runs once: the
whole SDR is read per invocation, and this check is schedulable
(`references/scheduled.md`).

**The filter is what finds a fault.** A power supply that failed
a year ago and was never replaced is still asserted, so
`sel elist last 20` would show the twenty newest records and call
the host clean. Every state change in the whole log passes the
filter instead, and the tail keeps the newest hundred, which is
where each sensor's current state is.

A full 100 lines back means the log holds more state changes than
the window, and the oldest may be cut: say so in the report
rather than calling the check clean. A host that flaps — one
failing fan asserting and deasserting all night — reaches that
every run, which is itself worth reporting.

## Reading the output

**The SEL is a history, not a state.** An entry that reads
`Asserted` is a condition that began; the same sensor later
`Deasserted` is that condition ending. A failure from two years
ago whose part was replaced still stands in the log. So a finding
needs an `Asserted` entry with no later `Deasserted` for the same
sensor **and the same event**, and nothing else counts as a fault
now.

Both halves matter. One sensor carries several conditions — a
temperature sensor asserts `Upper Non-critical going high` and
`Upper Critical going high` separately — so pairing by sensor
alone lets a deassertion of one clear an assertion of the other,
and reports a machine that is still too hot as clean.

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
