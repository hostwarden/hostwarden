### Added

- **A development session knows where your operations clone is.**
  Record its path once in `~/.config/hostwarden/operations-checkout`
  and every development checkout on the machine names it at session
  start and in each refusal, instead of asking in every session. The
  agent offers to write the file after it has asked. Where a tool
  can offer a session that starts in the operations checkout itself
  on one click, the agent offers that before the terminal command.
