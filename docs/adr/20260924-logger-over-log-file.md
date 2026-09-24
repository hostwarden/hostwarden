---
id: 20260924-logger-over-log-file
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [changelog, logging]
---

# Log to the system journal, not a custom file

## Context

Decided in Heinzel commit 2a5fdabd on 2026-02-26, before this
repository's own records existed. The changelog wrote every
session's audit trail to a custom file, `/var/log/heinzel.log`
on the server. That file needed its own rotation, offered no
query tool, and put a fixed path on every distribution alike,
Alpine's syslog layout included.

## Decision

Every session logs its audit trail with `logger -t heinzel`
(now `-t hostwarden`) instead, handing rotation and querying to
the system's own logger — `journalctl` on systemd distributions,
syslog elsewhere.

## Consequences

`rules/changelog.md` carries the mechanism and the `logger`-failure
fallback; `rules/activity-check.md` → How to check carries reading
it back, journal or OS-file `## Logs` alike. A proposal to write a
custom log file again is answered with this record.
