# SSH Passwords

Some devices take no SSH key: DrayTek Vigor routers
(`rules/appliance/drayos.md`), many switches, some appliances.
Hostwarden logs in to them with a password that neither the session
nor this conversation ever sees. ssh asks `bin/hostwarden-askpass`
for it, and the helper reads it from where the user put it and
hands it to ssh through a pipe.

A password is only for a host no key or certificate can log in to.
Where the host takes one, say so, and offer to install the key for
the account instead (`rules/accounts.md`). The scripts hold to this
themselves: `bin/hostwarden-password` asks the host which login
methods it offers, with a login by the method none that
authenticates nothing (the call `rules/host-keys.md` uses), and
refuses `set`, `link` and `check` for a host that offers
`publickey`, or neither `password` nor `keyboard-interactive`. Only
the target's own refusal counts, never a jump host's.
`bin/hostwarden-askpass` gives no password without such an answer
from the last 30 days, and
`check` asks the host again once its answer is a week old: a
firmware that learns keys ends the password logins. Never work
around a refusal; the answer is a key.

## When It Applies

- The user says the host takes only a password.
- A first call ends in `Permission denied` whose list names
  `password` or `keyboard-interactive` and no `publickey`, as in
  `Permission denied (password).`: the server offers no key login.
  Ask the user whether the host really takes no key before setting
  anything up. Never switch a host to a password on your own.

A `Permission denied` that lists `publickey` means the host takes
keys and this one was not accepted: `rules/ssh-unreachable.md`, not
this file.

## Setting Up a Host

1. **Ask where the password lives**, in the interview format of
   `rules/ssh-user.md`: *"Where should Hostwarden take the password
   for `<user>@<host>` from?"* Three options:
   1. **This machine (recommended)** — stored here, in the macOS
      keychain, elsewhere in an encrypted file. Only Hostwarden's
      own passwords are in reach.
   2. **1Password**, through a service account of its own.
   3. **Bitwarden or Vaultwarden**, through an account of its own.

   A password manager is never the default, and never the user's
   own login: Passwords in a Manager below comes first.

   The login is the one `rules/ssh-user.md` recorded for the host.
   A second account on the same host is a second login with a line
   of its own; each is set up the same way.
2. **The host block.** Add the host's block to `memory/ssh_hosts`
   (`rules/ssh-config.md` → Adding a Block) with these lines under
   its `Host` line, then run `bin/hostwarden-ssh-config`:

   ```
   Host rtr1 rtr1.example.com
     BatchMode no
     PubkeyAuthentication no
     PreferredAuthentications password
     NumberOfPasswordPrompts 1
   ```

   `BatchMode no` lets ssh ask the helper; every other host keeps
   `BatchMode yes` from the standard options, and ssh never asks
   there. `PubkeyAuthentication no` sends no key the host would
   count as a failed login. `PreferredAuthentications` names one
   method, `password`, or `keyboard-interactive` where the host's
   `Permission denied` list names only that: ssh counts each
   method's prompts apart, so with both a wrong password would go
   out twice per call. `NumberOfPasswordPrompts 1` then tries it
   once per call. A block the host already has gets the four lines
   added.
3. **The password.** By the answer to step 1:
   - **This machine.** Give the user the command to run in a
     terminal of their own. It asks twice, echoes nothing, and
     writes the line in `memory/user.md` itself:

     ```bash operator
     bin/hostwarden-password set admin@rtr1
     ```

     Run from the checkout. A command Claude Code runs with `!`
     has no terminal to ask in; the script refuses without one.
   - **1Password.** The entry lives in the vault the service
     account sees (Passwords in a Manager), and gets a text field
     named `hostwarden` that holds the target exactly as
     `bin/hostwarden-password check admin@rtr1` prints it in
     parentheses, `admin@192.0.2.1:22`. The account's token goes
     into this machine's store, by the user, in a terminal of their
     own:

     ```bash operator
     bin/hostwarden-password token 1password
     ```

     Then, with the reference the user gives:

     ```bash
     bin/hostwarden-password link admin@rtr1 '1password op://Hostwarden/rtr1/password'
     ```

     `link` refuses a token that sees more than one vault, or a
     reference to another vault, then reads the entry's
     `hostwarden` field and nothing else, and records the line
     only where it names the target. Without a token 1Password is
     not used at all: its app would open every vault of the user.
   - **Bitwarden or Vaultwarden, through rbw.** rbw is the
     unofficial client whose agent holds a vault unlocked for a
     while, and `RBW_PROFILE` keeps an account apart from the
     user's own. The user sets the profile up for the Hostwarden
     account, in a terminal of their own, and unlocks it with that
     account's master password when it locks:

     ```bash operator
     RBW_PROFILE=hostwarden rbw config set email hostwarden@example.com
     RBW_PROFILE=hostwarden rbw config set base_url https://vault.example.com
     RBW_PROFILE=hostwarden rbw unlock
     ```

     `base_url` only for a server of the user's own. The entry's
     user name is the SSH user, and it gets a custom field named
     `hostwarden` holding the target; no other field of it may have
     `hostwarden` in its name, since rbw matches field names by
     substring. Link it as `rbw <profile>/<item name>`,
     `rbw hostwarden/rtr1`. The helper refuses a locked vault rather
     than prompt.
   - **Bitwarden Secrets Manager**, `bws`, on Bitwarden's own
     servers only (Vaultwarden has none): a secret whose name is the
     target and whose value is the password, in a project a machine
     account may only read. Its access token goes in with
     `bin/hostwarden-password token bws`, by the user. Link it as
     `bws <secret id>`. It needs `jq`.
4. **Memory.** Add `- SSH login: password (<why no key>)` to the
   host's `memory.md`, such as
   `- SSH login: password (DrayOS takes no key)`. The line is
   shared; the source of each login stays in `memory/user.md`,
   which is personal (`rules/machine-memory.md` → Personal versus
   shared).
5. **Check** with `bin/hostwarden-password check admin@rtr1`, then
   go on with the pipeline (`rules/first-connection.md`).

## Passwords in a Manager

A session that can reach a password manager can read whatever the
identity it goes through can read. So a manager is used only
through an identity that sees Hostwarden's entries and nothing
else, and only on the user's explicit decision:

1. **Say what is at stake**, before anything is set up: through the
   user's own login, every entry of every vault would be in reach
   of this session and of anything that takes it over; a password
   on this machine puts only Hostwarden's own in reach.
2. **Name what the identity has to be**, by manager:
   - **1Password:** a vault kept for Hostwarden alone, holding only
     the SSH entries, and a service account with read access to
     that vault and no other. 1Password gives a service account
     vaults whole, never single entries, so a vault shared with
     anything else puts that in reach too.
   - **Bitwarden or Vaultwarden:** an account of its own for
     Hostwarden, a member of an organization with read access to
     one collection holding only the SSH entries, reached through
     an rbw profile of its own. Vaultwarden keeps collections apart
     from 1.35.3 on (CVE-2026-26012); on an older server every
     member reads the whole organization, so ask for the version
     and refuse below it. "Hide passwords" on a collection is no
     boundary: rbw reads the password all the same.
   - **Bitwarden Secrets Manager:** a machine account with read
     access to one project holding only these secrets.
3. **Ask for the decision**, in the interview format of
   `rules/ssh-user.md`: *"Take SSH passwords from `<manager>` only
   through an identity that sees nothing but Hostwarden's entries —
   is it set up that way?"* Options: **Yes, set up that way**,
   **Not yet — take the password on this machine**, **No manager**.
   Only the first goes on; never set a manager up on a hedged
   answer.
4. **Record it** as a decision for the workspace
   (`rules/decisions.md` → Writing one), with the identity and what
   it sees: `Decided: SSH passwords from 1Password through the
   service account hostwarden-ssh, which reads the vault Hostwarden
   only`.

`bin/hostwarden-password` holds to what it can check: 1Password
only through a stored service account token that sees exactly one
vault, the one the reference names; rbw only through a named
profile that is set up. What an rbw account's collections hold, it
cannot see; that rests on the decision. Where a check or the
decision no longer holds — a token that sees a second vault, an
answer that the account sees more — stop using the manager for
Hostwarden and say so.

## Every Connection

- Before the session's first call to a host whose memory has
  `SSH login: password`, run `bin/hostwarden-password check
  <user>@<host>`. Where it reports none, the password was set up on
  another machine: give the user the command for this one (Setting
  Up a Host, step 3) and wait. It reads no password, and for a
  password manager only the entry's `hostwarden` field. Where it
  says the host offers key logins, the host takes a key now: tell
  the user, offer the key (`rules/accounts.md`), and log in by
  password no more.
- The calls are the ordinary ones, `ssh -F …`
  (`AGENTS.md` → SSH Options). Claude Code's session start
  exports `SSH_ASKPASS` and `SSH_ASKPASS_REQUIRE=force` for every
  Bash call. A tool without hooks starts each call to such a host
  with them, and nothing else changes:

  ```bash
  SSH_ASKPASS=/srv/hostwarden/bin/hostwarden-askpass SSH_ASKPASS_REQUIRE=force \
    ssh -F "/srv/hostwarden/memory/ssh_config" admin@rtr1 …
  ```

  `/srv/hostwarden` stands for the checkout.
- Connection sharing keeps one login open for ten minutes
  (`rules/ssh-connections.md`), so the password is asked once for
  a round of calls, not once per call.
- A jump host that takes only a password is one more login, set up
  the same way.

## A Password Refused

`Permission denied` once is the end of it: never repeat the call,
never try another user or root. Many such devices lock an account
after a few failures, and the helper answers at most three times
per target in 15 minutes for that reason. Tell the user the
password was refused, and give the command to set or link it again.
Where the helper itself refused, its message on stderr names why:
no password stored, a source that does not name the target, a
locked manager, an ssh call with other options. A refusal ends the
ssh process too, so no empty password goes to the host: ssh would
send one where its askpass fails, and the host would count it as a
failed login. A manager that answers too slowly is such a refusal,
not a failed login.

## Never

- Never ask for the password in the conversation. One the user
  pastes is `rules/secrets.md` → Secrets the User Pastes Into Chat;
  offer `set` for next time.
- Never read a stored password or token: not by running
  `bin/hostwarden-askpass`, a password manager's read command
  (`op`, `rbw get`, `bws secret get`, `bw get`), `security` with
  `-w` or `-g`, `secret-tool lookup`, nor by reading the files
  under `~/.local/share/hostwarden/passwords` or
  `~/.config/hostwarden/password-key`. The taboo guard denies the
  commands where it runs.
- Never hand ssh a password another way: no `sshpass`, no password
  in an argument, an environment variable or a here-document, and
  no `SSH_ASKPASS` other than `bin/hostwarden-askpass`.
- Never add an option to a password call that changes how the host
  key is checked or how the connection is made
  (`StrictHostKeyChecking`, `UserKnownHostsFile`, `ProxyCommand`,
  …): the helper then gives no password and ends the call, since it
  could reach a host whose key was never verified.
- Never write a password, a token or part of one into memory, a
  report or a changelog. Memory records where it comes from.

## What the Protection Is

- The helper answers only a password prompt from an ssh process
  that is its parent, started with this checkout's
  `memory/ssh_config`, and only for the target that process logs
  in to: the user, HostName and Port ssh resolved, read from ssh
  itself. A HostName changed in `memory/ssh_hosts` finds no
  password, and a password manager's entry that does not name the
  target gives none.
- A password in this machine's store is encrypted at rest, by the
  keychain or with a key kept in a different directory from the
  files. That keeps it out of a backup, a sync or a commit.
  Anything running as the user can still read it, without a
  prompt; what keeps this session from doing so is the guard and
  this file. What is in reach is Hostwarden's own passwords: the
  keychain asks the user before another program's entry is read.
  A Linux desktop's Secret Service is no store here, since it
  hands every entry of an unlocked keyring to any process of the
  user.
- sudo is not covered: a password host whose commands need root
  logs in as root, or the work runs unprivileged
  (`rules/privilege-escalation.md`).

## Removing

`bin/hostwarden-password remove <user>@<host>` deletes the stored
password, where this machine holds one, whatever the line names,
and the line in `memory/user.md`; a password manager's entry stays. Once the
host takes a key, remove the four lines from its block in
`memory/ssh_hosts` and its `SSH login:` line.
