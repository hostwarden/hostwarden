### Fixed

- **The coordination guard reads a wrapped or quoted remote command
  correctly.** Its destination, reboot, firewall, network and
  restart reading now all unwrap a leading `sudo`/`doas` (short or
  long option, attached or separate value), `ssh`'s own
  multi-argument remote command, a `bash -c`/`sh -c`/`env -c`/
  `env -S` wrapper, and a heredoc's own body before judging it;
  reports every unit a compound command restarts instead of only
  the last one a single match kept, even a global option before
  the verb; and a leading or trailing `2>&1`-style redirect no
  longer hides what follows it.
