# Local SSH agent

In an operations checkout, use `bin/hostwarden-agent` to resolve the local
agent before an SSH Git signature. This applies to Claude Code, Codex,
OpenCode and other agents. Never assume
that the inherited `SSH_AUTH_SOCK` selects the agent SSH uses: `IdentityAgent`
can override it. Do not change global Git, SSH, shell, launchd or app settings.

## Client compatibility

Claude Code keeps its existing SessionStart hooks and SSH behavior. Without a
saved choice, generated configuration still includes the user's SSH files and
leaves their host-specific `IdentityAgent` settings intact. The signing wrapper
exports the selected socket only for the command it runs; it does not change
Claude Code's environment globally.

Codex and OpenCode use the same resolver. `SSH_AUTH_SOCK` is the bridge to Git's
SSH signing program in every client, even when SSH itself uses `IdentityAgent`.
A sandbox can restrict reading SSH configuration or connecting to a Unix
socket; setting the variable does not grant either permission. A saved absolute
socket avoids the configuration query, but the socket must still be accessible.
Report a denied query or socket access; do not change sandbox permissions or
fall back to another agent silently. The generic wrapper requires successful
resolution. Workspace signing handles an automatic query failure as described
under Signatures and failures.

Development checkouts have no personal workspace memory. Claude Code's
development SSH shim also blocks `ssh -G`. Keep existing Git signing settings
and environment there; do not require automatic resolution through this wrapper
or bypass the shim. The workspace generator and sync signing integration apply
only in operations mode.

## Optional signing setup

In an interactive operations session, before the first workspace commit, check
the effective `commit.gpgsign`, `gpg.format` and `user.signingkey` with
`git -C "<checkout>/memory" config`. An omitted format means OpenPGP. Existing
SSH default-key commands and custom signers count as an existing setup too;
do not assume that an absent key identifier means signing is unavailable.
Describe only the format and whether signing is enabled, never key material.

Where personal `memory/user.md` has no `Git signing setup:` line, ask once:
*"Use your existing Git signatures for this workspace, set up signatures, or
leave the current settings as they are? Signing is optional."* Offer:

1. **Use the existing setup**, recommended when signing is already enabled.
   Keep its format, key, program and enabled state. Record
   `Git signing setup: existing` only after the user chooses it.
2. **Set up or change signatures.** Ask which format: SSH, OpenPGP/GPG, X.509,
   or explicitly no signatures. Confirm the selected key identifier or public
   key path when needed, reusing the existing signer where possible. Explain
   any missing agent or Pinentry setup before applying the choice. User consent
   authorizes only workspace-local Git configuration: set `gpg.format`,
   `user.signingkey` when selected, and `commit.gpgsign=true` with
   `git -C "<checkout>/memory" config --local`. For an explicit choice of no
   signatures, set only `commit.gpgsign=false`; retain keys and programs.
   Record `Git signing setup: configured` after successful configuration.
3. **Not now.** Leave all Git settings untouched and record
   `Git signing setup: later`. Existing signatures continue to be used; this
   option does not disable them. With signing already off, work remains
   unsigned. Revisit only when the user requests it.

The marker records the interview, not a second source of signing configuration.
Effective Git configuration remains authoritative and can change outside
Hostwarden. Keep the marker personal and unsynchronized. Never ask again merely
because the format or key changed. If the user requests a change, repeat the
format choice and update only the workspace's Git configuration.

Unattended sessions ask nothing and retain the existing configuration. Missing
or deferred setup does not prevent server work or enable signing automatically.
Enabled signatures must still succeed before a commit is accepted; never turn
them off to get past a failure. Development sessions have no setup interview.

## Personal format

The optional, case-sensitive, unindented line in personal `memory/user.md` is:

```text
SSH agent socket: ~/Library/Application Support/example/agent.sock
```

Exactly one line is allowed. Its value is the remainder after the colon, without
leading or trailing blanks; spaces inside the path are literal, without quotes
or shell escaping. Use an absolute path or `~/` for this user's home,
`SSH_AUTH_SOCK` for
an explicitly inherited socket, or `none` to disable the agent. Omission means
automatic selection. Duplicate or empty fields fail. Other tilde forms, token
expansion, variables, backslashes, quotes, carriage returns and newlines are
unsupported; write the expanded absolute path instead. Nothing is evaluated as
shell code. `memory/user.md` is already excluded from workspace synchronization;
never commit it or copy a personal socket into shared `memory/ssh_hosts`.

Ask for a choice only when automatic selection cannot identify the needed
agent. Save a choice only when the user selects it; never persist a detected
path silently. No app name is required, including for Bitwarden.

## Precedence

1. A saved `SSH agent socket:` overrides SSH configuration for every host and
   the inherited environment. `none` disables it without falling back.
2. Without a saved line, `ssh -G HOST` determines the effective `IdentityAgent`
   using OpenSSH's own Host, Match, Include and first-value rules. This
   evaluates
   local configuration only; trusted `Match exec` commands can run locally.
3. If no `IdentityAgent` is set, use inherited `SSH_AUTH_SOCK`. An explicit
   `IdentityAgent none` disables it. `IdentityAgent SSH_AUTH_SOCK` uses the
   inherited value explicitly.

`bin/hostwarden-agent --host git.example.com --socket` inspects a particular SSH
context, including aliases and host-specific settings. Supply the same host
alias as the Git SSH remote when its configuration matters. Without `--host`,
resolution uses `hostwarden-agent.invalid`: wildcard defaults apply, and a
host-specific agent is never promoted to a global default. For an HTTPS Git
remote there is no SSH host context; use that default or a saved choice.

`bin/hostwarden-ssh-config` writes a saved choice as a quoted `IdentityAgent`
before including the user's files. A saved `SSH_AUTH_SOCK` stays that symbolic
value, so each SSH process reads its current environment rather than a socket
captured when the configuration was generated. Automatic mode leaves their
host-specific
choices intact. The generator does not require a running agent: a temporarily
locked app must not prevent configuration generation, and an invalid saved
choice is reported while the file is still written, without an `IdentityAgent`
line.

## Signatures and failures

Run signing commands through the resolver, with arguments quoted normally:

```sh
bin/hostwarden-agent --host git.example.com --exec git commit -S
```

For a workspace, `bin/hostwarden-sync commit` and `pull` (rebased signatures)
apply the default resolver when
`gpg.format=ssh` and `commit.gpgsign=true`. It changes only the signing
program's `SSH_AUTH_SOCK`, preserving the signing key and program. Fetch
authentication keeps its original environment and host-specific SSH settings;
the socket override applies only inside the signing program. Git's signing
program
checks availability when it needs an agent; private signing keys and custom
signers can work without one. A workspace needing a
host-specific signing agent must save its personal choice or use the wrapper
with its host for direct Git commands.

`--exec` deliberately changes the environment of the whole command. Use it for
signing commands such as `git commit`; do not wrap `git pull` or another command
that also authenticates to a remote when transport and signing use different
agents. Use `hostwarden-sync pull` for workspace rebases, which isolates the
signer's socket from fetch authentication.

Git's `gpg.ssh.defaultKeyCommand`, when configured instead of `user.signingkey`,
also runs with the selected signing socket. Its command and a custom
`gpg.ssh.program` are preserved through per-command adapters, never written back
to Git configuration.

If automatic `ssh -G` discovery fails, workspace signing reports the failure
and passes an empty socket only to the signing program and key command. Private
keys or independent custom signers can still work; signatures requiring an
agent fail without inheriting another one. Save an accessible socket or restore
configuration access before retrying agent-based signing. A malformed saved
choice or an unsupported resolved path remains fatal. The generic `--exec`
wrapper stays strict because its command may also need an agent for transport.

`--check` requires a Unix socket and a successful `ssh-add -l`; keys and
fingerprints are suppressed. Use it to diagnose agent availability. `--exec`
passes the selected socket to the command without requiring an agent: private
signing keys and custom programs may not need one. A missing, stale,
inaccessible, empty or locked agent fails signatures that require it, with the
signing program's diagnostics and without switching agents. Ask the user to
start
or unlock it, then retry. Listing identities does not prove that signing will
succeed: an app can require consent or refuse a key's signature. Keep the Git
failure visible and preserve signing requirements; never disable signatures,
extract a private key, or alter the app's policy to make the command succeed.

## OpenPGP and X.509 signatures

The personal SSH socket does not choose Git's signature format. Only explicit
`gpg.format=ssh` with `commit.gpgsign=true` activates workspace signing
adapters.
An omitted format uses Git's OpenPGP default; explicit `openpgp` and `x509` keep
their existing programs, keys and signing behavior. Unsigned commands do not
resolve a signing agent. Do not use the SSH wrapper for GPG signatures.

Keep GnuPG's environment, including `GNUPGHOME` and `GPG_TTY`, and its agent and
Pinentry configuration. Its normal agent socket is not an SSH agent socket;
only an agent's separate SSH interface belongs in `SSH agent socket:`. A broken
SSH selection must not block an OpenPGP or X.509 signature. For a missing key,
locked GPG agent or unavailable Pinentry, report the signer's diagnostics and
ask the user to unlock or complete their existing setup. Never change Pinentry
mode, extract a private key, disable signatures or switch formats silently.

OpenSSH's supported forms are documented in
[ssh_config](https://man.openbsd.org/ssh_config); Hostwarden accepts the literal
path subset above so the same selection can be passed to `ssh-keygen`.
