### Fixed

- **A CoreOS or Flatcar guest on DHCP had no way to be reached
  after creation.** `hostwarden-new-guest` bridges a new guest's
  settled name to its actual address before the first login, read
  through an exec channel or a guest agent for every other path —
  but neither Fedora CoreOS nor Flatcar ships one, and Ignition's
  own fixed wait reads nothing either. `references/ignition.md`
  now asks the user for the address instead, the same fallback
  already used for a hypervisor whose UI creates the guest, and
  checks it — against memory, and against the guest's own MAC
  where one is known — before trusting a login against it, since
  every admin guest can share one key and a login succeeding
  proves only that the address accepts it, not which machine
  answered.
- **Creating a Fedora CoreOS or Flatcar VM on Proxmox VE waited up
  to 570 seconds for a guest agent that never answers.** Neither
  image ships one, so `references/proxmox.md` now skips straight
  to Ignition's own two-minute wait instead.
