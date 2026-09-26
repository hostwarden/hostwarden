---
sidebar_position: 8
description: Sends ad-hoc text or files about a managed server by
  email.
---

# Email reports

Send ad-hoc text or files by email about a managed server.

```
 ❯ Email me the output of "df -h" from app.example.com
 ❯ Mail /var/log/auth.log to ops@example.com
```

## Where mail comes from

- **The first email per host asks where to send from** — your
  workstation or the server itself — and can remember the answer.
- **On the server**, Hostwarden uses `sendmail`, `msmtp` or a
  running postfix, OpenSMTPD or Exim; `mail` or `mailx` alone does
  not count.
- **When none is there**, it asks before installing one, and picks
  one that queues the mail — nullmailer, dma or postfix as a null
  client — so a relay that is down for a minute does not lose a
  report; `msmtp` only when you ask for it.
- **Nothing is installed on a Mac or on your workstation.**
- **It sends as a non-root user when possible.**

## Attachments

Attachments are checked for readability and size, get a content
preview before sending, and a file that likely holds a secret is
refused by default.

## Every message

Every message closes with a greeting and a signature naming
Hostwarden and the operator, both overridable in `memory/user.md`,
and carries the headers that keep out-of-office and vacation
auto-replies from answering it.
