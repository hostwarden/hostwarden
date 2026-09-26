---
sidebar_position: 5
description: Runs commands directly on the machine Hostwarden runs
  on, without SSH.
---

# Local administration

Hostwarden also works on the machine it runs on — a Linux, macOS
or FreeBSD workstation, or the WSL instance on Windows — with no
SSH.

```
 ❯ Update all Homebrew packages on this Mac
```

```
 ❯ Check if the firewall is configured on
   this machine
```

Commands run directly, as your own user, with sudo where it is
needed and unprivileged mode where it is not available. The steps
that only make sense for a remote host — access lists, SSH user,
DNS and host key — are skipped; OS detection, memory, the activity
check and the rest of the safety rules apply. A development
checkout has no local mode.
