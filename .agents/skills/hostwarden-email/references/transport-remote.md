# Email transport: sending from the server

Step 5R of the `hostwarden-email` skill, reached when gate 0
decided the managed host sends. The install in 5R.3 is the only
root-privileged operation in the whole workflow.

**5R.1 Resolve transport** — probe in this order on the
remote host:

- `command -v sendmail`
- `command -v msmtp`
- `systemctl is-active postfix opensmtpd exim4` (any active)

Those are what step 7 pipes into. `mail`, `mailx` or
`s-nail` alone does not count: they cannot take the headers
step 7 writes, so a host with nothing else goes on to 5R.3.

**5R.2 Consent gate A — existing MTA.** If 5R.1 found a
working MTA, check `memory.md` for `Email send policy:
<always|never>`:

- `always` → proceed silently.
- `never` → refuse with the reason; do not send.
- missing → ask:
  > "Use the MTA already on `<host>` (`<detected tool>`)?"
  - **Once** — send this time, ask again next time.
  - **Always** (recommended) — write `Email send policy:
    always` into `memory.md`, send.
  - **Never** — write `Email send policy: never` into
    `memory.md`, abort.

If 5R.1 found a working MTA, skip 5R.3 entirely.

**5R.3 Consent gate B — install a new MTA.** Only reached
when 5R.1 found nothing. Check `memory.md` for `MTA install
policy: <always|never>`:

- `always` → install silently using the OS-family default
  below.
- `never` → refuse; do not install, do not send.
- missing → ask:
  > "No MTA found on `<host>`. Install one?"
  - **Once** — install this time, ask again next time.
  - **Always** — write `MTA install policy: always` into
    `memory.md`, install.
  - **Never** — write `MTA install policy: never` into
    `memory.md`, abort.

Before any install — whichever answer allowed it — run the
mandatory service class conflict check from
`rules/service-class-check.md`. An MTA is a service class:
the check can find a member the 5R.1 transport probe missed
(e.g. an installed-but-stopped postfix), and a second MTA
must never be added without explicit user approval.

**What to install — the requirement before the package.**
This host will send unattended mail: cron output,
unattended-upgrades, hostwarden's own reports. None of those
senders retries. So whatever receives the mail has to hold it
and retry itself, or a relay that is down for a minute loses
the message with nobody to notice.

**msmtp does not queue.** It connects when called and exits
non-zero when the relay does not answer; the mail is gone. It
is the right choice for a container or a host that is
recreated rather than repaired, and the wrong one for a
server that is expected to report about itself. Install it
only when the user asks for it, or on such a host — and say
what it costs when you do.

So: **a spooling agent first.** Check what the host's package
manager actually offers before choosing — availability
differs by distribution and release, and a name that works on
Debian may need an extra repository elsewhere, which is a
bigger change than the mail is worth
(`rules/best-practices.md`):

1. `nullmailer` — relay-only by design, a spool with
   exponential backoff and a `failed` queue. The smallest
   thing that satisfies the requirement.
2. `dma` — same shape, where nullmailer is not packaged.
3. `postfix` as a null client — heavier, but in the base
   repository nearly everywhere, so it is often the one that
   needs no third-party repo at all.

Pair it with a `mail(1)`: `bsd-mailx` on Debian/Ubuntu,
`s-nail` on RHEL and SUSE, base on FreeBSD.

Tell the user which one you picked and why that one, in a
line — "nullmailer, because apt has it and the queue means a
relay outage does not drop a report".

macOS as a managed target: do **not** install. Use the
`/usr/sbin/sendmail` shim of a working, configured Postfix;
otherwise refuse cleanly and explain (residential macOS
rarely sends).

Before installing, surface the deliverability caveat: the
server's IP probably has no PTR/SPF/DKIM, so mail to
gmail-style providers will likely be filtered. Recommend a
smarthost relay if the user has one — every agent above
takes one (`/etc/nullmailer/remotes`,
`/etc/dma/auth.conf`, postfix's `relayhost`,
`/etc/msmtprc`). If a smarthost is configured during
install, follow `rules/backups.md` and back up that file
before editing it, and store the credentials `0600
root:root`.

**5R.4 Pick the sender identity — least privilege.** Sending
mail almost never needs root. Choose the UID for the send,
in this order:

1. Current SSH user is non-root → use that user.
2. Current SSH user is root (common on hosts that allow only
   root SSH with no usable sudo, or after privileged earlier
   work in the session):
   - First check `memory.md` for an `Email sender:` line —
     if present, use it without re-probing.
   - Otherwise read `memory/user.md` for the preferred
     username.
   - `id <user>` to verify the account exists on the host.
   - `su - <user> -c 'command -v <transport>'` to verify the
     account can invoke the chosen transport. If group perms
     on its credentials file block it, fall to case 3.
   - Drop privileges for the send only:
     `runuser -u <user> -- sh -c '…'` (Linux util-linux) or
     `su - <user> -c '…'` (portable, FreeBSD).
3. If no non-root sender is viable, send as root and tag the
   report **WARN** with the reason. Never invent a user.

Then continue at the shared step **6 (Compose)**.
