### Added

- **Hostwarden can log in with an SSH key of its own.** Asked once,
  never required: the key lives in Hostwarden's own agent, your
  password manager's agent or a hardware key, and every host's log
  then names its logins. You add the line `bin/hostwarden-identity
  line` prints to each host; once a fresh login with it has worked,
  Hostwarden offers that key there instead of your agent's, and the
  doctor, the guard and the security and fleet audits check it.
