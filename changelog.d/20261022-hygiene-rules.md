### Added

- **Small hygiene rules for servers.** The agent ends a process by its
  one PID and never by name pattern, lists file names before it reads
  fields in a recursive search, keeps log excerpts, mail content and
  personal data out of memory, and knows that a conversation rewind
  undoes nothing on a host. A deploy key goes to the CI secret store
  over stdin, and a user's shell profile gets one marked block, with
  `.bashrc` backed up and a managed file changed at its source.
