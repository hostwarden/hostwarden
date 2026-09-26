### Fixed

- **`hostwarden-migrate --help` printed nothing and ran the
  migration anyway.** It now prints its usage and exits without
  migrating, matching every other script in `bin/`; an unknown
  argument does the same and exits with an error.
