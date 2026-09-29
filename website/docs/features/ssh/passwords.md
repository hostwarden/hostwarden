---
sidebar_position: 4
description: Logs in to devices that take no SSH key, with a password
  Hostwarden never sees, from your keychain or a password manager.
---

# Password logins

Some devices take no SSH key: DrayTek Vigor routers, many switches,
some appliances. Hostwarden logs in to them with a password that
neither the AI session nor the conversation ever sees. ssh asks
`bin/hostwarden-askpass` for it, and that helper reads it from where
you put it and hands it to ssh through a pipe.

Where a host takes a key or a certificate, a password is refused.
`bin/hostwarden-password` asks the host which login methods it
offers before it stores, links or checks anything, and refuses a
host that offers key logins; the helper gives no password without
that answer from the last 30 days. Hostwarden offers to set a key up
instead. A device that learns keys with a firmware update stops
getting a password within a week.

## Setting a host up

When a host turns out to take only a password, Hostwarden asks where
the password lives, adds four lines to the host's block in
`memory/ssh_hosts` and a line `- SSH login: password (…)` to its
memory. Then one of these, depending on your answer.

**On this machine.** Run this yourself, in a terminal of your own,
from the checkout:

```bash
bin/hostwarden-password set admin@rtr1.example.com
```

It asks for the password twice without echoing it and stores it in
the macOS keychain, elsewhere in a file encrypted with a key kept in
another directory. `!` in Claude Code has no terminal to ask in; the
script refuses there. This is the recommended place: only
Hostwarden's own passwords are in reach. A Linux desktop's Secret
Service is not used, since it hands every entry of an unlocked
keyring to any program you run.

## Passwords in a password manager

Whatever identity Hostwarden reads a password manager with, the AI
session can read everything that identity sees. So Hostwarden uses a
manager only through an identity that sees its SSH entries and
nothing else, and only once you have decided so; it asks, explains
what is at stake, and records the decision. Your own login is never
used.

**1Password.** Create a vault for Hostwarden holding only the SSH
entries, and a
[service account](https://www.1password.dev/service-accounts/get-started)
with read access to that vault alone; 1Password grants vaults whole,
never single items. Store the token yourself with
`bin/hostwarden-password token 1password`. Give each item a text
field named `hostwarden` that holds the target exactly as
`bin/hostwarden-password check admin@rtr1.example.com` prints it in
parentheses, such as `admin@192.0.2.1:22`. `link` refuses a token
that sees more than one vault, and reads only that field.

**Bitwarden or Vaultwarden.** Create an account of its own for
Hostwarden, give it read access to one collection holding only the
SSH entries, and set it up in an [rbw](https://github.com/doy/rbw)
profile of its own:

```bash
RBW_PROFILE=hostwarden rbw config set email hostwarden@example.com
RBW_PROFILE=hostwarden rbw config set base_url https://vault.example.com
RBW_PROFILE=hostwarden rbw unlock
```

The item's user name is the SSH user, and a custom field named
`hostwarden` holds the target. Vaultwarden keeps collections apart
only from 1.35.3 on. Hostwarden cannot see what the account's
collections hold; that rests on your decision.

**Bitwarden Secrets Manager** (Bitwarden's own servers; Vaultwarden
has none): a secret named after the target, in a project a machine
account may only read, with its access token stored by
`bin/hostwarden-password token bws`.

## Several logins, several machines

Each login is a line of its own under `# SSH Passwords` in
`memory/user.md`, so two accounts on one router work side by side.
That file is personal: on another machine of yours, Hostwarden finds
the host marked as password-only, sees no password for it there, and
gives you the command to set or link it again.

## What protects the password

- The helper answers only a password prompt, only from an ssh
  process started with this checkout's `memory/ssh_config`, and only
  for the user, address and port that ssh actually connects to. A
  changed address in the shared `memory/ssh_hosts` finds no
  password, and a password manager's item that does not name the
  target gives none, so a wrong line in `memory/user.md` cannot
  reach your other passwords.
- An ssh call that switches off the host key check gets no password.
  Every refusal also ends the ssh call, so the device never sees an
  empty password it would count as a failed login.
- It answers at most three times per host in 15 minutes, and a
  refused password is never retried: many devices lock an account
  after a few failures.
- The taboo guard denies the commands that would read a stored
  password or token.

A password on this machine is encrypted at rest, which keeps it out
of a backup, a sync or a commit. Anything running as your user can
still read it without asking you; the guard and the rules keep the
session from doing so. A password manager with a service account
limits what can be read at all.

Rule: `rules/ssh-passwords.md`.
