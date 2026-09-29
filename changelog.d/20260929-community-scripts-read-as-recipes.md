### Added

- **Community scripts are read as recipes on Proxmox VE and Incus.**
  Before installing a service on such a host or in one of its guests,
  and before creating a guest for one, Hostwarden looks the
  application up at community-scripts.org and offers to read its
  script: dependencies, source, paths, ports and container defaults
  come from there, while versions, firewall, login and the guest
  itself follow Hostwarden's own rules. It never runs a script or a
  guest's `update` command, and says why when asked to. The guest
  inventory marks a guest a script built, which gets a
  `Community script:` line in memory.
