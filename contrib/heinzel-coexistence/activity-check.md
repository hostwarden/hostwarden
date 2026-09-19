# Custom Rules — Activity Check

Override for `rules/activity-check.md` while
hostwarden works on the same hosts.

## Replace: How to check

Read both journal tags. Work done by hostwarden is
invisible to a check that only asks for `heinzel`,
and that is how two sessions end up surprising each
other.

**systemd (Linux):**

```
journalctl -t heinzel -t hostwarden \
  --since "7 days ago" --no-pager -q 2>/dev/null
```

As a non-root user outside the `systemd-journal` /
`adm` groups, `journalctl` silently shows only the
user's own entries. When connected as non-root, try
`sudo -n journalctl -t heinzel -t hostwarden ...`
first. If sudo is unavailable, run the command
without `-q` and watch for the "not seeing messages
from other users" hint. When visibility is limited,
tell the user the activity check may be incomplete —
do not stay silent.

**macOS:**

```
/usr/bin/log show --last 7d \
  --predicate 'process == "logger"' --info 2>&1 \
  | grep -E "heinzel|hostwarden"
```

**FreeBSD:**

```
grep -hE "heinzel|hostwarden" /var/log/messages.0 \
  /var/log/messages 2>/dev/null | tail -20
```

Note: this shows the last 20 matches, not a strict
7-day window, and only reaches one rotation back
(`messages.0`). Older rotated logs are usually
compressed; mention the limitation if relevant.

If the command returns nothing — and it actually ran,
and journal visibility is not limited — skip
silently.

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
