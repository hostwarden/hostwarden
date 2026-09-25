### Fixed

- **`hostwarden-impact --report` printed nothing on a macOS
  workstation.** Its formatter built a line from two chained
  ternary expressions passed straight to `printf`, a form macOS's
  own `awk` cannot parse; the whole report was silently empty.
  The ternaries are computed into plain variables first, which
  every `awk` handles the same way.
