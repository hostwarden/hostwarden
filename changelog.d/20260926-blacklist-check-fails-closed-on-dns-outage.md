### Security

- **A DNS outage could not be told apart from a clean blacklist or
  read-only-list miss.** `hostwarden-impact`'s
  team-telling and `hostwarden-fleet-run`'s unattended fleet read
  both check the server blacklist and, for `hostwarden-impact`, the
  read-only list, by resolving names and addresses; a resolver that
  could not be reached returned the same empty result as a name
  that genuinely resolves to nothing, so an outage during the check
  was silently treated as safe to proceed. The shared resolver
  behind both now tells the two apart the way DNS alias detection
  already does, and an unresolvable result is treated as a match:
  `hostwarden-fleet-run` skips the host, and `hostwarden-impact`
  refuses the blacklist call and defaults an unresolvable read-only
  list to read-only, rather than connecting or registering a write
  it could not actually clear.
