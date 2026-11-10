### Added

- **Arch Linux and its derivatives are a family of their own.**
  CachyOS, EndeavourOS, Manjaro and other `pacman` systems get
  `rules/os/arch.md`: updates as a full system upgrade and never a
  partial one, the pending reboot read from the running against
  the installed kernel, the AUR left to the user, and probes for
  housekeeping, the security audit and the fleet audit.
- **NetBSD is a family of its own.** `rules/os/netbsd.md` covers
  pkgsrc with `pkgin`, `rc.d` services, NPF, `doas`, the base
  system's updates and the safety net through `at`. Housekeeping
  and the security audit run on it and name a check that has no
  NetBSD variant; the fleet audit skips NetBSD hosts and says so.
- **`/hostwarden-macos-cleanup` finds what removed apps left
  behind on a Mac.** It scans `~/Library` and `/Library`, reports
  each leftover with its size and the app it belonged to, and
  moves to the Trash only what you confirm. A second mode
  uninstalls one app together with everything it created. It never
  uses root: what needs an administrator comes back as a command
  block for you to run.
- **A host remembers each login apart.** What holds for one account
  only, its home, groups, sudo rights, runtimes and crontab, is
  kept in `user-<login>.md` beside the host's `memory.md`, created
  with the first such fact.

### Changed

- **The privilege lines move to the login's file.** `Sudo:`,
  `Doas:`, `Privilege mode:` and `Root-equivalent group:` describe
  an account, not a host. A line still in `memory.md` counts for
  the login the host is reached as and moves the next time it is
  written; nothing has to be migrated by hand.
- **A journal line is ASCII and gives its reason after
  `; because`.** A BSD syslogd stores every other byte as an
  escape, so an entry with an umlaut or a dash could not be found
  again. Entries written with the dash before `because` are still
  read.
- **A check reports what it found in its output, not in its exit
  status.** A probe for a file or package that may be missing
  prints a verdict and exits 0, so a non-zero exit means the check
  itself did not run.

### Fixed

- **The pf example for FreeBSD no longer locks out a login through
  a tunnel.** Its SSH rule names no interface; the one written
  before passed SSH on the external interface alone, and a session
  that came in over WireGuard lost its way back the moment the
  rules loaded.
