# Local SSH agent

In an operations checkout, use `bin/hostwarden-agent` to resolve the local
agent before an SSH Git signature, whichever tool runs the session. Never
assume that the inherited `SSH_AUTH_SOCK` selects the agent SSH uses:
`IdentityAgent` can override it. Do not change global Git, SSH, shell, launchd
or app settings. Never disable signatures, extract a private key, change an
app's policy or Pinentry mode, or switch agents or formats to get past a
failure.

Each command needs its own environment, since shell exports do not persist
between tool calls; the wrapper below sets it for one command. A sandbox can
block reading SSH configuration or connecting to a Unix socket, and setting a
variable grants neither. Report a denied query or socket and do not change
sandbox permissions.

Development checkouts have no personal workspace memory, and Claude Code's
development SSH shim blocks `ssh -G`. There the existing Git signing settings
and environment stay as they are. The workspace generator and the sync
integration apply only in operations mode.

## Optional signing setup

In an interactive operations session, before the first workspace commit, check
the effective `commit.gpgsign`, `gpg.format` and `user.signingkey` with
`git -C "<checkout>/memory" config`. An omitted format means OpenPGP. An SSH
default-key command or a custom signer counts as an existing setup too, so an
absent key identifier does not mean signing is unavailable. Describe only the
format and whether signing is enabled, never key material.

Where personal `memory/user.md` has no `Git signing setup:` line, ask once:
*"Use your existing Git signatures for this workspace, set up signatures, or
leave the current settings as they are? Signing is optional."* Offer:

1. **Use the existing setup**, recommended when signing is already enabled.
   Keep its format, key, program and enabled state. Record
   `Git signing setup: existing` only after the user chooses it.
2. **Set up or change signatures.** Ask which format: SSH, OpenPGP/GPG, X.509,
   or explicitly no signatures. Confirm the key identifier or public key path
   when needed, reusing the existing signer where possible. Explain any
   missing agent or Pinentry setup before applying the choice. Consent
   authorizes only workspace-local Git configuration: set `gpg.format`,
   `user.signingkey` when selected, and `commit.gpgsign=true` with
   `git -C "<checkout>/memory" config --local`. For no signatures, set only
   `commit.gpgsign=false`; keys and programs stay. Record
   `Git signing setup: configured` after it succeeded.
3. **Not now.** Leave all Git settings untouched and record
   `Git signing setup: later`. Enabled signatures keep signing, and unsigned
   work stays unsigned.

The marker records the interview and is no second source of signing
configuration: Git's effective configuration stays authoritative. Keep it
personal and unsynchronized. Ask again only when the user requests a change,
then repeat the format choice and touch only the workspace's Git
configuration. Unattended sessions ask nothing and keep the existing
configuration; development sessions have no interview.

## Personal format

The optional, case-sensitive, unindented line in personal `memory/user.md` is:

```text
SSH agent socket: ~/Library/Application Support/example/agent.sock
```

Exactly one nonempty line is allowed. Its value is the remainder after the
colon without leading or trailing blanks; spaces inside the path are literal,
without quotes or escaping. Use an absolute path, `~/` for this user's home,
`SSH_AUTH_SOCK` for the inherited socket, or `none` to disable the agent.
Omission means automatic selection. Anything else, including other tilde
forms, variables, quotes, backslashes and line breaks, is rejected: write the
expanded absolute path. Nothing is evaluated as shell code. Never commit the
file or copy a personal socket into shared `memory/ssh_hosts`.

Ask for a choice only when automatic selection cannot identify the needed
agent, and save it only when the user selects it; never persist a detected
path silently. No app name is required, Bitwarden included.

## Precedence

1. A saved `SSH agent socket:` overrides SSH configuration for every host and
   the inherited environment. `none` disables the agent without a fallback.
2. Without one, `ssh -G HOST` gives the effective `IdentityAgent` by OpenSSH's
   own Host, Match, Include and first-value rules. It evaluates local
   configuration only, and trusted `Match exec` commands can run locally.
3. With no `IdentityAgent`, the inherited `SSH_AUTH_SOCK` is used.
   `IdentityAgent none` disables it, and `IdentityAgent SSH_AUTH_SOCK` names
   it explicitly.

`bin/hostwarden-agent --host git.example.com --socket` inspects one SSH
context, aliases and host-specific settings included; give the host alias of
the Git SSH remote when its configuration matters. Without `--host`, the
neutral `hostwarden-agent.invalid` applies: wildcard defaults count, and a
host-specific agent never becomes a global default. An HTTPS remote has no SSH
host context, so it uses that default or a saved choice.

`bin/hostwarden-ssh-config` writes a saved choice as a quoted `IdentityAgent`
before including the user's files; a saved `SSH_AUTH_SOCK` stays symbolic, so
each SSH process reads its current environment. Automatic mode leaves the
user's host-specific choices intact. The generator needs no running agent, and
an invalid saved choice is reported while the file is still written, without
an `IdentityAgent` line.

## Signatures and failures

Run signing commands through the resolver, arguments quoted normally:

```sh
bin/hostwarden-agent --host git.example.com --exec git commit -S
```

`--exec` changes the environment of the whole command, so use it for signing
commands only; a command that also authenticates to a remote, such as
`git pull`, would hand it the signing agent too.

For a workspace, `bin/hostwarden-sync commit`, and `pull` where its rebase
replays local commits, apply the default resolver when `gpg.format=ssh` and
`commit.gpgsign=true`. They set
`SSH_AUTH_SOCK` for the commit and for the rebase that replays local commits,
and for nothing else: the fetch keeps its original environment and the
remote's own `IdentityAgent`. The signing key, program and default-key command
are Git's own and see the selected socket. A workspace needing a host-specific
signing agent saves its personal choice, or uses the wrapper with that host
for direct Git commands.

`--check` requires a Unix socket and a successful `ssh-add -l`, with keys and
fingerprints suppressed; use it to diagnose availability. `--exec` and the
workspace signing do not require an agent, since private signing keys and
custom signers may not need one. A missing, stale, inaccessible, empty or
locked agent fails the signatures that need it, with the signer's diagnostics
and without switching agents. Ask the user to start or unlock it and retry.
Listing identities does not prove that signing succeeds: an app can still ask
for consent or refuse a key.

If automatic `ssh -G` discovery fails, workspace signing says so and passes an
empty socket to the signer. Private keys and independent custom signers still
work; signatures that need an agent fail without inheriting another one. Save
an accessible socket or restore configuration access to retry them. A
malformed saved choice or unsupported path stays fatal to the commit and to
such a rebase, and so does a failed resolution in the generic wrapper, whose
command may need the agent for transport.

## OpenPGP and X.509 signatures

Only `gpg.format=ssh` with `commit.gpgsign=true` resolves an agent. An omitted
format, `openpgp`, `x509` and unsigned commits keep their programs, keys,
`GNUPGHOME`, `GPG_TTY`, GnuPG agent and Pinentry, and a broken SSH selection
never blocks them. GnuPG's ordinary agent socket is no SSH agent socket. For a
missing key, a locked GPG agent or unavailable Pinentry, report the signer's
diagnostics and ask the user to complete their existing setup.

OpenSSH's supported forms are documented in
[ssh_config](https://man.openbsd.org/ssh_config); Hostwarden accepts the
literal path subset above so one selection can also reach `ssh-keygen`.
