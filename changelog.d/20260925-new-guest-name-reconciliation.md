### Fixed

- **A new guest could end up permanently registered under its
  address instead of its settled name.** The first login after
  creation always uses the guest's actual address, since DNS for a
  brand-new name often is not live yet, so the memory directory the
  first connection created carried that address, and the host's
  `guests.md` linked to it that way for good.
  `hostwarden-new-guest` now checks the settled name against DNS
  before creating the guest, and again before the first login, and
  bridges it to the guest's address in `memory/ssh_hosts` in
  between, so the guest is reached, keyed and registered by its
  settled name from the start. It closes that bridge only once the
  settled name resolves to the guest's address and nothing else.
