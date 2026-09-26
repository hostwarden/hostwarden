---
sidebar_position: 4
description: Creates and removes accounts, groups, and sudo rules
  the way each host manages them.
---

# Accounts

Hostwarden records how admins log in on each host, then manages
accounts the way that model expects.

- **The login model is recorded once.** Through a role account, a
  directory, local accounts or an agent, as one `Accounts:` line,
  and Hostwarden creates or removes accounts, groups and sudo rules
  the way that model does, each asked first.
- **Team accounts stay in sync.** They get the same UID and GID on
  every host; removing one revokes its certificates first and
  keeps the home directory unless you say otherwise.
- **Certificate and directory logins are covered.** Logins with
  user certificates, and accounts an identity provider hands out on
  demand, are covered: the second are read and reported.
- **Directories, identity providers and CAs are never written to.**
  Hostwarden tells you what to create there instead.
