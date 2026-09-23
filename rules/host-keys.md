# Host Keys

Every SSH, scp and rsync call checks the host's key against
`memory/known_hosts` in the workspace and against nothing else
(`AGENTS.md` → SSH Options). This file says how a key gets
there, what a changed key means, and how the file is kept. No
one has to log in by hand first.

## The File

- **OpenSSH's own format**, read by `ssh` directly: a list of
  names, the key type and the key, one key per line
  (`man sshd` → SSH_KNOWN_HOSTS FILE FORMAT).
  `@cert-authority` and `@revoked` lines work as that page
  describes. A missing file counts as empty.
- **Shared in team mode** (`rules/server-memory.md` → Personal
  versus shared). A key recorded once serves every machine and
  every teammate, and the workspace's history says who added
  which key and when.
- **Every entry starts with a comment line:**
  `# <date> <names>: <source>`. The sources are the ones
  Getting a Key and DNS Aliases below name:
  `pct exec 105 on pve1.example.com`,
  `imported from ~/.ssh/known_hosts on <workstation>`,
  `first use`, `console (user)`, `alias of web1.example.com`.
- **Written by a command, never typed.** A key copied out of
  the conversation by hand is one wrong character away from
  locking the host out, or from trusting the wrong one. Every
  write goes through a file in `~/.cache/hostwarden/`, named
  `hostkey.<name>`, and reaches `memory/known_hosts` only after
  `ssh-keygen -lf` has parsed it, with an `@revoked` marker taken
  off for the check only: `-lf` rejects a marked line. Delete it
  once it has been appended.
- **Committed like every workspace file**, by its path
  `memory/known_hosts` (`rules/parallel-sessions.md` → The
  workspace). Another session may have appended lines of its own.

The workspace's own git remote is not a managed host. Git
checks its key against the user's own known_hosts, as it always
does.

## Before the First Connection

The end of step 4 of `rules/first-connection.md`, once per host
and session, with no connection to the host. `ssh -G
<user>@<host>`, run without Hostwarden's options, prints the name
ssh looks the key up by: its `hostkeyalias` line where there is
one, else its `hostname` line. Off port 22, the name is
`[<name>]:<port>`, with the port from the same output. Look it
up:

```bash
ssh-keygen -F web1.example.com -f "/srv/hostwarden/memory/known_hosts"
```

`/srv/hostwarden` stands for this checkout's absolute path here
and below, the `<checkout>` of `AGENTS.md` → SSH Options. Any
output, a plain key or a line marked `CA`, means the host is
known: connect. No output means Getting a Key comes first, or DNS
Aliases for a name the DNS check has just found to be an alias.

## Getting a Key

Take the first source that applies. Each one writes a comment
line and the key lines, as The File says. The names are every
name the host is reached by, each as ssh looks it up: the name
from Before the First Connection, and the FQDN and the `- IP:`
addresses in its memory. Leave out a name that already has a key
or falls under a `@cert-authority` line. A name whose recorded
key differs is A Changed Key, and nothing is written for it.

### 1. Through a host that is already verified

A guest whose `Runs on:` names its host, where the host's
manager can enter it (`rules/system-containers.md` → Reaching
It, which also says how to read `qm guest exec`'s answer). The
connection to the host was itself checked against the file, so
what it carries is as trustworthy as the host. Read the public
key inside the guest, in one call on the host, into the cache
file:

```bash
ssh … root@pve1.example.com \
  'pct exec 105 -- cat /etc/ssh/ssh_host_ed25519_key.pub' |
  while read -r type key _; do
    echo "web2.example.com,192.0.2.22 $type $key"
  done > ~/.cache/hostwarden/hostkey.web2.example.com
```

Where `ssh_host_ed25519_key.pub` is missing, read
`ssh_host_ecdsa_key.pub`. Then, in a call of its own (a line
that names a host key and deletes a file is one the taboo guard
refuses):

```bash
f=~/.cache/hostwarden/hostkey.web2.example.com
[ -s "$f" ] && sed 's/^@revoked //' "$f" | ssh-keygen -lf - &&
  { echo "# $(date +%F) web2.example.com: pct exec 105 on pve1.example.com"
    cat "$f"; } >> "/srv/hostwarden/memory/known_hosts"
rm -f "$f"
```

An empty file or one `ssh-keygen` rejects writes nothing: report
it and go on to the next source. A run that records several
guests fills every cache file first, then appends them all in one
call and commits once.

### 2. The user's own known_hosts

The files the same `ssh -G` output names on its
`userknownhostsfile` and `globalknownhostsfile` lines: the
user's own configuration, so these keys are the trust the user
already had on this machine. Read each file with `ssh-keygen -F`
only:

```bash
ssh-keygen -F web1.example.com -f ~/.ssh/known_hosts |
  grep -v -e '^#' -e '^@cert-authority' \
  > ~/.cache/hostwarden/hostkey.web1.example.com
```

Then append as in source 1, with
`imported from ~/.ssh/known_hosts on <workstation>` as the
source, where `<workstation>` is `hostname -s`. No question; say
in one line what was imported. A hashed line stays hashed and
still matches, and a `@revoked` line comes along as it is. A
`@cert-authority` line, which the filter above leaves out, trusts
every host its pattern names, for the whole team: where the lookup
prints one, show the pattern and ask before importing it.

### 3. Ask

Where neither applies, ask as `rules/ssh-user.md` → Interview
format says, with these options:

```
<host> is not in memory/known_hosts, and no verified host or
known_hosts file of yours has its key. How should Hostwarden
trust it?

  1. accept on first use     (every later connection is checked)
  2. compare with console    (you read the fingerprint first)
  3. stop                    (connect to nothing)

[1/2/3]:
```

For option 2, the user reads the fingerprint at the host's
console:

```bash operator
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

A cloud VM's console output has it too, between
`-----BEGIN SSH HOST KEY FINGERPRINTS-----` and the matching
`END` line, which cloud-init prints at its first boot.

A run that created or reinstalled the host itself
(`hostwarden-new-guest`, `hostwarden-os-install`) and has no
session inside it to read the key through takes option 1 without
the question, and says so in one line.

For options 1 and 2, one fresh login records the key the host
offers into the cache file. The options in front replace the
standard options' sharing, known_hosts files and check, since ssh
keeps the first value it sees; a shared connection would skip the
key exchange and record nothing. The cache file comes first,
because ssh writes a new key into the first file, and the
workspace's second, so an `@revoked` line there still refuses the
key (`was revoked`: stop and tell the user):

```bash
ssh -o ControlMaster=no -o ControlPath=none \
  -o 'UserKnownHostsFile=~/.cache/hostwarden/hostkey.web1.example.com "/srv/hostwarden/memory/known_hosts"' \
  -o StrictHostKeyChecking=accept-new -o HashKnownHosts=no \
  <standard options> root@web1.example.com true
ssh-keygen -lf ~/.cache/hostwarden/hostkey.web1.example.com
```

For option 2, compare the printed fingerprint with the user's. A
mismatch writes nothing: delete the cache file, tell the user
both fingerprints, and connect to nothing.
Otherwise append as in source 1, with `first use` or
`console (user)` as the source, and report the fingerprint in one
line.

An override may remove option 1 (`rules/overrides.md`).

## A Changed Key

`REMOTE HOST IDENTIFICATION HAS CHANGED`, or `Host key for
<name> has changed`, from any call: stop.

- Change nothing: no line removed, no retry with other options,
  no other name or address tried.
- Tell the user the name, the line ssh names as offending in
  `memory/known_hosts`, and the fingerprint the host offered,
  which the same message prints. A reinstall, a guest restored
  from a backup and a cloned guest are the harmless causes. None
  of them may be assumed.
- Replace the key only on the user's word: remove the host's
  names as below, then get the new key from source 1 or 3 of
  Getting a Key. Never from source 2: the user's own file holds
  the old key. Note the replacement in the host's changelog. A
  shared connection opened before keeps running on the old
  check; the access test afterwards uses the fresh-login options
  (`rules/ssh-connections.md`).

## Removing Names

For a replaced key, a removed DNS alias, and a host whose memory
directory is removed, with its aliases:

```bash
ssh-keygen -R web1.example.com -f "/srv/hostwarden/memory/known_hosts" &&
  rm -f "/srv/hostwarden/memory/known_hosts.old"
```

`-R` removes each whole line that names the host, other names on
it included, and leaves `@cert-authority` lines alone. For an
alias, check with `ssh-keygen -F` first: a line that also names
the canonical host stays, so run `-R` only where the alias has
lines of its own.

## Host Certificates

A `@cert-authority` line covers every host whose name matches
its pattern and whose certificate that CA signed. Such a host
needs no line of its own. Hostwarden reads these lines and never
proposes a CA: not in a finding, not in the baseline, not in a
recommendation. Whether to run one is the user's decision, as
configuration management is (`rules/config-management.md`).

`Host key verification failed` on a name a CA line covers points
at the certificate: expired because its renewal stopped, or not
naming this host among its principals. The single retry with the
fresh-login options and `-v` (`rules/ssh-unreachable.md`) shows
which. That is a finding for the host, reported in one line. Get
a plain key for it only when the user asks.

## DNS Aliases

A name `rules/dns-aliases.md` has just found to be an alias of a
known host, before it writes the alias into memory, and that
Before the First Connection does not find: connect once with the
standard options plus
`-o HostKeyAlias=<the canonical host's name>`, the name its
Before the First Connection lookup uses. A key that verifies
proves the alias better than the matching address did. Then
give the alias lines of its own, copied from the canonical
host's plain lines:

```bash
ssh-keygen -F web1.example.com -f "/srv/hostwarden/memory/known_hosts" |
  grep -v '^[#@]' |
  while read -r _ type key _; do
    echo "www.example.com $type $key"
  done > ~/.cache/hostwarden/hostkey.www.example.com
```

Append them as in source 1, with `alias of web1.example.com` as
the source. Where the canonical host has only a CA line, copy
nothing: the alias is outside that line's pattern, or the lookup
would have found it, so it gets a key of its own through Getting
a Key.

A key that does not verify under `HostKeyAlias` is a different
machine behind the same address: stop and tell the user, as for
a changed key.

## Jump Hosts

Options on the command line do not reach a `ProxyJump` host
(`man ssh` → `-J`), so it would be checked against the user's
own known_hosts. Reach a jump host with `ProxyCommand` instead,
so the standard options apply to both:

```bash
ssh <standard options> \
  -o ProxyCommand="ssh <inner options> -W %h:%p root@jump.example.com" \
  root@web1.example.com
```

The inner options are the standard options with two spellings
changed, because the command passes through the outer ssh's `%`
expansion and a second shell:

- the `ControlPath` as `~/.cache/hostwarden/ssh-<id>-%%C`: the outer
  ssh knows no `%C` there (`unknown key %C`), and `%%` reaches the
  inner ssh as `%`;
- the known_hosts file as
  `-o 'UserKnownHostsFile=\"<checkout>/memory/known_hosts\"'`: the
  escaped quotes survive the outer double quotes and keep a path
  with a space in one piece for the inner ssh.
