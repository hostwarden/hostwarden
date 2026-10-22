### Fixed

- **The safety net checks the persisted file before it cancels the
  undo.** Where the tool can check the written firewall or network
  file, the check and the cancel run in one call, so a failing check
  leaves the undo armed. A PAM change is read, not gated: `diff` is
  inspected and each module is looked up, and the password-login test
  stays the safety.
