### Added

- **A reboot, a firewall or network change, or a restart is
  announced before it runs.** `bin/hostwarden-impact announce`
  computes what the step would reach and checks a local presence
  map for another session already on one of those hosts; `wait`
  blocks briefly for it to say it is safe, and `ack` and `done`
  close the loop. Two new hooks carry the mechanical half:
  `presence.sh` keeps the map from what sessions actually do, and
  `impact.sh` denies a disruptive step with another live session on
  its radius until it has been announced, and refuses once — never
  paused — a command a running impact's radius already covers.
  `hostwarden-impact status` answers "why is SSH not responding?"
  from that map alone, with no connection made, and
  `rules/ssh-unreachable.md` checks it before anything else.
