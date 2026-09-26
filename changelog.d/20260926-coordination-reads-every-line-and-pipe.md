### Fixed

- **Coordination sees every line of a multi-line command.** The
  presence and impact hooks read only the first line's host, and
  charged that host with what the later lines did; each line's host
  is now tracked and checked on its own.
- **A reboot piped into the far shell is checked.** A `printf` or
  `echo` piped into `ssh host 'sh -s'` now counts as that host's
  commands, the way a heredoc body already did, so the impact hook
  asks for an announcement before it.
- **The off switch keeps judging the line after a heredoc.** With
  the guard off toward one host, a command on the line after a
  heredoc sent to that host was dropped with it, unjudged; it is
  now judged like any other local command.
