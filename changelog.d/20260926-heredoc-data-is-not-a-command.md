### Fixed

- **A heredoc a remote command only stores is no longer read as
  commands.** `ssh host 'cat > /tmp/notes' <<EOS`, a remote script
  file, or `ssh -n` with a body line such as `reboot` made the impact
  hook demand an announcement for a reboot nothing runs; such a body
  is now left out, while one any other command may run, or with a
  `$(…)` the shell expands, still counts.
- **Text piped into an ssh that never reads it is no longer checked
  as commands.** With `ssh -n` or `-f`, or with the ssh's stdin
  redirected, a `printf` or `echo` piped into it counted as that
  host's commands, though the pipe never reaches the far shell.
