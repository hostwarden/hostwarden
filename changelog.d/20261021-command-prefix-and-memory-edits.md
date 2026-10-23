### Fixed

- **An alias or function no longer changes a command the session
  relies on.** In a shell that may have read the user's profile —
  the workstation, local mode, a plain `ssh host 'cmd'`, `bash -lc`
  — sessions write `command <tool>` (`\<tool>` in csh) for every
  command whose output or effect they use, and `command sudo` where
  a `sudo` alias expands the next word. `rm -i` without a terminal
  keeps the file and exits 0, the case that shows it. Calls inside
  `sh -s`, scripts and behind `xargs` need none; the limits are in
  `rules/shell-aliases.md`.

### Changed

- **Memory files and the changelog are edited with the file-edit
  tool.** An in-place `sed` or an interpreter heredoc that names
  `sshd_config` or a key path is denied by the guard; the edit tool
  is judged by the file it writes.
