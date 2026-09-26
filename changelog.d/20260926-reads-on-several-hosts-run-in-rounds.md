### Changed

- **Work on several hosts starts far fewer subagents.** A question,
  the fleet audit included, runs on all hosts at once from the
  session, one call per round, so a follow-up can build on the last
  answer. Housekeeping or a security audit on more than four hosts
  runs in subagents of four hosts each, and only a larger change
  gets one subagent per host. `Multi-host: agents` in
  `memory/user.md` sends every task to subagents.
