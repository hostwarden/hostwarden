# Features

## Auto OS-detection

The first time you point Hostwarden at any machine, it
detects the OS, gathers hardware info, and remembers
everything for future sessions.

## DNS alias detection

When multiple DNS names point to the same server,
Hostwarden detects this automatically by comparing IP
addresses. The first hostname becomes the canonical
name; additional names become symlinks that share the
same memory. Each alias can have its own SSH user.

## Memory across sessions

After working on a machine, Hostwarden remembers it.
Next week you start a new session and type:

```
 ❯ Check on web1.example.com.
```

It reads
`memory/servers/web1.example.com/memory.md`, already
knows it's Debian 12 with nginx and PostgreSQL,
checks the local changelog, and picks up right where
it left off.

## Session to-do list

When a multi-step task gets interrupted — connection
drop, conversation ends, laptop closes — Hostwarden
keeps a to-do list in
`memory/servers/<hostname>/todo.md` with checkboxes
for each step. On reconnection it shows what's still
pending and asks whether to continue or start fresh.

## Housekeeping checks

Run routine health inspections on any server:

```
 ❯ Run housekeeping on app.example.com
```

Hostwarden checks disk, memory, load, pending updates,
firewall, SSL certificates, failed services, and
server-specific services. Problems are highlighted
at the top of a concise report.

## Security audit

Check security configuration on any server:

```
 ❯ Run a security audit on app.example.com
```

Hostwarden checks SSH password authentication settings,
firewall status, and reports issues by severity.

## Fleet audit

Compare key policies across every server Hostwarden knows about:

```
 ❯ Run a fleet audit
 ❯ Vergleiche die Policies auf allen Servern
```

Hostwarden probes unattended-upgrades, sshd effective config,
firewall posture, MTA, time sync, auto-reboot behaviour and,
on Ubuntu, Pro/ESM coverage and needrestart's restart mode
on each host in `memory/servers/`, then renders a
side-by-side table that highlights where servers disagree.
It makes no configuration changes on any host (it only
writes one audit-trail line to each journal). Use it after
fixing a config bug on one server to find which others
carry the same bug, or as a periodic consistency check.

## Email reports

Send ad-hoc text or files by email about a managed server:

```
 ❯ Email me the output of "df -h" from app.example.com
 ❯ Mail /var/log/auth.log to ops@example.com
```

The first email per host asks once where to send from
(local workstation or the server itself) and remembers the
answer. On the remote path Hostwarden prefers an existing MTA
(postfix, sendmail, msmtp, mail/mailx) and asks before
installing one. Sends as a non-root user when possible.
Attachments check sender readability, file size, and offer
a content preview before sending.

Every message closes with a two-line greeting from Hostwarden
(`Viele Grüße / Hostwarden`) followed by a short signature
naming Hostwarden, the project URL, and the operator who
requested the send. The operator name comes from
`Operator name:` in `memory/user.md` (with a sensible
fallback chain to git config and the system full name).
Set it once; edit it any time. Both lines are
overridable: a `Greeting:` line in `memory/user.md` or
`memory/servers/<host>/memory.md` replaces the default
wording.

Every Hostwarden email also carries the RFC 3834
`Auto-Submitted: auto-generated` header plus
`Precedence: bulk` and `X-Auto-Response-Suppress: OOF,
AutoReply`, so out-of-office and vacation auto-replies
do not fan back at the operator.

## Plan mode (Claude Code)

For complex or unfamiliar tasks, switch to plan mode
before touching anything:

```
 ❯ /plan Migrate the database from MySQL to
   PostgreSQL on db.example.com
```

Hostwarden explores the server, checks what's running,
reads configs, and drafts a step-by-step plan — but
makes no changes. You discuss the approach, adjust
it, and only when you approve does execution begin.

> **Note:** The `/plan` command is a Claude Code
> feature; in the desktop app, pick Plan in the mode
> selector instead. OpenCode does not have an
> equivalent — simply ask Hostwarden to plan before
> acting.

## Local administration

Hostwarden also works on the local machine — no SSH
needed, commands run directly. The same safety rules,
memory, and guardrails apply whether the target is a
remote server or your own laptop.

This works on both Linux and macOS:

```
 ❯ Update all Homebrew packages on this Mac
```

```
 ❯ Check if the firewall is configured on
   this machine
```

