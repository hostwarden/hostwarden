### Changed

- **An operations checkout opened in Claude Cowork, or in Claude
  Code on the web, reaches no server and says so.** Their shell
  runs in a Linux VM apart from the workstation, without its SSH
  keys, so such a session stops before any server work with a
  pointer to the same checkout in Claude Code on the workstation. A
  development checkout in such a VM is unaffected.
