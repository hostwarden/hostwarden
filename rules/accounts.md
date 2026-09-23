# Accounts and Sudo Rules

A key or certificate proves who logs in. Whether the account
exists, where it comes from and what it may do is decided on the
host: by the name service (`nsswitch.conf`), PAM and sudo. This
file sorts a host into one of four account models, records it in
one memory line, and says what that means for Hostwarden's own
login and for any change to accounts or sudo rules. It covers
Linux, FreeBSD and macOS.

What the host does is read with the probe in
`rules/accounts-probe.md`, which also says how to read its output.
Where memory already has the `Accounts:` line, read that instead
of probing again.

## Which Model a Host Uses

- **Role account:** admins log in as `root` or one shared admin
  account. With certificates, the principals decide who may, and
  the key ID — the name the CA wrote into the certificate, which
  sshd logs with each login — shows who it was. Few or no personal
  accounts.
- **Directory:** personal accounts from a directory, sudo from
  the directory or from a directory group in the local files.
- **Local:** personal accounts in the local files (macOS:
  `/Local/Default`), created on each host, sudo through a local
  group. With a CA, a small team gets the same account on every
  host (Team Accounts).
- **Agent:** vendor software on the host serves or creates the
  accounts and usually handles sudo itself. Serving: its own
  source in `passwd:`. Creating: local accounts it adds and
  removes, such as Pangolin's Newt with a sudo file
  `/etc/sudoers.d/90-pangolin-<user>`
  (`.agents/skills/hostwarden-security/references/vpn-ssh.md`).

A host can mix them, such as a directory host with one local
break-glass account. Record the model that admits the admins and
name the exceptions (Memory).

People who get an account without anyone creating it beforehand,
from an identity provider and short-lived certificates:
`rules/accounts-on-demand.md`.

## Certificate Logins

A certificate proves who logs in, not that the account exists.
sshd looks the account up through NSS before it checks any key or
certificate: an unknown name is `Invalid user`, the certificate
never counts, and `AuthorizedKeysCommand` and
`AuthorizedPrincipalsCommand` run only for an account that
resolves. `getent passwd <name>` (macOS:
`dscl /Search -read /Users/<name> RecordName`) must answer before
a person's first login. Which principals a certificate carries:
`ssh-keygen -L -f <certificate>`.

Which user CA sshd trusts, its principals files and its revocation
list are read as `rules/ssh-ca.md` → User CA Trust says; a login
refused on the principal, as `rules/ssh-ca-issuing.md` → When a
Login Fails on the Principal says. For the accounts, two things
follow:

- With `AuthorizedPrincipalsFile none`, sshd's default, a
  certificate must name the account itself, so a principal named
  like a local account (`root`, `deploy`) logs in as that account.
  The CA's issuing rules must keep such names from people
  (`rules/ssh-ca-issuing.md` → Findings).
- A principals file per account (`…/%u`) admits no certificate for
  an account without its file. On a directory host that locks out
  every person, so keep `none` there and give files only to role
  accounts, in a `Match User` block.

The user CA's trust and these directives live in `sshd_config`,
which Hostwarden never writes on a running sshd (`AGENTS.md` →
Critical Safety Rules): it names the lines, the user sets them.
A new guest is the exception, whose first boot may set them
(`hostwarden-new-guest`).

## Changes Across Hosts

Connecting hosts to a directory or creating team accounts on them
is a plan (`rules/server-memory.md` → Plans that outlive a
session), whose `Status:` names the hosts still pending. Per host,
one call with its question and its backup, then an access test
with the fresh-login options (`rules/ssh-connections.md` →
Fresh-login options). Stop at the first failed test. A host that
could not be reached is not done.

## Memory

One line in `memory/servers/<hostname>/memory.md`:

```markdown
- Accounts: directory (SSSD, AD example.com, access
  simple:%linux-admins), sudo from sss + %linux-admins ALL (root)
  in /etc/sudoers.d/admins, mkhomedir on; local: deploy, rescue
- Accounts: role (root via principals), sudo unused
- Accounts: local (team roster, certificates), sudo %sudo
  NOPASSWD ALL (root)
```

Three hosts, one line each. `local:` lists the local accounts
beside the model that admits the admins; the line holds facts
only. That one of them is meant as break-glass is the user's word,
recorded as a decision for the host (`rules/decisions.md` →
Writing one), never inferred and never written into this line.
What the probe could not see is marked:
`sudo rules unchecked (needs root)`. Hostwarden's own sudo stays in
its `Sudo:` line (`rules/privilege-escalation.md`).

The line is rewritten whenever it stops being true: after a change
to accounts, groups or sudo rules on the host, and when a security
audit's probe finds something else, an `unchecked` part included.
The fleet audit only reports a line its probe contradicts.

## What It Means for Hostwarden

- **Role account:** Hostwarden logs in as that account; root is
  the login itself or sudo from the shared account.
- **Directory or local:** Hostwarden logs in as the user's own
  personal account and depends on its sudo, all of it or the
  commands `rules/privilege-escalation.md` → Mixed Mode counts.

Where the recorded SSH user does not fit the model,
`rules/ssh-user.md` → Account Model asks.

## Changing Accounts or Sudo Rules

Ask first: both are privilege changes.

- **Directory host:** accounts, groups and directory sudo rules
  belong in the directory. Hostwarden never writes to a
  directory, an identity provider or a CA; it tells the user what
  to create there. Never create a local account instead, unless
  the user asks for a local one, such as break-glass or a service
  account.
- **Agent-managed accounts** and their sudo files belong to the
  agent: change them on its side, not on the host, where the
  agent would undo it.
- **Sudo files:** one file in `sudoers.d`, as
  `.agents/skills/hostwarden-deploy-user/references/harden.md` →
  Restricted Sudo writes one: backed up, checked with
  `visudo -c -f`. Name it without a `.`, which `@includedir`
  would skip, then run `visudo -c` for the whole set, since a
  sudo older than 1.9.3 refuses to run at all with an error
  anywhere in it; confirm with `sudo -l -U <user>`.

## Team Accounts

A few people who rarely change, a user CA the user runs, no
directory: the same local account on every host, created once as
root, the principal equal to the account name, which
`AuthorizedPrincipalsFile none` admits (Certificate Logins). The
person, and Hostwarden for them (`rules/ssh-user.md`), work as
that account; root stays for break-glass.

- **Roster** under `## Team accounts` in `memory/network.md`,
  one line per person: `- alice: uid 1101, gid 1101, groups
  sudo`. The same UID and the same GID for the person's own group
  on every host, free where `getent passwd <uid>` and
  `getent group <gid>` print nothing, and outside any directory or
  identity-provider range.
- **Create** per host as Changes Across Hosts says: the person's
  own group with the roster's GID, the account in it and in the
  sudo group a rule on that host names, a shell the host has, and
  no password (`rules/accounts-probe.md` → Local Accounts). Linux,
  then FreeBSD, then Alpine, whose busybox tools stand in where
  the `shadow` package is missing:

  ```bash
  groupadd -g <gid> <name> && useradd -m -u <uid> -g <name> \
    -G <group> -s <shell> -c "<Full Name>" <name> && id <name>
  pw groupadd <name> -g <gid> && pw useradd <name> -m -u <uid> \
    -g <name> -G <group> -s <shell> -c "<Full Name>" -w no && id <name>
  addgroup -g <gid> <name> && adduser -D -u <uid> -G <name> \
    -s <shell> -g "<Full Name>" <name> && addgroup <name> <group> \
    && id <name>
  ```

  Where sshd runs without PAM, as on Alpine, the new account's
  `!` locks it out of key and certificate logins too: set `*`
  with `echo '<name>:*' | chpasswd -e`. macOS accounts come from
  the Mac's own management; Hostwarden does not create them. Then
  a fresh login with that person's certificate.
- **Remove:** the user revokes the person's certificates at the
  CA, or in the hosts' revocation list (`rules/ssh-ca.md` →
  Terms), then
  per host `userdel <name>` (`pw userdel` on FreeBSD, busybox
  `deluser` on Alpine). The home stays unless the user wants it
  gone (`-r`; `--remove-home` for `deluser`). Update the roster.
