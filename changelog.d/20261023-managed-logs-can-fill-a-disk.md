### Changed

- **A log under logrotate or journald is still checked when a disk
  is full.** The agent reads the rotation policy and the measured
  usage before ruling the log out, since time-based rotation caps
  nothing between runs and a retention limit can exceed the disk.
