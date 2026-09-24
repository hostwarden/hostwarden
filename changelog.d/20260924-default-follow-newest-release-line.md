### Added

- **An operations checkout that never chose a release line settles
  on one automatically.** Once a release of 1.0.0 or later exists,
  the next `hostwarden-update` on `main` moves it to that release's
  major line instead of only pulling `main`, and `--unpin` returns
  to following `main` and reports what changed there since.
