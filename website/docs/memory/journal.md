---
sidebar_position: 4
title: Journal and changelog
description: The one-line journal entry on the server, the full entry
  in your workspace, and what you see about both when you connect.
---

# Journal and changelog

Every change is written down twice, for two readers. The server's own
journal gets one plain sentence for any admin who logs in after you.
Your workspace gets the full technical record for the next session and
for an audit. Every session writes at least one entry, a session that
changed nothing included.

|         | System journal           | Local changelog                 |
| ------- | ------------------------ | ------------------------------- |
| Where   | on the server            | `machines/<host>/changelog.log` |
| For     | any admin, no Hostwarden | Hostwarden sessions, audits     |
| Answers | who, what, why           | also how, where, how to undo    |
| Length  | one sentence             | as long as needed               |

## On the server: the journal

One line per change, not per command, tagged `hostwarden`:

```
[alice as root] app.example.com now deploys via two alternating app
slots (blue/green), so new releases go live without dropping
requests — because deploys used to restart the app and interrupt
visitors
```

- **`[alice as root]`** — your handle, and the account the commands
  ran as. In a team where everyone logs in as `root`, the handle is
  what tells your work from a colleague's.
- **Plain language** — the service and the effect, written for someone
  who has never heard of Hostwarden. No command lines or flags; a
  version or path only when it is the news.
- **`— because …`** — the reason, when it is known. It is never
  invented.
- **A session that only read** logs one `read-only:` line, so the next
  visitor still sees that someone was there.

Backup paths, commit hashes, port lists and rollback recipes stay out
of the journal; they go into the changelog below.

### Reading it yourself

```bash
# All entries, those of an old Heinzel session included
journalctl -t hostwarden -t heinzel

# Filter by date
journalctl -t hostwarden -t heinzel --since "2026-02-01"

# Last 20 entries
journalctl -t hostwarden -t heinzel -n 20

# macOS
log show \
  --predicate 'senderImagePath CONTAINS "logger"' \
  --info --last 7d | grep -E 'hostwarden|heinzel'

# Alpine and FreeBSD (syslog)
grep -E 'hostwarden|heinzel' /var/log/messages
```

A script Hostwarden deploys logs under its own name
(`backup-usb-watch`), so the tag stays a record of sessions. A script
that still logs under `hostwarden` or `heinzel` — often one an old
Heinzel session wrote — is reported as a **watcher** when Hostwarden
connects, never as somebody at work, and housekeeping lists it until
it has a tag of its own.

## In your workspace: the changelog

Every journal headline is mirrored to the host's `changelog.log`, with
a timestamp and the detail the journal leaves out:

```
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
```

| Label       | What it holds                                         |
| ----------- | ----------------------------------------------------- |
| `Detail:`   | what was changed, where                               |
| `Source:`   | for a deployed file: its master and hash              |
| `Rollback:` | how to undo it                                        |
| `Verify:`   | how the result was checked                            |
| `Flags:`    | a constraint later work has to respect                |

A `Flags:` or `Rollback:` that still holds is also copied to the end of
the host's `memory.md` as a standing line, so the next session sees it
without reading the whole log ([A host's memory](host-memory.md)).
Entries older than two years are trimmed, except one a standing line
still points to. When the session is done with the host, the files it
wrote are committed to the workspace with the headline as the commit
message.

## When you connect: recent activity

Every connection reads the host's journal for the last seven days of
Hostwarden entries — its own and those of an old Heinzel session — and
shows a short summary before any work:

```
Recent activity (last 7 days):
- [2026-04-12 14:32] [hostwarden] [alice as root]
  Installed nginx, opened port 443 — because static
  site launch
- [2026-04-11 09:15] [heinzel] [bob as bob] Updated
  Node.js 22.14 → 22.15
```

- **It says how far back the log reached.** Where that is less than a
  week, as on hosts that keep their logs in RAM, it names the date and
  reads your local changelog for the time before.
- **Scripts are told apart from sessions.** A watcher logging under the
  tag gets one line of its own, never mixed with the work of people.
- **Other sessions and tools show up.** Sessions registered on the host
  right now, and recent Ansible runs, are named in the same summary.
- **A planned downtime** on the host is named in one line:
  *"Downtime: 2026-10-05 22:00–23:30 (plan pve1-kernel)."*

The whole changelog is read only when history matters: you ask what
changed or when, a fault may trace back to an older change, or a
rollback needs its full entry.

## No secrets

A password, key or token never goes into a journal line or a changelog
entry. Where a credential matters, the entry records where it lives and
its permissions ([Secrets and untrusted output](../safety/secrets.md)).
