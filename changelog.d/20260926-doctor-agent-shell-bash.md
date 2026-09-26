### Added

- **`bin/hostwarden-doctor` reports when Claude Code runs commands in
  zsh or an old Bash.** Agents write their commands for Bash; under
  macOS's zsh they fail and get written again. The doctor names the
  Bash 4 or newer to set as `CLAUDE_CODE_SHELL`, or how to install
  one, and the Claude Code page in the documentation shows the
  setting.
- **A shell script written for a host is POSIX `sh` unless it needs
  Bash.** Where it does, its shebang is `#!/usr/bin/env bash` for one
  a person starts, and an absolute path for one cron, launchd,
  systemd, root or a session over SSH starts, on a Mac the Homebrew
  Bash rather than macOS's 3.2. A script root runs gets only a Bash
  that root owns and nobody else can replace, else stays POSIX `sh`.
