### Fixed

- **The auto-mode block goes where Claude Code reads it.** The rule
  told you to put `autoMode` in the project's `.claude/settings.json`,
  which Claude Code ignores, so writes over SSH stayed blocked. It now
  names `~/.claude/settings.json`, lists your servers as trusted
  hosts, and points to `/auto-mode-setup` with three checks for its
  draft. A refusal of any server write, not only a reload, now stops
  the work and names that fix.
