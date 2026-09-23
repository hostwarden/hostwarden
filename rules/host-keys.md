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
  `imported from <files> on <workstation>`,
  `first use`, `console (user)`, `alias of web1.example.com`.
- **Written by a command, never typed.** A key copied out of
  the conversation by hand is one wrong character away from
  locking the host out, or from trusting the wrong one. Every
  write goes through a file in `~/.cache/hostwarden/`, named
  `hostkey.<name>`, and reaches `memory/known_hosts` only after
  `ssh-keygen -lf` has parsed it, with a leading `@` marker
  (`@revoked`, `@cert-authority`) taken off for the check only:
  `-lf` rejects a marked line. Delete it once it has been
  appended.
- **Committed like every workspace file**, by its path
  `memory/known_hosts` (`rules/parallel-sessions.md` → The
  workspace). Another session may have appended lines of its own.

The workspace's own git remote is not a managed host. Git
checks its key against the user's own known_hosts, as it always
does.

## Before the First Connection

The end of step 4 of `rules/first-connection.md`, once per remote
user, host and session, with no connection to the host.
`ssh -F "/srv/hostwarden/memory/ssh_config" -G <user>@<host>`
prints the name ssh looks the key up by: its `hostkeyalias` line
where there is one, else its `hostname` line. Off port 22, the
name is `[<name>]:<port>`, with the port from the same output. A
`proxyjump` line other than `none` names jump hosts, and each
needs its key first, looked up the same way as its own login
user (`rules/access-control.md` → Server Blacklist, Jump Hosts
below).
Another user on the same host, such as root for
`rules/privilege-escalation.md`, is looked up again: a
`Match user` block can give that user another endpoint, which
that file treats as another machine. Look it up:

```bash
ssh-keygen -F web1.example.com -f "/srv/hostwarden/memory/known_hosts"
```

`/srv/hostwarden` stands for this checkout's absolute path here
and below, the `<checkout>` of `AGENTS.md` → SSH Options. Any
output, a plain key or a line marked `CA`, means the host is
known: connect — except for a host whose `SSH host cert:` line
names a CA, which Host Certificates below checks first. No output
means Getting a Key comes first, or DNS Aliases for a name the DNS
check has just found to be an alias.

## Getting a Key

Take the first source that applies. Each one writes a comment
line and the key lines, as The File says. The names are every
name the host is reached by, each as ssh looks it up: the name
from Before the First Connection and the `- IP:` addresses in
its memory; its `- FQDN:` adds none (`rules/dns-aliases.md` →
The FQDN). Leave out a name that already has a key or falls
under a `@cert-authority` line. A name whose recorded key
differs is A Changed Key, and nothing is written for it.

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
[ -s "$f" ] && sed 's/^@[^ ]* //' "$f" | ssh-keygen -lf - &&
  { echo "# $(date +%F) web2.example.com: pct exec 105 on pve1.example.com"
    cat "$f"; } >> "/srv/hostwarden/memory/known_hosts"
rm -f "$f"
```

An empty file or one `ssh-keygen` rejects writes nothing: report
it and go on to the next source. A run that records several
guests fills every cache file first, then appends them all in one
call and commits once.

### 2. The user's own known_hosts

The files `ssh -G <user>@<host>`, run without `-F`, names on its
`userknownhostsfile` and `globalknownhostsfile` lines: the
user's own configuration, so these keys are the trust the user
already had on this machine. Read every one of them with
`ssh-keygen -F` only, one lookup per file, each appending to the
cache file: ssh checks a host against all of them together, and a
`@revoked` line in one refuses a key another holds. In one call,
empty the cache file first, since an interrupted option 2 below
can leave an unverified key in it; then give each file its own
lookup on its own line, never chained with `&&`, since `grep`
fails on a file without the host and would skip the rest, and
print the cache file's line count after each. A count that grows
names a file that gave lines; a missing file prints
`Cannot stat` and gives none. For the two default user files:

```bash
f=~/.cache/hostwarden/hostkey.web1.example.com
: > "$f"
ssh-keygen -F web1.example.com -f ~/.ssh/known_hosts 2>/dev/null |
  grep -v -e '^#' -e '^@cert-authority' >> "$f"
wc -l < "$f"
ssh-keygen -F web1.example.com -f ~/.ssh/known_hosts2 2>/dev/null |
  grep -v -e '^#' -e '^@cert-authority' >> "$f"
wc -l < "$f"
```

Then append as in source 1, with
`imported from <files> on <workstation>` as the source, where
`<files>` are the files that gave lines, comma-separated, and
`<workstation>` is `hostname -s`. No question; say
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
offers into the cache file. Its `-o` options win over the file's
sharing, known_hosts files and check; a shared connection would
skip the key exchange and record nothing. The cache file comes
first, because ssh writes a new key into the first file, and the
workspace's second, so an `@revoked` line there still refuses the
key (`was revoked`: stop and tell the user). The options do not
reach a jump host, which is checked as on every call:

```bash
ssh -F "/srv/hostwarden/memory/ssh_config" \
  -o ControlMaster=no -o ControlPath=none \
  -o 'UserKnownHostsFile=~/.cache/hostwarden/hostkey.web1.example.com "/srv/hostwarden/memory/known_hosts"' \
  -o StrictHostKeyChecking=accept-new -o HashKnownHosts=no \
  -o PreferredAuthentications=none -o ForwardAgent=no \
  -o ClearAllForwardings=yes \
  alice@web1.example.com true
ssh-keygen -lf ~/.cache/hostwarden/hostkey.web1.example.com
```

It logs in as the user being looked up, never as root in its
place. This is option 2's call: until the fingerprints match, the host
gets no key, no agent and no forwarding, and the call ends in
`Permission denied`, as it should. That is one failed login
(`rules/ssh-connections.md` → Avoid failed logins): once per host,
never in a loop. For option 1, leave out the last three options:
the call is the first login, and the choice already trusts the
key.

ssh records the key under the one name it connected by. Before
appending, give the line every name Getting a Key lists:

```bash
f=~/.cache/hostwarden/hostkey.web1.example.com
sed -E 's/^[^ ]+ /web1.example.com,192.0.2.10 /' "$f" > "$f.n" &&
  mv "$f.n" "$f"
```

For option 2, compare the printed fingerprint with the user's. A
mismatch writes nothing: delete the cache file, tell the user
both fingerprints, and connect to nothing. Otherwise append as in
source 1, with `first use` or `console (user)` as the source,
report the fingerprint in one line, and, for option 2, only then
log in as usual.

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

For a replaced key, and a host whose memory directory is removed,
with its aliases:

```bash
ssh-keygen -R web1.example.com -f "/srv/hostwarden/memory/known_hosts" &&
  rm -f "/srv/hostwarden/memory/known_hosts.old"
```

`-R` removes each whole line that names the host, other names on
it included, and leaves `@cert-authority` lines alone.

A removed DNS alias takes only its own name: `-R` would take the
canonical host's names on a shared line with it. Rewrite the
names field instead, leaving out that name and a line that
names nothing else, then put the result in place:

```bash
f=/srv/hostwarden/memory/known_hosts
awk -v a=www.example.com '
  /^#/ || NF < 3 { print; next }
  { i = ($1 ~ /^@/) ? 2 : 1; n = split($i, h, ","); o = ""
    for (j = 1; j <= n; j++) if (h[j] != a) o = o (o == "" ? "" : ",") h[j]
    if (o == "") next
    $i = o; print }' "$f" > "$f.new" && mv "$f.new" "$f"
```

A hashed name is not in clear and cannot be matched this way;
`ssh-keygen -F www.example.com` afterwards must print nothing
but a `CA` line. Where it prints a hashed line, remove that one
with `-R`: a hashed line names one host only.

## Host Certificates

A `@cert-authority` line covers every host whose name matches
its pattern and whose certificate that CA signed. Such a host
needs no line of its own. An SSH CA the user already runs is
audited and used as `rules/ssh-ca.md` says; building one is the
user's decision, which Hostwarden neither proposes nor helps
with.

Before the first connection to a host whose `SSH host cert:` line
names a CA, the CA lines of Before the First Connection's lookup
must name that CA. Off port 22, look up the plain name as well:
ssh accepts a CA line for either `[<name>]:<port>` or `<name>`,
while `ssh-keygen -F` finds only the form it is given.

```bash
for n in '[web1.example.com]:2222' web1.example.com; do
  ssh-keygen -F "$n" -f "/srv/hostwarden/memory/known_hosts" |
    grep '^@cert-authority' | cut -d' ' -f3- | ssh-keygen -lf -
done
```

- **The CA's fingerprint is among them:** connect. During a CA
  rotation two lines print, and one match is enough.
- **None:** the host is known by a plain key only, or not at all.
  Offer the host CA's line, for the patterns its scope in
  `memory/network.md` names, never `*`, each in both forms:
  `*.example.com,[*.example.com]:*`. It comes from the user's own
  known_hosts as source 2 of Getting a Key imports it, or from the
  user; written as The File says, and only on a yes. A no leaves
  the plain key working.
- **Only other CAs:** the workspace trusts another CA for this
  name — an unfinished rotation, or a wrong line. Connect to
  nothing, and tell the user both fingerprints.

The certificate must list the name looked up here among its
principals (`rules/ssh-ca.md` → Host Certificate).

`Host key verification failed` on a name a CA line covers points
at the certificate. The client prints the reason just before it:
`Certificate invalid: expired`, because its renewal stopped, or
`Certificate invalid: name is not a listed principal`, because it
does not name this host. Where no reason shows, the single retry
with the fresh-login options and `-v`
(`rules/ssh-unreachable.md`) shows which. That is a finding for
the host, reported in one line; Hostwarden cannot log in to fix
it, and the user renews the certificate. Get a plain key for it
only when the user asks.

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

A jump host's key is checked against `memory/known_hosts` as the
target's is, whether `memory/ssh_hosts` or the user's own
configuration names it. One missing from the file fails the call
with `Host key verification failed` before the target is reached:
get its key first, as for any host.
