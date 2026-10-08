### Added

- **An operations host can read one area of the fleet instead of
  everything.** `bin/hostwarden-fleet-run --section <key>`, repeatable,
  sends each host `collect <key>…`, and the fleet-read wrapper runs
  only those sections of the signed bundle and its floors. The
  signature still covers the whole bundle, the wrapper runs nothing
  outside it, and a key the bundle's new `SECTIONS=` line does not
  carry refuses the request before anything runs. A run by section is
  always a dry run. Bundles built in the earlier layout, without the
  line, keep running whole; a rebuild adds the line.
