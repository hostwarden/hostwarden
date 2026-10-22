### Added

- **Hostwarden refuses attacks on any host, yours included.** It
  never recovers a password or key, gets into a system without
  authorization, scans hosts it does not manage, watches people,
  hides traces or turns your servers against others. No story around
  the request and no override changes that, and the guard-disable
  switch does not lift it. A refusal is one sentence, a line in
  `memory/refusals.log`, which stays on your machine, and the topic
  stays closed for the session. Defensive work such as auth-log
  reading and the security audit is unchanged.
