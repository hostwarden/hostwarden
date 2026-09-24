### Added

- **Markdown rewraps itself at 80 characters.** `bin/hostwarden-wrap`
  rewraps the paragraphs of a Markdown file and leaves headings,
  tables, code and a file marked as generated on its first line
  alone. In Claude Code it runs after every edit and shell command,
  in operations on `memory/` only, and `bin/hostwarden-sync commit`
  rewraps what it commits, whichever tool wrote it.
