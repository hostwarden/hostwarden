### Changed

- **Hostwarden asks for keys in an agent or on hardware, not
  passphrase-free keys.** The documentation now recommends a key an
  agent confirms per use (1Password, Bitwarden, KeePassXC,
  `ssh-add -c`) or a hardware key, and a key without a passphrase
  only for an operations host's fleet-read key and a deploy user's
  pipeline key. That pipeline key is made by you, with a command
  Hostwarden hands over, under `~/hostwarden-keys/`.

### Added

- **The doctor names the agents and key files ssh offers, and warns
  about a key file without a passphrase.** It covers the keys every
  host gets and those of the block in `~/.ssh/config` of a host
  Hostwarden knows, and
  also names a key with a passphrase that no agent holds. In an
  operations checkout it checks at every session start, gives up on
  a step that takes over five seconds, and refuses nothing; no key
  material reaches its output.
- **The security audit reports SSH logins that need two factors.**
  It counts what each method asks for, so a password asked twice is
  one factor, and says so where a PAM stack is too involved to tell.
  An override turns on a note for hosts whose sshd
  accepts one factor, for where NIS2 or BSI IT-Grundschutz applies.
