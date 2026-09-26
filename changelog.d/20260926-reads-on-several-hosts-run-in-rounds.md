### Changed

- **Work on several hosts runs from the session, every host at
  once.** A question, a change or the fleet audit reaches all hosts
  in one call per round, so a follow-up builds on the last answer,
  and no subagent starts per host. Housekeeping or a security audit
  on more than four hosts still runs in subagents of up to four.
  `Multi-host: agents` in `memory/user.md` sends questions and
  skills to subagents.

### Added

- **`bin/hostwarden-group` prints what several hosts returned, each
  answer once.** The hosts that gave the same answer share one
  block, section by section, so a fleet that agrees reads in a few
  lines.
