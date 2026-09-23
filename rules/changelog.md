# Changelog

Two layers for two audiences:

1. **System journal** (on the server) — one-line,
   plain-language headlines for *other admins*.
   `journalctl -t hostwarden` should read like a
   colleague's handover notes, not a debug dump.
2. **Local changelog**
   (`memory/servers/<hostname>/changelog.log`) — the
   full technical detail for future Hostwarden sessions
   and audits.

The journal headline answers *who, what, why*. The
local changelog additionally answers *how, where,
and how to undo it*.

## Journal Headlines (remote)

Log to the system journal:
`logger -t hostwarden "message"`. Do not add timestamps
(the system logger handles them). Where the loaded OS
file's `## Logs` section names another writer, use that
one.

Every session gets at least one entry — sessions
that change nothing log a single `read-only:`
summary.

Reading back: `rules/activity-check.md` → How to
check.

If `logger` fails, log to the local changelog only.
The same holds when the loaded OS file says `logger`
can succeed without writing, and its check shows
that it did.

### Entry format

One sentence, written for a sysadmin who has never
heard of Hostwarden and was not part of the session:

    [<operator> as <unix-user>] <what changed, in
    plain language> — because <why>

```
logger -t hostwarden "[alice as root] app.example.com \
now deploys via two alternating app slots \
(blue/green), so new releases go live without \
dropping requests — because deploys used to restart \
the app and interrupt visitors"
```

- `<operator>` is the handle `rules/ssh-user.md` →
  Operator names; `<unix-user>` is the account the
  commands ran as (`root`, `alice`, …). Always
  include both, even when they are identical — the
  prefix is what lets admins tell each other's work
  apart.
- **Plain language.** Name the service and the
  effect an outsider can understand. No abbreviation
  soup, no command lines, no flag dumps. A version
  or path may appear when it *is* the news
  ("upgraded nginx 1.26.3-3+deb13u2 → u5").
- **One sentence, ~250 characters max.** If you are
  tempted to write more, the overflow belongs in the
  local changelog, not in the journal.
- **One entry per change, not per command.** Ten
  commands that together set up one backup job log
  one entry. Unrelated changes log separately.
- **Include the why** in the single fixed shape
  `— because <reason>` whenever the reason is known
  (from the user's request or the surrounding
  context). If the reason is not known, omit it —
  never invent one.
- **Flags for other admins get their own entry.** A
  constraint a colleague must know ("database
  migrations must now stay backward-compatible")
  deserves its own headline, not a subordinate
  clause buried in another entry.

Other rule files and skills show example message
*bodies* (e.g. `Reloaded <svc> (auto, policy)`); the
envelope above — identity prefix and `— because` —
always applies on top of them.

### What stays out of the journal

Backup file paths, commit hashes, CI run IDs,
rollback recipes, port lists, intermediate failures
and their workarounds. All of that is valuable —
record it in the local changelog (below) and in
`memory.md`, never in the headline.

## No Secrets

Credential values never go into journal or
`changelog.log` entries — record location and
permissions instead. See `rules/secrets.md`.

## Local Changelog (full detail)

Mirror every journal headline to
`memory/servers/<hostname>/changelog.log` with a
full `[YYYY-MM-DD HH:MM]` timestamp, then indent the
technical detail the journal omitted:

    [2026-06-11 09:50] [alice as root]
    app.example.com now deploys blue/green …
    — because deploys interrupted visitors
      Detail: templated app@.service (blue :4003,
      green :4005); nginx upstream moved to
      /etc/nginx/snippets/app-upstream.conf; sudoers
      rewritten for slot management.
      Rollback: re-enable app.service, restore vhost
      backup from /var/backups/hostwarden/….
      Verify: ~135 HTTPS probes during two slot
      switches, all 200.
      Flags: migrations must now stay
      backward-compatible.

A new entry starts with `[` in column 1; indented
lines continue the previous entry. Use the labels
`Detail:`, `Source:`, `Rollback:`, `Verify:`, `Flags:`
as applicable — skip empty ones.

`Source:` belongs to a deploy (`rules/deployed-files.md`):
one line per file, naming its master in the workspace
and the first 16 characters of the hash it was
deployed with, which finds that version in the
workspace history for a later rollback:

      Source: servers/web1.example.com/files/usr/local/
      bin/backup-usb-watch (sha256 98ea6e4f216f2fb4)

Trim entries older than 2 years when writing, except
one a standing line in `memory.md` still points to
(below).

### Standing lines

A `Flags:` that constrains later work on the host,
and a `Rollback:` for a change that stays in place,
also go into the host's `memory.md` when the entry
is written: as its last lines, one per entry, with
the entry's timestamp to find the full entry by:

    - Flags: migrations must stay backward-compatible
      (2026-06-11 09:50)
    - Rollback: blue/green deploys — re-enable
      app.service, restore the vhost backup
      (2026-06-11 09:50)

Remove the line once it no longer holds: the
constraint is lifted, or a later change replaces or
undoes what the rollback restores. A `Flags:` or
`Rollback:` about this session alone stays in the
log.

A choice the user made is not a `Flags:` line but a
decision (`rules/decisions.md`).

### Reading it

Every connection reads the entries of the activity
check's seven-day window
(`rules/activity-check.md` → How far back it
reached); what still binds from older entries is in
`memory.md` as standing lines. Read the whole log
only when history matters: the user asks what
changed or when, a fault may trace back to an older
change, or a rollback needs its full entry.

## The Workspace

As soon as this session is done with a host and this
changelog is written — for a session that changed it, the
moment it deregisters (`rules/parallel-sessions.md`); for one
that only read, once its visit is recorded — commit the files
it wrote there, not at a session end the agent rarely sees,
with the journal headline as the message:
`bin/hostwarden-sync commit "<headline>" <paths>`. Which paths,
and what to leave out: `rules/parallel-sessions.md` → The
workspace. A session that changed nothing in `memory/` commits
nothing.

Then push, if the workspace has a remote:
`bin/hostwarden-sync push`. The first push of a session
waits for the user's yes — *"Push the workspace to its
remote?"* — because it sends hostnames and the network's
layout off this machine. After a yes, later pushes in the
same session go without asking. A no stands for the rest
of the session; the commits wait for the next one.
