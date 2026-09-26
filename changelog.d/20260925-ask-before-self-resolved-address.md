### Fixed

- **A self-resolved address could silently redirect a shared
  workspace's other workstations.** Renaming a host with no DNS of
  its own, and an mDNS name conflict, both wrote an address one
  workstation resolved straight into the shared `memory/ssh_hosts`
  file; a different workstation reaching the same infrastructure by
  a different route, an mDNS answer above all, could not
  necessarily reach it the same way. Hostwarden now asks, in a
  shared workspace and only for an address it determined itself,
  whether every workstation reaches it the same way before writing
  it there. A caller whose own remaining steps in the same run
  depend on the name resolving — creating a new guest, above all —
  keeps working on a decline: it reaches the address directly for
  the rest of that run instead of writing it anywhere.
