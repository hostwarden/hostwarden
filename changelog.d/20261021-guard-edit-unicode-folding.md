### Security

- **The guard holds an SSH key or sshd_config against a file name
  spelled in Unicode.** On macOS a ligature, a sharp s or a zero-width
  character in a path opens the same file, so Edit or Write on
  `sshd_conﬁg` reached it past the guard. The target is now also
  matched with the characters Unicode folds onto ASCII letters spelled
  out and with all other non-ASCII removed. Without jq a relative or
  JSON-escaped target is denied, and every path key of a call is judged,
  not the first.
