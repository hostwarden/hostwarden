### Changed

- **The background session is now called presence.** Hostwarden used
  "coordinator" for it and for the session that drives several pull
  requests; the background one keeps no assignments and reaches no
  server, so it takes the word the code already uses for its map. The
  skill is `/hostwarden-presence`, the session `hostwarden presence`,
  and the opt-out line `Presence: off` in `memory/user.md`. A
  `Coordinator: off` line is no longer read: change it to
  `Presence: off`, and stop a running old session once with
  `claude stop` before updating.
  An override file `memory/custom-rules/hostwarden-coordinator.md` is
  read under the skill's new name: rename it to
  `hostwarden-presence.md`.
