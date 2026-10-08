### Added

- **Choose a personal local SSH agent for SSH and Git signatures.** A socket
  selection in unsynchronized `memory/user.md` overrides inherited agents;
  automatic selection respects SSH configuration and reports unavailable agents.
  An invalid saved choice is reported without keeping the host blocks out of
  `memory/ssh_config`. Workspace Git signatures use the selected socket without
  changing the agent used to authenticate a fetch, including with custom
  signing programs and default-key commands. OpenPGP, X.509 and unsigned Git
  operations retain their existing setup. Interactive workspace setup offers
  optional signing configuration once, detecting existing signatures and
  preserving them when setup is deferred.
