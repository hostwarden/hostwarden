# Sending and verifying

Steps 7 and 8 of the `hostwarden-email` skill, after
`references/compose.md` has produced subject, body and any
attachments.

7. **Send.** Because Hostwarden always injects custom headers
   (the anti-auto-reply triple `references/compose.md` sets,
   plus MIME headers
   when attaching), the canonical send path builds the
   full RFC 822 message and pipes it to a sendmail-style
   agent that reads headers from stdin (`-t` mode). This
   is uniform across Postfix, msmtp-mta, exim, opensmtpd,
   and macOS Postfix — they all expose `/usr/sbin/sendmail`
   with compatible `-t` semantics.

   The composed message always has this shape (headers,
   blank line, body + greeting + signature):

   ```
   From: noreply@<sending-host-fqdn>
   Reply-To: <operator email>
   To: <recipient>
   Subject: <subject>
   Auto-Submitted: auto-generated
   Precedence: bulk
   X-Auto-Response-Suppress: OOF, AutoReply
   MIME-Version: 1.0
   Content-Type: text/plain; charset=utf-8

   <body>

   <greeting>

   -- 
   <signature>
   ```

   `From:` and `Reply-To:` are resolved by
   `references/compose.md` — step 6 ran before this one
   and its last case leaves `Reply-To:` unresolved. When
   it did, omit the line entirely after warning the user.

   **No attachments.** Pipe the message to
   `sendmail -t -oi` (`-oi` prevents a lone `.` on a line
   from ending input). Prefer the MTA-provided
   `/usr/sbin/sendmail`; fall back to `msmtp -t` when only
   msmtp is present.

   **With attachments**, build a MIME multipart message by
   hand — `text/plain` body plus parts that are
   `text/plain` for `text/*` MIME types (detected via
   `file --mime-type`) and base64-encoded
   `application/octet-stream` otherwise. Hostwarden
   constructs the headers (including the anti-auto-reply
   triple) and the boundary itself, then pipes into
   `sendmail -t -oi` (or `msmtp -t` when only msmtp is
   present). One code path for every MTA, which is what
   makes the headers survive: a tool-specific shell-out to
   `mutt` or `mail -a` drops them.

   **macOS local path.** `/usr/sbin/sendmail` on macOS is a
   Postfix compatibility shim and accepts the same `-t`
   invocation, so the same composed message pipes through
   without change.

   Remote path: run under the user chosen in 5R.4, via
   `runuser -u <user> -- sh -c '…'` or
   `su - <user> -c '…'`. Local path: under the current
   shell user.

8. **Verify delivery.** Check the send command's exit code,
   then probe the appropriate mail log from the last minute:
   - Linux remote: `journalctl -u postfix --since "1 minute
     ago" | tail -20` (substitute the active MTA unit), or
     `tail -50 /var/log/mail.log` (Debian) /
     `/var/log/maillog` (RHEL/FreeBSD).
   - macOS local: `log show --style compact --last 1m
     --predicate 'process == "smtpd" OR process == "smtp"'`.
   - Linux workstation local: `journalctl --since "1 minute
     ago" -t postfix` or `/var/log/mail.log`.

   Look for `status=sent` (or msmtp's `delivery
   successful`). Flag `deferred` / `bounced` as **CRITICAL**
   and report verbatim instead of claiming success. Never
   call a send successful on the basis of the command's exit
   code alone.

   On the remote path, confirm the log line's `from=<…>`
   matches the chosen sender user (not root, unless 5R.4
   fell to case 3). This is the *envelope* sender (the
   Return-Path), which always reflects the submitter UID;
   the visible `From:` header is `noreply@…` and is
   independent — do not flag the mismatch as a problem.
