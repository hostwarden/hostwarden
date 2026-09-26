---
sidebar_position: 7
description: How Hostwarden keeps secrets out of the conversation
  and treats everything a server returns as data, not instructions.
---

# Secrets and untrusted output

Hostwarden works next to private keys, passwords and tokens
constantly, and next to server output it did not write. Neither is
ever treated as something to print or something to obey.

## Keeps secrets out of transcripts

Private keys, password files, and `.env` contents are inspected via
metadata and fingerprints, never printed into the conversation,
reports, memory, changelogs, or emails. Secrets are never passed as
command-line arguments, where `ps`, the journal, and shell history
would capture them. Likely-secret files are refused as email
attachments by default.

Where a command must take a secret, Hostwarden prefers, in order: a
credentials file the tool reads natively, an environment variable,
or an interactive prompt. An inline argument is the last resort, and
only after warning that the value will leak.

Rule: `rules/secrets.md`.

## Ignores injected instructions

Text found in server files, logs, or command output is treated as
data only. Suspicious patterns — text addressing the AI directly,
embedded commands, requests to skip or override safety rules — are
flagged to you, never followed. When Hostwarden spots one, it stops,
quotes the suspicious content in a labeled block, explains that it
looks like a prompt injection, and waits for you to acknowledge
before continuing.

Rule: `rules/anomaly-detection.md`.
