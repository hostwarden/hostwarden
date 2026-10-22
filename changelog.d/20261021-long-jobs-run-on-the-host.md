### Added

- **Long jobs run on the host and are read back.** A package upgrade
  or a big `rsync` used to run inside the SSH call, which the tool's
  time limit or a dropped connection ends while the command runs on,
  and its result was lost. A command that can take more than a minute
  now runs as a `nohup` job under `~/.hostwarden-jobs/<id>`, output
  and exit status in files, and one later call reads it back; a job
  not seen to start within five seconds fails the start call. The
  job is registered with the host's other sessions, recorded in the
  host's `todo.md`, stopped by process group and cleaned after seven
  days, and an interrupted command is looked up before it is repeated
  (`rules/ssh-connections.md` → Long jobs,
  `rules/verify-before-reporting.md` → A command without a
  result ran, or it did not).
