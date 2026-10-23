### Added

- **The baseline expects needrestart on Debian and Ubuntu, in list
  mode.** A new guest gets the package and a drop-in that sets
  `$nrconf{restart} = 'l'`; housekeeping reports a host without
  needrestart, or without an explicit mode, as INFO, and
  `hostwarden-baseline` offers to install and set it. Automatic
  security updates then leave the services that still run the old
  library visible instead of unseen. On Ubuntu 24.04 and later the
  drop-in also stops unattended-upgrades from restarting services in
  the night, which needrestart does there by default; a decision for
  the host, or an override that replaces the Service Restarts
  section, keeps `a`.
