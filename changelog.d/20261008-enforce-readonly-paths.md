### Added

- **A `readonly` path can be enforced on the host, when you ask.**
  The `hostwarden-enforce-readonly` skill turns a glob of a host's
  `readonly` list into something the host keeps: an immutable flag
  on the files (`chattr +i` on Linux, `chflags schg` on FreeBSD and
  macOS), a read-only ZFS dataset or Btrfs subvolume for a whole
  tree, or a login of Hostwarden's own without the write bit on
  those paths and sudo for the commands you name only. It reads
  what is in place, names what each mechanism breaks before
  asking, applies one per glob, and lifts it again once the glob
  left the list. Nothing is applied because a glob was written,
  and sshd's configuration and keys stay untouched.
