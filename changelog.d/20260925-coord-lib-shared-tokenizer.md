### Fixed

- **The coordination guard reads a wrapped or quoted remote command
  correctly.** Its reboot, firewall, network and restart
  classification now unwraps `sudo`/`doas`, `ssh`'s own
  multi-argument remote command, and a `bash -c`/`sh -c`/`env -c`
  wrapper before judging it, and reports every unit a compound
  command restarts instead of only the last one a single match
  kept.
