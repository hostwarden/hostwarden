### Changed

- **A server lock with a `false` line anywhere locks the host.** A
  file holding both `allow_changes = false` and `allow_changes = true`
  was read as unlocked; any line that is not `true` now locks. The
  taboo guard also refuses `touch` on the lock file.
