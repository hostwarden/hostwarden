---
sidebar_position: 5
description: Lets Hostwarden log in with an SSH key of its own, which
  every host's log names, instead of yours.
---

# Hostwarden's own SSH key

Without it, Hostwarden logs in with whatever key your agent or
`~/.ssh` offers: yours. sshd's log on the host cannot tell its
logins from yours, and anything that takes the session over can use
your key. With a key of its own, named
`hostwarden@<operator>-<workstation>`, every login shows up in the
host's log under that key's fingerprint, and you can revoke it
without touching your own.

It is a recommendation, never a requirement. Hostwarden asks once,
in the first interactive session that reaches a server; *Not now*
leaves everything as it was, and you can ask for it later.

## Where the key lives

Hostwarden offers all three alike. Which one fits depends on what
you already have, and the interim you can live with:

1. **Its own agent.** An `ssh-agent` at
   `~/.cache/hostwarden/agent.sock` that holds Hostwarden's key and
   nothing else, for 8 hours or the lifetime you pick. The key comes
   from Hostwarden's vault in 1Password or Bitwarden Secrets Manager,
   through the same restricted account
   [Password logins](passwords.md) use, or from an encrypted key file
   you unlock in a terminal of your own. Your own agent stays out of
   the session's reach.
2. **Your password manager's agent.** The key sits next to yours in
   1Password or Bitwarden. This cannot be restricted: both apply
   their settings to the whole agent, so a session that reaches it
   can ask for your keys too. What protects you is the manager's
   approval prompt.
3. **A hardware key of its own** (`ed25519-sk`), touched once per new
   connection to a host.

You make the key; Hostwarden never creates, copies or reads a private
key. It records the key under `# SSH Identity` in `memory/user.md`,
which stays on your machine, and `bin/hostwarden-identity load` loads
it into its agent.

## Putting it on a host

Hostwarden never writes `authorized_keys`. It prints the line, and
you add it:

```bash
bin/hostwarden-identity line web1.example.com
```

```
restrict,port-forwarding,pty ssh-ed25519 AAAA… hostwarden@alice-ws1
```

`restrict` turns off everything the key does not need. Port
forwarding and a terminal stay on, for the forwardings Hostwarden
adds to its connections and for commands that need a terminal.
`--from` limits the key to your address, `--until` gives it an end
date.

Once you say it is added, Hostwarden records the key's fingerprint
in the host's memory and tests it with one fresh login. From then on
it offers that key and no other to that host. A host without the
line keeps working as before, and the security and fleet audits
list it as `no Hostwarden key`, next to the logins by each key over
the last 30 days.

## With a certificate from your CA

Where you run an SSH CA, it can certify Hostwarden's key for a
working day at a time, and a host that trusts the CA needs no
`authorized_keys` line for it at all. Hostwarden never signs or
renews the certificate; your CA does, the way you run it. Have it
issued with the key ID `hostwarden@<your handle>`, only the
principals Hostwarden logs in as, no agent forwarding, and a
source address where your workstation has a fixed one. sshd then
logs the key ID with every login, root logins included.

You record the certificate's path, and the command you renew it
with, under `# SSH Identity` in `memory/user.md`. At every session
start, and again before it reaches a host that relies on it,
Hostwarden reads how long the certificate is still valid. It tells
you, with your command, when it ends within two hours, and holds
back the hosts that rely on it once it has ended or cannot be used. No CA is
needed for anything else on this page.

## What protects what

The session runs as your user, so it could still read your key files
and reach your agent's socket. What holds is outside it: an agent or
hardware key that asks before it signs, sshd's options on the key and
its log, and the key's lifetime in the agent. The configuration and
the guard, which refuses an ssh call with `-i`, `-A` or another
agent, are a safety net against mistakes, not a wall. The only real
separation would be a separate OS user or a sandbox for Hostwarden,
which you can set up yourself; Hostwarden does not.

`bin/hostwarden-doctor` reports at every session start whether
Hostwarden's agent answers and holds the key.
