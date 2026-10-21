### Changed

- **A host the session is creating is not announced.** A new
  guest's first boot, reboot from inside and the firewall and services set up
  on it have an empty blast radius, so
  `rules/coordination.md` now says there is nothing to announce and
  nobody to inform; the trigger lines in `AGENTS.md`,
  `rules/service-reload.md`, `rules/ssh-safety-net.md` and the
  `hostwarden-new-guest` skill point there. In `rules/coordination.md`, a
  message to sessions is an "announcement", apart from the `Downtime notice:`
  to customers and IT.
