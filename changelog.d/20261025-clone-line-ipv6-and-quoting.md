### Fixed

- **The workspace README's clone line works for an IPv6-hosted mirror
  and for a path with a space.** A Hostwarden copy reached by an IPv6
  address is printed in brackets, as git needs it, and an address
  with a space or a shell metacharacter is quoted so the command
  pastes as written. Plain addresses print as before.
