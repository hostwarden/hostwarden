### Added

- **Choose a personal local SSH agent for SSH and Git signatures.** A socket
  selection in unsynchronized `memory/user.md` overrides inherited agents;
  automatic selection respects SSH configuration and reports unavailable agents.
  Workspace Git signatures use the selected socket without changing the agent
  used to authenticate a fetch, including with custom signing programs.
  OpenPGP, X.509 and unsigned Git operations retain their existing setup.
  Interactive workspace setup offers optional signing configuration once,
  detecting existing signatures and preserving them when setup is deferred.
