### Fixed

- **A new guest could end up permanently registered under its
  address instead of its settled name.** The first login after
  creation always uses the guest's actual address, since DNS for a
  brand-new name often is not live yet, so the memory directory the
  first connection created carried that address, and the host's
  `guests.md` linked to it that way for good. `hostwarden-new-guest`
  now reconciles the memory directory, `memory/ssh_hosts`, and
  `memory/known_hosts` to the settled name before registering the
  guest.
