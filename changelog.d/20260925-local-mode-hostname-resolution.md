### Fixed

- **Local mode no longer files a workstation's memory under the
  literal name "localhost".** Before creating or looking up its
  memory directory, local mode resolves the machine's own hostname
  with `hostname -s`, run directly in the shell, and never opens an
  SSH connection to itself to do so.
