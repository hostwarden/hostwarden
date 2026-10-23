---
id: 20261021-own-ssh-identity-recommended
status: proposed
supersedes:
superseded-by:
waiting-on: the review of the pull request for issue #515
tags: [ssh, keys, guard]
---

# Hostwarden logs in with its own SSH key, per host

## Context

Issue #515, specified by Julian on 2026-10-21. Hostwarden logged in
with whatever key the user's agent or `~/.ssh` offered, the admin's
own, so sshd's log could not tell its logins apart. ISO/IEC 27002
8.2 asks for separate identities for privileged work, BSI
OPS.1.1.2.A5 for showing who did which administrative task. The
session runs as the same OS user as the admin, so nothing inside it
can keep the admin's key out of reach.

## Decision drivers

- Attribution in every host's log, and a key that can be revoked
  alone.
- Recommended, never required: without a recorded identity nothing
  changes.
- Hostwarden never writes `authorized_keys` and never handles a
  private key.
- No host refuses a login because its key line is still missing.
- `git push` and `bin/hostwarden-sync` keep the user's own agent.

## Considered options

### Its own key, offered per host through memory/ssh_config — chosen

`memory/user.md` records the key and its agent: Hostwarden's own,
the password manager's, or a hardware key. The operator adds the
`authorized_keys` line Hostwarden prints. The host's memory then
records the fingerprint, and a `Match originalhost` block before
`Match all` offers the key there. One fresh login tests it, and a
refusal takes the line out again: the test runs after the write
because the guard denies the per-call options a test beforehand
would need. A guard module denies `-i`, `-A`, the identity options,
a call without this checkout's `-F` and reading `~/.ssh/id_*`.
Against it: the admin's key stays in reach of the session, the
guard is only a backstop, and a password manager's agent cannot be
confined to one key.

### The same lines in Match all

The specification's first form. Lost: a host without the line, a
new one above all, refuses every login once the identity is
recorded, and each refusal counts with fail2ban.

### SSH_AUTH_SOCK pointed at Hostwarden's agent

Lost: it adds nothing ssh does not get from `IdentityAgent`, and it
breaks `git push` and `bin/hostwarden-sync`, which need the user's
own agent.

### A separate OS user or a sandbox for the session

The only real isolation from the admin's files and sockets. Lost:
out of proportion for a user with a few hosts, and it changes how
every tool reaches the workstation. Documented, not built.

## Decision

An identity is offered, never required, in one setup question with
every option alike. Recorded, it applies per host once that host's
memory records its fingerprint; elsewhere calls run as before.
`rules/ssh-identity.md` separates what holds — an agent's or
hardware key's confirmation, sshd's `authorized_keys` options and
log, `ssh-add -t` — from the backstop: the generated lines and the
guard.

## Consequences

Each operator and workstation has its own key, one line per host
in `authorized_keys` and one `Hostwarden key:` line in host memory.
The audits count logins by fingerprint. A key file without a
passphrase in the user's configuration is still offered, which
#345's doctor check reports. `rules/ssh-identity.md`,
`bin/hostwarden-identity`, `bin/hostwarden-ssh-config` and
`.claude/hooks/guard-taboos.d/identity.sh` carry it.

## Confirmation

`tests/bin/hostwarden-ssh-config.sh` and the guard matrix hold the
lines and the denials. The default options `restrict,port-forwarding,pty`
come from sshd(8); a lab check of `-O forward` and `ssh -t` against
them, which Julian runs or allows, is still to come.
