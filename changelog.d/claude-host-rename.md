### Added

- **Renaming a host.** On request, one host at a time, Hostwarden
  lists what the old name reaches, sets the new hostname and
  `/etc/hosts`, moves the host's memory to the new name with the old
  one kept as an alias, and hands over what is yours: DNS, a Proxmox
  VE cluster node, appliances, directory-joined hosts and
  memberships keyed by the node name.
- **Every family file names its hostname command.** Debian, RHEL,
  SUSE, Alpine, FreeBSD and macOS each say how the hostname is set
  for the running system and the next boot, and XCP-ng uses its own
  `xe` command in place of `hostnamectl`.
