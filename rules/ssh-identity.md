# SSH Identity

Hostwarden can log in with an SSH key of its own instead of the
admin's: one key per operator and workstation, named
`hostwarden@<operator>-<workstation>`, whose fingerprint sshd writes
into every host's log with each login. Its logins can then be told
apart from the admin's, counted, and revoked on their own.

Recommended, never required. Without an `SSH identity:` line in
`memory/user.md`, or with `SSH identity: none`, every call runs as
it does without this file, and nothing below applies.

## What Holds

The session runs as the same OS user as the admin. Only what acts
outside it holds:

- A password manager's agent, an agent loaded with `ssh-add -c`, or
  a hardware key asks a human before a key signs. A prompt the
  admin did not expect is the sign that something used their key.
- sshd enforces each key's `authorized_keys` options and logs its
  fingerprint.
- `ssh-agent` never hands a private key out, and `ssh-add -t` ends
  its use after the lifetime.

The rest is a backstop against mistakes, not against a determined
reader: the lines `bin/hostwarden-ssh-config` writes into
`memory/ssh_config`, and the taboo guard's denials (Every
Connection below), which stop a call copied from somewhere with
`-i` in it, never a program that reads the same files as the user
(`docs/adr/20260924-guard-is-a-backstop-not-a-sandbox.md`).

`IdentityFile` lines add up across the user's own configuration,
which `memory/ssh_config` includes, so a key file without a
passphrase named there is still offered, and its private half is
readable by the session. An encrypted key file is never offered:
`BatchMode yes` stops ssh from asking for its passphrase, and
`bin/hostwarden-askpass` answers no passphrase prompt.

The only isolation of the workstation itself is a separate OS user
or a sandbox for the session, which cannot read the admin's files
and sockets. Hostwarden builds neither.

## The Setup Question

Asked once, in an interactive operations session about to reach a
machine, where `memory/user.md` has no `SSH identity:` line, after
the SSH user interview (`rules/ssh-user.md`). An unattended session
asks nothing and runs as it does without an identity.

Say what is at stake first, in two lines: today every host logs
Hostwarden's logins under the admin's key, and anything that takes
the session over can use that key; a key of its own is told apart
in every log and can be revoked alone.

Then ask, in the interview format of `rules/ssh-user.md` with four
options instead of three, each with what it needs and its interim,
none marked as recommended: the right one depends on what the user
already has and what they want. Option 1 comes first, as the
default. *"Should Hostwarden log in with an
SSH key of its own, and where should it live?"*

1. **Its own agent (the default).** An `ssh-agent` on
   `~/.cache/hostwarden/agent.sock`, holding Hostwarden's key and
   nothing else, for a lifetime, 8 hours unless the user names
   another. The key comes from Hostwarden's vault, through the
   identity `rules/ssh-passwords.md` → Passwords in a Manager
   describes, or from an encrypted key file the user unlocks in a
   terminal of their own. No agent of the user's holds
   Hostwarden's key; the user's own agent stays as reachable as
   before, only no longer offered to the hosts that carry
   Hostwarden's key. Interim: a load each working day.
2. **The password manager's agent.** The key sits in 1Password or
   Bitwarden beside the admin's, and `IdentitiesOnly` picks it.
   This cannot be confined: 1Password's `agent.toml` and
   Bitwarden's agent apply to the whole agent, so a session that
   reaches the socket can ask for a signature with the admin's keys
   too. What holds is the manager's approval prompt.
3. **A hardware key of its own** (`ed25519-sk`), in Hostwarden's
   own agent, touched for each new connection: connection sharing
   makes that once per host per ten minutes
   (`rules/ssh-connections.md`).
4. **Not now.** Records `SSH identity: none`.

The answer is not asked again; the user names a change when they
want one.

## Setting It Up

The user makes the key. The public key lies at
`~/.ssh/hostwarden_ed25519.pub` (`hostwarden_ed25519_sk.pub` for a
hardware key) unless the user names another path. Its comment is
`hostwarden@<operator>-<workstation>`, `<operator>` as
`rules/ssh-user.md` → Operator defines it and `<workstation>` as
`hostname -s` gives it, lower case; `bin/hostwarden-identity line`
prints it.

1. **The key**, by the answer:
   - **Its own agent, from a key file.** The user runs, in a
     terminal of their own, with a passphrase:

     ```bash operator
     ssh-keygen -t ed25519 -C hostwarden@alice-ws1 -f ~/.ssh/hostwarden_ed25519
     ```

   - **Its own agent, from the vault.** The vault and its identity
     are the ones `rules/ssh-passwords.md` → Passwords in a Manager
     names, decided and recorded the same way, before anything
     here. In 1Password, an SSH key item in that vault, with a text
     field named `hostwarden` holding the comment; the source is
     the reference to its private key in OpenSSH format,
     `op://Hostwarden/hostwarden-ssh/private key?ssh-format=openssh`.
     In Bitwarden Secrets Manager, a secret whose name is the
     comment and whose value is the private key; the source is
     `bws <secret id>`. The user saves the public key to the path
     above. rbw is no source here: it reads an entry's password,
     not a key.
   - **The password manager's agent.** The user creates the key in
     the manager and saves its public key to the path above. The
     agent's socket is the manager's own: 1Password
     `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
     on macOS, `~/.1password/agent.sock` on Linux; Bitwarden
     `~/.bitwarden-ssh-agent.sock`, or the path its settings show
     for an App Store, Snap or Flatpak install.
   - **A hardware key.** The user runs, with the key plugged in:

     ```bash operator
     ssh-keygen -t ed25519-sk -C hostwarden@alice-ws1 -f ~/.ssh/hostwarden_ed25519_sk
     ```

2. **Record it** in `memory/user.md`, which is personal
   (`rules/machine-memory.md` → Personal versus shared), under a
   heading of its own, each line once, unindented:

   ```markdown
   # SSH Identity

   SSH identity: own-agent
   SSH identity key: ~/.ssh/hostwarden_ed25519.pub
   SSH identity agent: ~/.cache/hostwarden/agent.sock
   SSH identity source: file ~/.ssh/hostwarden_ed25519
   ```

   `SSH identity:` is `own-agent`, `manager`, `hardware` or `none`.
   The key is the public key. The agent is a socket path, absolute
   or starting with `~/`. The source is `file <path>`,
   `1password <reference>` or `bws <secret id>` for its own agent,
   the key's file for a hardware key, and absent for the manager's
   agent. An `SSH agent socket:` line stays
   (`rules/ssh-agent.md` → Precedence).
3. **Load it**, for its own agent and a hardware key:
   `bin/hostwarden-identity load`, `-t <lifetime>` for another
   lifetime than 8 hours. From the vault, it needs no terminal: run
   it. From a file or a hardware key, it asks for the passphrase or
   the touch: give the user the command for a terminal of their
   own, run from the checkout. It refuses a key file without a
   passphrase.
4. **Check** with `bin/hostwarden-identity check`, which prints the
   fingerprint.

## Putting the Key on a Host

The operator adds the line Hostwarden prints, as for fleet read.

1. Print the line for the host:

   ```bash
   bin/hostwarden-identity line web1.example.com
   ```

   `--from <addresses>` adds `from=`, for a workstation whose
   address the host sees as a fixed one; `--until <YYYYMMDD>` adds
   `expiry-time=`, for an end date. Give the user the line and the
   account it is for: the one `memory/user.md` records for the host.

   ```
   restrict,port-forwarding,pty ssh-ed25519 AAAA… hostwarden@alice-ws1
   ```

   `restrict` turns off every forwarding, the terminal, X11 and
   `~/.ssh/rc`. `port-forwarding` brings back what
   `rules/ssh-config.md` → Port Forwardings adds to a shared
   connection, and `pty` what `ssh -t` needs, such as
   `netplan try`. Leave either out where the user asks; say what
   then fails.
2. **Once the operator says it is added**, add the host's line to
   its `memory.md` and run `bin/hostwarden-ssh-config`:

   ```markdown
   - Hostwarden key: SHA256:4W9k… (hostwarden@alice-ws1, 2026-10-21)
   ```

   The fingerprint is the one `bin/hostwarden-identity check`
   prints. From then on `memory/ssh_config` offers that key and
   no key of the user's agent to this host, by every name its
   memory gives it (directory, `Reached as:`, FQDN, IP, DNS aliases)
   and every `memory/ssh_hosts` name whose block has this host's
   name or address as its HostName; a name whose block points to
   another HostName is not this host's. A key file the
   user's own configuration names is still tried (What Holds). The
   line goes in before the test below because the test needs it:
   offering the key any other way takes `-i` or `-o IdentityFile`,
   which the guard denies.
3. **Test it with one fresh login** (`rules/ssh-connections.md` →
   Fresh-login options): a shared connection keeps the key it
   logged in with until it ends.

   ```bash
   ssh -F "/srv/hostwarden/memory/ssh_config" -o ControlMaster=no \
     -o ControlPath=none root@web1.example.com true
   ```

   A `Permission denied` means the line is not where sshd reads it:
   take the `Hostwarden key:` line out again, run
   `bin/hostwarden-ssh-config`, and tell the user. Never repeat the
   call: each refusal is a failed login (`rules/ssh-connections.md`
   → Avoid failed logins).

The line is shared, one per identity: in a shared workspace each
person's key gets its own. A host without one for this identity
keeps the keys it has today, and the audits report it.

A new guest gets Hostwarden's key among its first-boot keys
(`hostwarden-new-guest` → Admin keys), beside a key the session's
agent holds, never alone: the guest's first login comes before its
memory exists, and `memory/ssh_config` offers Hostwarden's key only
to a host whose memory records it. The guest's `Hostwarden key:`
line follows once it is registered, as in steps 2 and 3; the
operator may then take the other key out.

## Every Connection

- Before the session's first call to a host whose memory has this
  identity's `Hostwarden key:` line, the doctor's line from the
  session start counts (`rules/session-start.md` → Workstation
  tools). Where it said the agent does not answer or does not hold
  the key, load it first (Setting It Up, step 3), or wait for the
  user to. A call made anyway is refused, and counted.
- Every call is the ordinary one, `ssh -F …` (`AGENTS.md` → SSH
  Options). The taboo guard denies an
  ssh, scp or sftp call, an `rsync -e "ssh …"`, and an rsync to a
  remote without one, that carries `-i`, `-A`,
  `-o IdentityFile`, `-o IdentityAgent` or `-o IdentitiesOnly`, or
  that has no `-F` naming this checkout's `memory/ssh_config`, and
  any command that names a private key `~/.ssh/id_*` without
  `.pub`. The one call allowed with `-F /dev/null` is a control
  command to a shared connection by its socket (`-S` with
  `-O forward`, `cancel`, `check` or `exit`), which logs in nowhere.
  Git keeps its own route to ssh and the admin's key. Where the
  guard does not run, this list is the rule.
- No `SSH_AUTH_SOCK` in the session's environment changes: the
  identity reaches ssh through `memory/ssh_config` alone, and Git
  and `bin/hostwarden-sync` keep the user's own agent.

## Audits

`hostwarden-security` and `hostwarden-fleet-audit` count the key
logins of each host by fingerprint and name Hostwarden's among
them by the host's `Hostwarden key:` lines; on macOS and Windows,
`not checked`.
The probe reads sshd's log with `$SUDO` from the privilege prefix
(`rules/privilege-escalation.md` → Stand-ins for sudo), empty for
root; without either, the count is `unknown(needs-root)`:

```sh
if [ "$SUDO" = - ]; then echo 'unknown(needs-root)'; else
  P='log files since their last rotation'
  L=$($SUDO journalctl -q --since '30 days ago' -o short-iso \
    SYSLOG_IDENTIFIER=sshd SYSLOG_IDENTIFIER=sshd-session 2>/dev/null)
  if [ -n "$L" ]; then
    P="journal, oldest sshd entry $(printf '%s\n' "$L" | head -n 1 | cut -d' ' -f1)"
  else
    L=$($SUDO cat /var/log/auth.log /var/log/secure \
      /var/log/messages 2>/dev/null)
  fi
  if [ -z "$L" ]; then echo 'unknown(no-log)'; else
    echo "period: $P"
    R=$(printf '%s\n' "$L" | grep 'Accepted publickey for ' |
      awk '{ u = ""; f = ""
        for (i = 1; i < NF; i++) if ($i == "for") { u = $(i + 1); break }
        for (i = 1; i <= NF; i++) if ($i ~ /^SHA256:/) { f = $i; break }
        print u, f }' | sort | uniq -c)
    echo "${R:-none}"
  fi
fi
```

A first line, `period:`, names what was read: the journal's oldest
sshd entry within the last 30 days, which is not the journal's own
start (a quiet sshd, a volatile or capped journal), or the log
files back to their last rotation. Then one line per account and key: the count,
the account and the key's fingerprint, the first `SHA256:` of the line, which
for a certificate login is the key's and not the CA's. `none` is a
log read with no key login in it; `unknown(no-log)` is no log
found, the journal empty and none of the files there, which is
never reported as no logins (`rules/verify-before-reporting.md`).
`unknown(...)` stands alone, without a `period:` line. The report
names the period.

- A host whose memory has a `Hostwarden key:` line for this
  identity: its logins under that key, and the others by account
  and fingerprint.
- A host without one, where `memory/user.md` records an identity:
  `no Hostwarden key` (INFO), with
  `bin/hostwarden-identity line <host>` for the line.
- Logins under a key nobody recorded are reported, not judged:
  other people and jobs log in too.

## Replacing or Removing It

- **A new key**: the user makes it and the four lines point at it;
  each host then goes through Putting the Key on a Host again, and
  the old key's `Hostwarden key:` line comes out with the new one's
  test; the operator removes the old line on the host.
- **A key that leaked**: the operator removes its line on every host
  first, then the `Hostwarden key:` lines come out and
  `bin/hostwarden-ssh-config` runs.
- **No identity any more**: `SSH identity: none`, the other three
  lines out, `bin/hostwarden-ssh-config`. The host lines stay until
  the operator removed the key there.

## Never

- Never write, edit or remove an `authorized_keys` line on a host:
  print it for the operator. The one exception is AGENTS.md's: the
  first-boot configuration of a guest that has never run
  (`hostwarden-new-guest`).
- Never create, copy, read or print a private key, the admin's or
  Hostwarden's, and never load the admin's key into Hostwarden's
  agent.
- Never reach a host with another key or agent to get past a
  refusal: a refused login under Hostwarden's key is a finding to
  tell the user about.
