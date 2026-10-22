### Fixed

- **A NetBSD, OpenBSD, DragonFly, illumos or AIX host is no longer
  refused as a menu.** The first-call gate stopped on any first line
  other than Linux, FreeBSD or Darwin, so a real Unix shell was treated
  like a banner. Such a host now gets its own outcome: Hostwarden says it
  has no OS file for it, reads with generic POSIX commands, and
  asks before changing anything. A menu or banner is still refused.
