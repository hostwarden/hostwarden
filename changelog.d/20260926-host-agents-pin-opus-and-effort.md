### Changed

- **The multi-host subagent runs on Opus, whatever the session runs
  on.** `hostwarden-host-task`, which carries housekeeping, security
  audits and, where the user asks for it, questions to groups of
  hosts, runs at medium effort. It inherited the session's model and
  effort before.
