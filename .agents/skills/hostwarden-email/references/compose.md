# Composing the message

Step 6 of the `hostwarden-email` skill. Both the local and
the remote path converge here.

6. **Compose.**
   - Default subject: `[hostwarden/<short-hostname>] <topic>` —
     even on the local-side path, the subject names the
     server the report is *about*.
   - Body: plain text, in this order and nothing else — one
     line naming what ran and on which host, the report or the
     user's content verbatim, then the Hostwarden closing (see
     **Greeting** and **Signature** below). If the user asks to
     send command output, run the command and embed
     stdout/stderr inline in a fenced block in place of the
     report.
   - **Ceiling: 5 lines of your own text** around that block,
     per "Talking to Humans" in `AGENTS.md`. No cover sentence,
     no restatement of the subject, no "as requested", no recap
     under the report. A report goes in exactly as its skill
     produced it — nothing added before or after it.
     Attachments get one line each: name and size, not a
     description of the contents.

   **Attachments** (e.g. "email me /var/log/auth.log"):

   a. Per file, `stat` the path on the side that holds it
      (remote when the path lives on the server; local
      otherwise). Refuse if it doesn't exist; never invent
      paths.
   b. **Readability check.** Confirm the chosen sender UID
      (5R.4 result on the remote path, current shell user on
      the local path) can read it: `[ -r path ]` under that
      UID. If not, do not silently escalate. Show the perms
      (`ls -l`) and ask:
      - skip the file (default offered);
      - copy via root to a temp file `0600 <sender>:<sender>`
        the sender can read, then clean up after send;
      - send as root with a **WARN**.
   c. **Size check.** If the file is over 10 MB, show the
      size and Gmail's 25 MB cap, then ask: send as-is, gzip
      first (recommended for text logs), or skip.
   d. **Sensitive-content nudge.** Log files often contain
      secrets, IPs, hostnames, internal email addresses.
      Show the file's `head -5` and ask "ok to attach?"
      before proceeding. The user can override globally for
      the session by saying "skip the log preview" — do not
      persist that override to memory.

      **Likely-secret files are default-refuse.** For
      `.env`, `id_*`, `*_key`, `*.pem` with private key
      material, `shadow`, `msmtprc`, `.netrc`, cloud
      credential files, or anything under
      `/etc/ssl/private/`: warn explicitly and attach only
      on an explicit per-file override. Never show their
      content as a preview — the preview itself would leak.
      Preview with `ls -l` + `file` instead. See
      `rules/secrets.md`. The session-wide "skip the log
      preview" override does NOT apply to these files.
   e. Multiple attachments: repeat a–d per file. Hard cap of
      5 attachments per message in v1; refuse the 6th and
      suggest splitting the mail.

   **Voice.** Hostwarden, not the operator, is the apparent
   author of every outgoing message. Body text — including
   any casual sign-off the user asks for above the fixed
   greeting — must speak in Hostwarden's voice on the
   operator's behalf. If a closing line precedes the
   greeting (e.g. "Have a good week,"), attribute it to
   Hostwarden acting for the operator, like:

   ```
   Have a good week,
   Hostwarden (for <Operator name>)
   ```

   Never write `<Operator> (via hostwarden)`, `<Operator> via
   hostwarden`, or any phrasing that frames the operator as
   the author with Hostwarden as a delivery channel. The
   persona is **"Hostwarden for `<Operator>`"**, not
   "`<Operator>` via Hostwarden". Same applies to the subject
   and any inline narration.

   **Greeting.** Before the signature, every outgoing
   message carries a fixed two-line human close, separated
   from the body above by one blank line and from the
   signature below by another blank line:

   ```
   Viele Grüße
   Hostwarden
   ```

   Hostwarden is the author of the closing — not the operator.
   The operator attribution lives in the signature block
   below. Keep the greeting fixed across languages; the
   subject and body may be English, the "Viele Grüße /
   Hostwarden" close stays the tool's voice. Users who want a
   different wording can set a `Greeting:` line in
   `memory/user.md` (global) or
   `memory/servers/<host>/memory.md` (per-host); if present,
   it replaces both lines verbatim (multi-line allowed).
   Per-send instructions ("use 'Mit freundlichen Grüßen'
   this time") always win over memory.

   **Signature.** Every outgoing message ends with a fixed
   three-line signature block, separated from the greeting
   above by one blank line and opened by the RFC 3676
   delimiter `"-- "` (two hyphens, one space, then newline
   — most MUAs collapse the sig visually only when the
   delimiter is exact):

   ```
   -- 
   Sent by Hostwarden on behalf of <Operator name>
   https://github.com/jpawlowski/hostwarden
   ```

   Keep it to these three lines. No timestamp, no hostname,
   no extra attribution — the subject already names the
   host. Plain text only; no HTML.

   **Resolve `<Operator name>`** in this order, stop at the
   first hit. Never fabricate a name from a short handle
   like `root`, `admin` or the `Operator:` line:

   1. `Operator name:` line in
      `memory/servers/<host>/memory.md` (per-host override,
      rare).
   2. `Operator name:` line in `memory/user.md` (global,
      canonical).
   3. Claude Code auto-memory — the `user_profile.md` file
      referenced from `MEMORY.md`. Take the human name from
      its front-matter `name:` field (strip any suffix like
      ` — user profile`). This is the same auto-memory
      channel step 3 uses for the default email.
   4. `git config --global user.name` on the workstation.
   5. GECOS full name:
      `getent passwd "$USER" | cut -d: -f5 | cut -d, -f1`
      on Linux, `id -F` on macOS/BSD.
   6. `$USER` as a last resort.
   7. If even `$USER` is empty, ask once via the picker and
      persist the answer.

   **Persist on first resolution via 3/4/5/6** — write
   `Operator name: <name>` into `memory/user.md` under the
   existing `# Preferences` section so the next run skips
   the probes and the user can edit the canonical value.
   Do not overwrite an `Operator name:` line that already
   exists; user edits win.

   **From header.** Hostwarden mail is machine-generated. Set
   `From: noreply@<sending-host-fqdn>` so recipients see at
   a glance that the mailbox is not monitored:

   - Remote path: `<sending-host-fqdn>` is the `- FQDN:`
     line of the server's `memory.md`; where that holds no
     name (missing, `none`, `unknown`), the directory name
     under `memory/servers/<host>/`.
   - Local path: `<sending-host-fqdn>` is the workstation's
     FQDN (`hostname -f`, fall back to `hostname`).

   The `noreply@…` mailbox does **not** need to exist on the
   host. Real bounces follow the *envelope* sender (the
   submitter UID picked in 5R.4, or the current shell user
   on the local path) — that is always a real account that
   can receive MAILER-DAEMON notices. The From header is
   purely visual, for the recipient's MUA.

   A host can pin a different From mailbox by adding a
   `From:` line to its `memory.md` (rare — only useful when
   a host needs a non-`noreply@` identity such as
   `alerts@<host>`).

   **Reply-To header.** Because the From mailbox is unread,
   every Hostwarden message MUST carry a `Reply-To:` pointing
   at the human operator, so recipients hitting "Reply"
   land in a real inbox.

   The operator email is the address of the human
   *using* Hostwarden — the same person logged into Claude
   Code right now. It is **never** an account on the
   managed server: no `root@<host>`, no
   `<ssh-user>@<host>`, no alias derived from `/etc/aliases`
   or `~/.forward` on the target. Do not probe
   `getent passwd`, `id`, or any mail metadata on the
   managed host to resolve it. Replies must land in the
   operator's real inbox, not on the server they were
   asking Hostwarden to work on.

   **Resolve `<operator email>`** in this order, stop at
   the first hit. Never fabricate an email from a short
   handle like `root` or `admin`, and never derive it
   from a managed host:

   1. `Reply-To:` line in
      `memory/servers/<host>/memory.md` (per-host
      override, rare — e.g. a different operator fields
      replies for one specific host; still must be a
      real off-server inbox).
   2. `Reply-To:` line in `memory/user.md` (global,
      canonical).
   3. Claude Code auto-memory — the "Default email"
      entry under User in `MEMORY.md`. Load the linked
      file and use the address. Same channel step 3 of
      "Resolve recipient" uses.
   4. `git config --global user.email` on the
      workstation.
   5. If still nothing, omit the Reply-To header, tag
      the report **WARN** with the reason, and tell the
      user before sending — don't ship a Hostwarden mail
      with no working reply path silently.

   **Persist on first resolution via 3/4** — write
   `Reply-To: <addr>` into `memory/user.md` under the
   `# Preferences` section so the next run skips the
   probes and the user can edit the canonical value.
   Do not overwrite an existing `Reply-To:` line.

   **Anti-auto-reply headers.** Every Hostwarden email is an
   automated status message about a managed server. It
   should never fan out out-of-office or vacation replies
   back at the operator. To that end, every outgoing
   message carries this fixed header triple, regardless of
   path or attachments:

   ```
   Auto-Submitted: auto-generated
   Precedence: bulk
   X-Auto-Response-Suppress: OOF, AutoReply
   ```

   - `Auto-Submitted: auto-generated` is the RFC 3834
     signal. Standards-compliant auto-responders
     (vacation(1), Sieve `vacation`, recent postfix,
     well-behaved providers) MUST NOT reply to a message
     that carries it.
   - `Precedence: bulk` is the older sendmail convention,
     still honoured by many legacy responders.
   - `X-Auto-Response-Suppress: OOF, AutoReply` is the
     Microsoft Exchange / Outlook-specific knob that
     suppresses OOF replies and "I'm out of the office"
     auto-responses when the recipient uses Exchange.

   Together the three cover RFC-compliant systems, legacy
   Unix responders, and the Exchange-flavoured world.
   Do not make them per-host configurable; there is no
   realistic Hostwarden message that should be treated as
   a normal human email by an auto-responder.
