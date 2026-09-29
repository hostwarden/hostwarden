### Added

- **Password logins for hosts that take no SSH key.** You store the
  password yourself with `bin/hostwarden-password set`, in the macOS
  keychain or an encrypted file, or link a 1Password, Bitwarden or
  Vaultwarden entry through an identity that sees nothing else; ssh gets it from
  `bin/hostwarden-askpass`, and the session never sees it. Each login
  of each host has its own line in `memory/user.md`. A host whose SSH
  server offers key logins gets no password: Hostwarden asks it and
  refuses.
- **DrayTek Vigor routers on DrayOS 3.x and 4.x.** Hostwarden logs in
  by password, reads their command line for housekeeping and the
  security audit, checks the firmware against DrayTek's advisories,
  and changes nothing without an explicit request.
