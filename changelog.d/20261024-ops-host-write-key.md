### Added

- **A session on the operations host can change hosts while you
  unlock a write key there.** Hostwarden's own key, in an encrypted
  file you load for a time you name, or certified by your CA for a
  few hours; once it is gone and its connections are closed, the
  machine is read-only again.

### Changed

- **The nightly fleet run never uses an agent or a session's
  connections.** Its ssh calls pass no agent and use connection
  sockets of their own, so a write key unlocked on the operations
  host stays out of the timer's reach.
