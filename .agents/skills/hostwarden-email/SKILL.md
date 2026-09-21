---
name: hostwarden-email
argument-hint: "[hostname] [recipient]"
description: Send an email about a managed server — ad-hoc text
  and/or file attachments. Use when the user asks to "email me
  X", "send X by mail", "mail this to <address>", "attach
  /var/log/foo to an email", or "send a report by email". The
  first email per host asks where to send from (local
  workstation vs the server itself). On the remote path,
  prefers the existing MTA (postfix, sendmail, msmtp,
  mail/mailx) and asks before installing one. Sends
  unprivileged — as the SSH user, or dropping from root via
  `runuser`/`su -` when the session is root. Attachments
  check sender
  readability, size, and offer a content preview before
  sending. **Never run automatically** — only on explicit user
  request.
---

# hostwarden-email

Send ad-hoc text and file attachments by email about a managed
server. The report content is *about* the server; whether the
mail leaves *from* the server or *from* your workstation is a
per-host preference that's asked once and remembered.

## Workflow

1. **Onboarding pipeline.** Run `rules/first-connection.md` in
   full. No "quick question" exception — even a one-line email
   goes through every step of it.

2. **Load overrides**, key `hostwarden-email`, per
   `rules/overrides.md`. Read `memory/servers/<host>/memory.md`
   for recipient, source, transport and policies — see
   "Per-server memory" below.

3. **Resolve recipient.** In order of precedence:
   1. **User said an explicit address** ("send to alice@…",
      "mail it to bob@example.com") → use that. Don't override
      it with stored values.
   2. **Per-server memory** — `memory/servers/<host>/memory.md`
      has an `Alert email:` line (the established pattern) →
      use that.
   3. **"Send me" shorthand** ("email me", "send me", "mail it
      to me") and the user's default email is recorded in
      Claude Code's auto-memory (the `MEMORY.md` index will
      show a "Default email" entry under User → load that file
      and use the address) → use it without prompting. Still
      write the address back to the per-server `memory.md` as
      `- Alert email: <addr>` on first use so the skill stays
      self-contained for future runs.
   4. Otherwise, ask once via the picker, then persist to
      `memory.md` as in (3).
   - Never guess or invent a recipient.

4. **Consent gate 0 — sender side (local vs remote).** Check
   `memory.md` for `Email source: local | remote`:
   - `local` → jump to step **5L**.
   - `remote` → continue with step **5R**.
   - Missing → ask the user with four options:
     > "First-time email for `<host>`. Send from where?"
     - **Remote — once**: send from the server this time, ask
       again next time.
     - **Remote — always for this host**: write
       `Email source: remote` into `memory.md`, then continue
       to 5R.
     - **Local — once**: send from this workstation this time,
       ask again next time.
     - **Local — always for this host**: write
       `Email source: local` into `memory.md`, then jump to
       5L.

   Why this gate exists: some hosts have great mail
   infrastructure (e.g. a working local Postfix relaying to
   an external smarthost); others have none and the user may
   prefer not to install anything on them. Either side is a
   perfectly valid choice the user should be able to lock in
   once.

### 5. Transport

Read the one file for the side gate 0 chose, and only that
one — the two branches share no step, so reading both is
reading a workflow that will not run.

- **Local** → `references/transport-local.md`. Probing the
  workstation, and why nothing is installed there.
- **Remote** → `references/transport-remote.md`. Probing the
  host, the two consent gates around using or installing an
  MTA, what to install and why that one, and picking a
  non-root sender identity. The install (5R.3) is the only
  root-privileged operation in the whole workflow.

## Shared steps (both 5L and 5R converge here)

6. **Compose** — `references/compose.md`. Subject and body
   shape, the five-line ceiling on your own text, the
   attachment gates (readability, size, the default refusal
   on likely-secret files, the content preview), and the
   fixed greeting and signature.

7. **Send** — `references/send-verify.md`. The canonical
   path builds the message with headers, because hostwarden
   always injects the anti-auto-reply triple and MIME
   headers when attaching. A remote send runs as the SSH
   user when that is not root, and drops from root via
   `runuser`/`su -` when it is.

8. **Verify delivery** — `references/send-verify.md`. Exit
   code, then the mail log from the last minute.

9. **Update `memory.md`** if anything new was learned (source
   chosen, transport discovered or installed, recipient
   added, policy set, sender identity confirmed, per-host
   operator override requested). Use the shape under
   "Per-server memory" below. Only write `…always` or
   `…never` lines when the user explicitly picked them;
   absence means "ask next time". The global `Operator name`
   is persisted to `memory/user.md`, not to per-server
   memory — write a per-host `Operator name:` line only when
   the user asks for a different signer on that specific
   host.

10. **Log to changelog** per `rules/changelog.md`:

    ```
    logger -t hostwarden "Email to <recipient> from \
        <local|remote/<user>>: <subject>"
    ```

## Per-server memory

No new file. The skill reads and updates lines in the
existing `memory/servers/<host>/memory.md`, extending the
existing per-server memory format. Policy lines are only
written once the user picks **Always** or **Never**;
absence means "ask next time".

```
- Mail: <transport summary>          # remote path only
                                     # e.g. "postfix + bsd-mailx
                                     #       (outbound via the provider MX)"
                                     # or  "nullmailer via smtp.example.com:587"
- Alert email: <recipient address>
- Email source: local | remote       # gate 0 — sender side
- Email sender: <username>           # remote path only — non-root user
- Email send policy: always | never  # gate A — use existing remote MTA
- MTA install policy: always | never # gate B — install a new remote MTA
- Operator name: <full name>         # per-host override for signature
                                     # (global default in memory/user.md)
- Greeting: <closing text>           # per-host override for the greeting
                                     # (global default in memory/user.md;
                                     # absent = "Viele Grüße / Hostwarden")
- From: <mailbox>                    # per-host From override
                                     # (default: noreply@<host>)
- Reply-To: <addr>                   # per-host Reply-To override
                                     # (global default in memory/user.md)
```

The two policy lines are deliberately separate: a user may
be happy to use a mature postfix that's already there
("send: always") but want to be asked every time before
hostwarden installs new packages on a different server
("install: ask" = line absent). Mirrors the shape of
`memory/service-policy.md`'s split between `restart-auto`
and `restart-never`.

## Rules this skill leans on

The `references/` files are named by the steps that need
them. Beyond those:

- `rules/first-connection.md` — the mandatory onboarding
  pipeline.
- `rules/server-memory.md` — server memory file format.
- `rules/changelog.md` — session logging procedure.
- `rules/best-practices.md` — anti-pattern review before
  installing software.
- `rules/service-class-check.md` — mandatory conflict check
  before installing an MTA (gate B).
- `rules/backups.md` — config backup before any edit (e.g.
  the smarthost credentials file).
- `rules/secrets.md` — secrets hygiene; default-refuse
  attachment gate for likely-secret files.
