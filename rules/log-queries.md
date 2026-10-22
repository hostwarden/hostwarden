# Log Queries

A busy server writes millions of journal lines a day. A query that
reads all of them and throws most away runs into the tool's time
limit, and the answer is lost with it. **Bound every log read by
time or count, and filter where the log is stored, not in a pipe
behind it.**

## journald

- **Count with `-n`, never with `| tail`.**
  `journalctl -t hostwarden -n 20` reads from the end of the
  journal. `journalctl -t hostwarden | tail -n 20` formats every
  entry since the journal began and keeps twenty.
- **Filter by field.** `-t <identifier>`, `-u <unit>`,
  `_UID=<uid>`, `_COMM=<name>`, `-p warning`. The journal indexes
  these and skips everything else.
- **Search text with `-g`, never with `| grep`.**
  `journalctl --since "48 hours ago" -g hostwarden -n 20`. A
  pattern in lowercase matches regardless of case. A journalctl
  older than systemd 237 has no `-g`, and a build without pattern
  support says so ("Compiled without pattern matching support");
  only then pipe, with `--since` as tight as the question allows and
  `| grep … | tail -n <n>` for the newest matches. `grep -m <n>`
  keeps the *oldest* n of the window; it only tells whether
  anything matches.
- **Always give `--since` or `-n`.** A `journalctl` with neither
  reads the whole journal.
- **A pipe is fine where the stream is short or ends early.** The
  oldest entry is `journalctl --no-pager -q -o short-iso | head -1`
  (`-n 1` would return the newest). A tag or field `-g` cannot see,
  such as dma's `dma[<queue-id>]`, is filtered with `| grep` behind
  a `--since` of minutes. So is a stream the field filter already
  makes short: `-t hostwarden` holds Hostwarden's own entries, or
  `-u <unit>` with `--since`, on a journalctl without `-g`.
- `--no-pager` always; `-q` hides the header lines and, for a
  user outside `systemd-journal`, `adm` and `wheel`, the hint that the
  journal is partial. `-o cat` drops timestamp and host when only
  the messages matter.

`grep hostwarden` over the whole journal does not find what
Hostwarden *wrote*: it finds the logins and sudo lines of the
`hostwarden` account. What Hostwarden writes carries the identifier
`hostwarden`, and on a host Heinzel managed before, `heinzel`
(`-t hostwarden -t heinzel`; `rules/activity-check.md`,
`rules/heinzel-legacy.md`).

## Log files

- `tail -n <n> <file>` for the newest lines; `grep -m <n>` keeps
  the oldest n matches. Never `cat <file> | grep`. A family's `syslog_stream` in
  its `## Logs` section reads the files that section names, which is
  its own bound.
- Rotated files only when the question reaches back that far, named
  one by one, newest first. No `zgrep` over `/var/log/*.gz`.

## Without journald

Alpine, FreeBSD and the appliances without systemd log to files:
`## Logs` in `rules/os/<family>.md` names them and how to read
them. The two rules above hold there.

## macOS

`log show` is slow even on a small window. Always give
`--last <n>m` or `--start`, and a `--predicate`; the call and its
details are in `rules/os/macos.md` → Logs.

## One Answer Is Enough

When a precise query has answered the question
(`-t hostwarden --since "48 hours ago"` returns nothing), report
it. Do not follow it with a broad cross-check that reads the whole
log. If you need one, make it as precise as the first.

**A result is an answer only if the session can read the whole
journal.** As a user outside `systemd-journal`, `adm` and `wheel`,
`journalctl` shows that user's own entries alone, so an empty
result, a count of zero and a result with some lines all can leave
out the entries that matter, such as a service's errors. Run the
sudo test of `rules/activity-check.md` → How to check first, and
where it passes, run the query itself under `sudo -n`. Where it
fails, report the result as incomplete.

A query that hit the time limit is not repeated unchanged and not
widened. Narrow it: a shorter `--since`, a field filter, `-n`.
