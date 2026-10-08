### Changed

- **The access-control page says which of its protections to pick
  for which need.** Fleet read is the one the host enforces, so
  unattended runs take it; the read-only list and the protected
  paths are rules the agent follows, for an interactive session on
  a writable host, a diagnosis with commands of its own included;
  and a hard guarantee for one path
  exists only on the host itself — an SSH user without write
  permission plus narrow sudo rules, `chattr +i`, a read-only ZFS
  or Btrfs dataset. The scheduled-housekeeping page points there.
