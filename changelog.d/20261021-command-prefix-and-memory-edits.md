### Fixed

- **An `rm -i` alias no longer makes a delete look like it worked.**
  Sessions write `command cp`, `command mv` and `command rm` for every
  command that runs on the workstation and in calls a login shell
  reads itself, and `command sudo rm` where a shell reads a `sudo`
  alias that expands the next word. An alias without a terminal keeps
  the file and exits 0 for `rm -i`. Calls inside `sh -s` need no
  prefix, and rules and skill probes that copy, move or delete carry
  it anyway.

### Changed

- **Memory files and the changelog are edited with the file-edit
  tool.** An in-place `sed` or an interpreter heredoc that names
  `sshd_config` or a key path is denied by the guard; the edit tool
  is judged by the file it writes.
