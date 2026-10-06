# Choose your local SSH agent

SSH can use an app's `IdentityAgent` while Git's SSH signatures inherit a
socket belonging to another agent. Hostwarden resolves the agent before
signing, without changing your global Git, SSH, shell or app settings.

Before your first workspace commit, an interactive session asks whether to use
your existing Git signatures, set them up, or leave your settings unchanged.
Signing is optional. Hostwarden detects the current format and enabled state;
an existing setup keeps its key and signer. New setup offers SSH, OpenPGP/GPG,
X.509, or explicitly no signatures and changes only the workspace's local Git
configuration after your choice. It does not generate or extract private keys
or change app, agent or Pinentry settings.

Personal `Git signing setup: existing`, `configured`, or `later` in
`memory/user.md` remembers that choice so the question does not recur. Git's
actual configuration determines whether and how commits are signed; the marker
does not override it. “Not now” retains existing signatures when enabled and
leaves unsigned work unsigned. Ask to change the setup later when needed.
Unattended sessions keep their settings and never stop for this interview.

In personal, unsynchronized `memory/user.md`, optionally write one unindented
line, without quotes around the path:

```text
SSH agent socket: ~/Library/Application Support/example/agent.sock
```

Use an absolute path or `~/`, including literal spaces, `SSH_AUTH_SOCK` to use
the inherited socket, or `none` to disable it. Empty or duplicate lines fail.
Other tilde forms, tokens, variables, quotes and backslashes are unsupported.
Remove the line to return to automatic selection. Do not commit this file.

The saved selection wins over every host's SSH configuration. Otherwise the
resolver reads effective `IdentityAgent` through `ssh -G`, then uses inherited
`SSH_AUTH_SOCK` when no agent is configured. Explicit `none` never falls back.
Automatic mode preserves host-specific settings in generated
`memory/ssh_config`.

Inspect the socket with `bin/hostwarden-agent --socket`; add `--host
git.example.com`
for that host's settings. Without a host, only wildcard defaults applying to
`hostwarden-agent.invalid` are considered. A host-specific choice never becomes
a global default silently. Use your Git remote's SSH alias as the host.

Run `bin/hostwarden-agent --host git.example.com --exec git commit -S` to sign
with that agent. Workspace commits through `bin/hostwarden-sync commit` use the
default resolver for SSH signatures, as do rebases during `pull`; save a
personal choice if your workspace
requires a host-specific signing agent. Claude Code, Codex and other tools
follow the same instructions, including OpenCode.

Workspace synchronization passes the chosen socket only to the signing program;
fetch authentication retains its existing environment and host-specific SSH
settings. A configured custom signer is preserved. The generic `--exec` wrapper
changes the whole command's environment: use it for `git commit`, and use
`hostwarden-sync pull` for workspace rebases when transport and signing use
different agents.

The SSH selection does not change Git's signature format. GPG users keep their
existing setup: Git's default OpenPGP format, explicit `openpgp`, and X.509
(`x509`) use their own programs, keys, `gpg-agent` and Pinentry settings. Only
SSH signatures use the selected socket; GPG signatures and unsigned commits do
not resolve it. A GnuPG agent's ordinary socket is not its SSH interface. Use
normal Git or workspace synchronization for GPG signatures, without the SSH
wrapper. A locked agent or unavailable Pinentry keeps its usual error; unlock
it or complete the existing setup rather than changing format or disabling
signatures.

Claude Code's existing hooks and SSH configuration continue to apply. Without
a saved selection, Hostwarden preserves the user's host-specific agents. The
wrapper exports `SSH_AUTH_SOCK` only for its command: Git's SSH signer needs
that variable in every client, independently of SSH's `IdentityAgent`.

Codex or another sandboxed client may restrict access to SSH configuration or
the agent socket. An environment variable does not grant socket access. Saving
an absolute socket avoids querying SSH configuration, but the client still
needs permission to connect to it. Hostwarden does not change sandbox settings.
These workspace instructions apply to operations checkouts; development keeps
its existing signing environment and Claude Code's SSH protection.

Use `bin/hostwarden-agent --check` to diagnose whether the agent is available.
The wrapper and workspace signing let Git's signer decide whether it needs an
agent, so private signing keys and custom signers can also work without one. A
workspace whose automatic SSH configuration query fails reports that failure
and passes an empty signing socket, allowing independent signers without
falling back to an inherited agent. Agent-dependent signatures still fail;
save an accessible socket or restore configuration access before retrying.
Malformed saved choices remain errors. The generic `--exec` wrapper requires
successful resolution.

A missing, locked, inaccessible or empty agent stops signatures that need it.
Start or unlock it and retry; Hostwarden neither chooses another agent nor
disables signatures.
An app may still ask for consent or refuse a signature after listing keys.
