### Changed

- **The per-host subagents run on Opus, whatever the session runs
  on.** The fleet audit's `hostwarden-host-probe` runs at low effort,
  since it only reads a fixed set of checks into one row;
  `hostwarden-host-task`, which carries approved changes, housekeeping
  and security audits to each host, runs at medium effort. Both
  inherited the session's model before, and the task agent its
  effort too.
