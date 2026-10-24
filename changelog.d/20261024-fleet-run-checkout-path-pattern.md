### Fixed

- **The nightly fleet run works from a checkout whose path holds a
  `%` or a glob character.** Its own ssh configuration included
  `memory/ssh_config` by path, which ssh reads as a pattern; it now
  carries a copy of that file instead.
