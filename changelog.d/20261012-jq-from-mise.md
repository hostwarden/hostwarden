### Added

- **The guard hooks run the jq mise installed.** `mise.toml` pins jq,
  and where `mise install` has run in the checkout the hooks use that
  one, so they read a tool call the same way on every workstation and
  in CI; a workstation with mise needs no other jq. Where `mise
  install` has not run, the hooks run the jq the PATH has, never
  through mise's shims, which fail until it has, and the doctor
  reports that jq as missing.
