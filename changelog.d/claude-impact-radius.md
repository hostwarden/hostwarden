### Added

- **Ask what a reboot, restart or network change would hit.**
  Hostwarden answers from memory without connecting anywhere: the
  host's guests, the hosts behind it as a jump host, the hosts that
  depend on a service it runs, and its cluster peers, each with its
  role and services, and how old the records are it relied on.
  Onboarding and housekeeping record the NFS or SMB shares a host
  mounts and the resolver it uses as a new `Depends on:` line.

### Changed

- **Several hosts behind one jump host are grouped by a script.**
  Before a task on several hosts, `bin/hostwarden-impact` reads each
  host's way in and puts the hosts that share a jump host in one
  sequence, with the same parser the fleet run's blacklist check
  uses.
