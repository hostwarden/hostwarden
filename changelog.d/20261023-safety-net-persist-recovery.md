### Fixed

- **A runtime-only change that fails to persist has a way back.** When
  the undo only reverses the runtime, as firewalld's reload and a
  sysctl do, the cancel comes before the permanent write. The pending
  write is now noted in the host's to-do first, and a failed write or
  read-back is resolved by restoring the files from the backup and
  making the runtime match, or by correcting the file and persisting
  again, not by leaving runtime and files apart.
