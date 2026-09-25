### Fixed

- **A CoreOS or Flatcar guest on DHCP had no way to be reached
  after creation.** `hostwarden-new-guest` bridges a new guest's
  settled name to its actual address before the first login, read
  through an exec channel or a guest agent for every other path —
  but neither Fedora CoreOS nor Flatcar ships one, and Ignition's
  own fixed wait reads nothing either. `references/ignition.md`
  now asks the user for a DHCP guest's address instead, the same
  fallback already used for a hypervisor whose UI creates the
  guest.
