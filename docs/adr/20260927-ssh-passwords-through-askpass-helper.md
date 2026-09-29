---
id: 20260927-ssh-passwords-through-askpass-helper
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [ssh, secrets, appliances]
---

# SSH passwords reach ssh through an askpass helper only

## Context

Hostwarden logged in by key alone. DrayTek Vigor routers and many
switches take no key, so they could not be managed. A password has
to reach ssh without passing through the session, the
conversation, an argument or the environment, and it may live on
the workstation or in 1Password or Bitwarden. The session runs as
the same user as anything that could decrypt a local copy.

## Decision drivers

- The password never enters the model's context.
- No secret in `argv`, the environment of a long-lived process, or
  a shared workspace file.
- A wrong line in memory must not hand one password to another host
  or read another entry of the user's password manager.
- Several logins per host and per workstation.

## Considered options

### An `SSH_ASKPASS` helper keyed by ssh's own resolved target — chosen

ssh runs `bin/hostwarden-askpass` with `SSH_ASKPASS_REQUIRE=force`;
a `Match originalhost … exec` in `memory/ssh_config` tells it the user,
HostName and Port that ssh process logs in to. The helper reads the
password from the OS store or a password manager, whose entry must
name that target in a field of its own, and writes it only into
ssh's pipe. Against it: a `Match exec` per call to such a host, and OpenSSH 8.4
or newer.

### sshpass

Well known. Against it: the password goes in as an argument, an
environment variable or a file sshpass reads, and it scrapes a
terminal prompt.

### The password in the workspace, encrypted

One place for every machine. Against it: the key has to reach every
workstation that shares the workspace, and a shared file is written
by everyone who can push to it.

### Parsing the target from the prompt or ssh's command line

No extra process per call. Against it: keyboard-interactive prompts
name no host, and `ps` joins arguments with spaces, so a quoted
remote command reads as options.

## Decision

Only a host whose login methods name no `publickey` gets a
password. ssh asks `bin/hostwarden-askpass`, which answers a
password prompt only, only its parent ssh started with this
checkout's `memory/ssh_config` and no host-key override, only for
the target that process resolved, at most three times in 15
minutes. `memory/user.md` names each login's source.

## Consequences

Every ssh call to a password host runs one short `Match exec`;
a refusal ends the ssh process, which would otherwise send an empty
password. OpenSSH before 8.4
cannot log in by password; `hostwarden-doctor` names it. A local
password is readable by anything running as the user; the taboo
guard, `rules/ssh-passwords.md` and `rules/secrets.md` keep the
session from reading it. A password manager is used only through an
identity that sees Hostwarden's entries alone, on the user's
recorded decision. The source of a login is set again on each
workstation. `rules/ssh-passwords.md` and `rules/ssh-config.md`
carry the constraint.

## Confirmation

A lab container with sshd taking only a password logs in through the
helper, and refuses a call with `StrictHostKeyChecking=no`, a
second target and a fourth attempt; `tests/bin/hostwarden-password.sh`
holds the helper to it.
