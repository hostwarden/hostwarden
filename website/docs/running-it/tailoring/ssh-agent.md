# Choose your local SSH agent

SSH can use an app's `IdentityAgent` while Git's SSH signatures inherit the
socket of another agent. Hostwarden resolves the agent before it signs,
without changing your global Git, SSH, shell or app settings.

## Git signing setup

Before your first workspace commit, an interactive session asks once whether
to use your existing Git signatures, set them up, or leave your settings as
they are. Signing is optional. An existing setup keeps its key and signer; a
new one offers SSH, OpenPGP/GPG, X.509 or no signatures and changes only the
workspace's local Git configuration after your choice. Hostwarden never
generates or extracts private keys, and never touches app, agent or Pinentry
settings.

`Git signing setup: existing`, `configured` or `later` in `memory/user.md`
remembers your answer. Git's own configuration still decides how commits are
signed. "Not now" keeps enabled signatures and leaves unsigned work unsigned.
Unattended sessions never stop for this question.

## Pick the agent

In your personal, unsynchronized `memory/user.md`, optionally write one
unindented line, without quotes around the path:

```text
SSH agent socket: ~/Library/Application Support/example/agent.sock
```

Use an absolute path or `~/`, with literal spaces; `SSH_AUTH_SOCK` for the
inherited socket; or `none` to disable the agent. Empty and duplicate lines
fail, as do other tilde forms, variables, quotes and backslashes. Remove the
line to return to automatic selection, and never commit the file.

A saved choice wins over every host's SSH configuration. Without one,
Hostwarden reads the effective `IdentityAgent` with `ssh -G` and falls back to
`SSH_AUTH_SOCK` only when none is configured. `none` never falls back, and
automatic mode keeps your host-specific settings in `memory/ssh_config`.

`bin/hostwarden-agent --socket` shows the result, `--check` tells whether the
agent is available, and `--host <alias>` evaluates one host's settings.
`bin/hostwarden-agent --exec git commit -S` signs with the resolved agent.

## What it touches

Workspace commits and the rebase in `hostwarden-sync pull` use the resolved
socket for SSH signatures only. The fetch keeps its own environment, and a
custom signer or default-key command is kept. OpenPGP, X.509 and unsigned
commits keep their own programs, `gpg-agent` and Pinentry, and a broken SSH
selection never affects them. A locked or missing agent fails the signatures
that need it; unlock it and retry, and Hostwarden neither picks another agent
nor turns signing off.

A sandboxed client such as Codex may block reading your SSH configuration or
connecting to the socket. Saving an absolute socket avoids the configuration
query, but the client still needs permission to reach it, and Hostwarden does
not change sandbox settings. Development checkouts keep their existing signing
environment.
