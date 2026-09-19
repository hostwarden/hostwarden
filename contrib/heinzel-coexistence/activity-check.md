# Custom Rules — Activity Check

Override for `rules/activity-check.md` while
hostwarden works on the same hosts.

## Add: Read hostwarden's journal tag too

Work done by hostwarden is invisible to a check that
asks for `heinzel` alone, and that is how two
sessions end up surprising each other. Widen the
commands in "How to check" — everything else in that
section still applies, including the journal
visibility warnings and "an empty result only counts
when the command succeeded":

- systemd: add `-t hostwarden` to the `journalctl`
  call, and to the `sudo -n journalctl` fallback —
  `-t` may be given more than once.
- macOS and FreeBSD: grep for
  `-E "heinzel|hostwarden"` instead of `heinzel`.

## Add: A fresh hostwarden entry means a live session

An entry tagged `hostwarden` from the last 15 minutes
means a hostwarden session is probably working on
this host right now.

Say so before making any change, and let the user
decide whether to go ahead, wait, or switch tools for
this task. Read-only work needs no such pause.

## Add: Name the tool in the summary

When entries from both tags appear, say which tool
did what. "Installed nginx" reads differently when
the user knows it was the other session, and it is
the fastest way to spot that both tools are working
on the same thing.
