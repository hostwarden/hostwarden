### Added

- **A coordinator keeps track of which session works where.** The
  first session in an operations checkout starts it in the
  background and says so. It asks a session what it is doing when
  it moves to other hosts, passes an announced reboot or restart on
  to the sessions changing something on the hosts it reaches, keeps
  an order of steps across sessions and warns about maintenance
  windows. It reaches no server and decides nothing.
  `/hostwarden-coordinator` stops it and keeps it off through
  `Coordinator: off` in `memory/user.md`, or starts it again.
- **In a team, an announced step is written onto the hosts it
  reaches.** With two or more active people in `operators.md`,
  `hostwarden-impact announce` leaves a register entry and a journal
  line on each of those hosts, so colleagues' sessions on other
  workstations see it and a later connection can tell why a host
  rebooted; `done` removes the entries. Alone, nothing is written
  on other hosts.

### Changed

- **`operators.md` marks a handle inactive or as an operations
  host.** `(inactive since <date>)` is set when you say someone has
  stopped and keeps the handle reserved; a session whose own handle
  is inactive asks first, and the fleet run refuses one.
  `hostwarden-fleet-read` reserves a machine's handle as
  `(operations host)`, which counts toward no team.
- **"Team mode" is now called a shared workspace.** A workspace
  with a remote is shared, whether by a team or by one person on
  several machines; "team" means two or more active people.
