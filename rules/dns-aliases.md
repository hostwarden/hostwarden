# DNS Aliases

The same physical server can have multiple DNS names.
Hostwarden detects this automatically using the `- IP:`
field in server memory files.

**Canonical name** = the first hostname used for a
server. Additional DNS names become filesystem
symlinks to the canonical directory.

A renamed host (`rules/host-rename.md`) makes its new
name the canonical one, and its old name an alias
without Detection: symlink and `- DNS alias:` line as
in step 3, until the user says the old name is gone
from DNS or a connection by it finds no address. Then
remove it as `rules/host-rename.md` → When the Old
Name Is Gone says.

## Detection (on every new hostname)

When connecting to a hostname with no
`memory/servers/<hostname>/` directory (and not a
symlink):

1. **Resolve the IP(s) the way `ssh` does.** First
   apply the SSH client config: a `Host` block in
   `memory/ssh_hosts` or `~/.ssh/config` can point
   anywhere through `HostName`, a `Match user` block
   for one user only. `ssh -G` with the standard
   options (`AGENTS.md` → SSH Options), for the user
   the call logs in as, prints the name
   ssh will really connect to, without connecting:
   ```
   ssh -F "<checkout>/memory/ssh_config" -G -l '<user>' <hostname> 2>/dev/null | \
     awk '$1=="hostname"{print $2}'
   ```
   `-l` quoted keeps a Windows `domain\user` whole
   (`rules/ssh-user.md` → Host-specific options).
   Every `ssh -G` below carries the same `-F`.
   Resolve that name. Ask the system resolver, not
   DNS directly: only it sees `/etc/hosts`, the
   search domain and the resolvers a VPN adds per
   domain (macOS scoped resolvers, systemd-resolved
   split DNS). Collect every IPv4 address, not just
   the first. On Linux:
   ```
   getent ahostsv4 <hostname> | \
     awk '{print $1}' | sort -u
   ```
   On macOS:
   ```
   dscacheutil -q host -a name <hostname> | \
     awk '$1=="ip_address:"{print $2}' | sort -u
   ```
   Elsewhere (FreeBSD), use `getaddrinfo`:
   ```
   python3 - <hostname> <<'EOF'
   import socket, sys
   for a in sorted({i[4][0] for i in socket.getaddrinfo(
           sys.argv[1], None, socket.AF_INET)}):
       print(a)
   EOF
   ```
   Only when neither is available, query DNS with
   `dig`, which misses everything above. Filter for
   addresses — a bare `dig +short` can return a
   CNAME target instead of an IP:
   ```
   dig +short +time=2 +tries=1 A <hostname> | \
     grep -E '^[0-9.]+$'
   ```
   Verify the syntax of the tool you use on the
   machine running the query (see AGENTS.md →
   Verify Before Running). If the blacklist or
   read-only check already resolved the name this
   way, reuse that result; otherwise resolve it
   here. If nothing resolves, the IP comparisons
   cannot run: tell the user so. Where the name ssh
   connects to ends in `.local`, follow
   `rules/mdns.md` before step 2.

2. **Compare against known servers.** Scan existing
   `memory/servers/*/memory.md` files (skip
   symlinks) for a matching `- IP:` line whose
   `- SSH port:` also matches the `port` line of
   `ssh -G <user>@<hostname>`, with the SSH user
   settled in `rules/first-connection.md` step 3: a
   `Match user` block can set another port. A file
   without `- SSH port:` gets one first, from
   `ssh -G <its user>@<its hostname>`, and records it;
   never assume 22. The same
   address on another port is another machine behind
   a port forward, such as a second WSL distribution
   on one Windows host: no alias.

   A directory with `heinzel-memory.md` and no
   `memory.md` is compared as
   `rules/heinzel-takeover.md` → Before its first
   connection says.

3. **Match found -> alias.**
   - First verify its host key against the canonical
     host's and give it lines of its own:
     `rules/host-keys.md` → DNS Aliases. A key that
     does not verify writes nothing here: no symlink,
     no `DNS alias:` line.
   - Create symlink:
     `ln -s <canonical> memory/servers/<alias>`
   - Confirm it is one: `test -L memory/servers/<alias>`.
     If not, delete the copy, use the canonical
     `memory.md` for this session, and point the user to
     docs/install.md → Symbolic links.
   - Add `- DNS alias: <alias>` to canonical
     `memory.md`.
   - Skip OS detection.

4. **No match -> new server.** Normal first-connection
   flow. Include resolved IP as `- IP:` field.

## The FQDN

`- FQDN:` is the host's fully qualified name as the host
itself gives it. It tells apart servers whose names share a
first label (Short Names Matching More Than One Server
below) and names the host in mail (`hostwarden-email`). It
is not unique: two guests of one hostname, or two machines
behind one address, can give the same one, and a host can
claim any name. So it never renames the directory and adds
no name to connect by: `ssh` calls, `Host` lines and
`memory/known_hosts` name what they would without it.

**When.** In the activity check's call
(`rules/activity-check.md` → What rides in this call), on a
host whose memory has no `- FQDN:` line or `unknown` in it.
A first connection writes `memory.md` without the line; this
call adds it. A full re-probe (`rules/os-detection.md` → On
subsequent connections) and the verification of a rename
(`rules/host-rename.md` → Verify) read it again, `none`
included, and write what they find over the old value.

**The probe** is the first line of `hostname -f` on the host,
after a marker of its own:

```
echo @fqdn; hostname -f
```

On Windows it is left out, since `hostname` there takes no
`-f`, and the resolver below decides alone.

**The test.** Take off one trailing dot first. The name
qualifies when it is one word of letters, digits, hyphens
and dots, holds at least one dot, has no label `localhost`
or `localdomain`, and does not end in `.local`. Record it in
lower case.

**The resolver.** Where the host's answer fails the test, or
the host has no `hostname` (OpenWrt, `rules/busybox.md`),
apply the test to the canonical name the workstation's
resolver gives for the `hostname` line of `ssh -G` that
Detection step 1 or IP Verification read, asked with the
tool step 1 uses: the third field of the first line of
`getent ahostsv4` on Linux, the `name:` line of
`dscacheutil -q host -a name` on macOS, elsewhere
`getaddrinfo` with `AI_CANONNAME`, whose first entry carries
it. It counts only where its first label equals that of the
name asked or of the host's answer: a CNAME target, such as a
load balancer's name, is not the host's. Skip it where that
line is an address, where `ssh -G` names a `proxyjump` other
than `none` or a `proxycommand` — the name is then resolved
beyond the workstation — for a guest reached through its
host, and for the local machine.

**Neither qualifies:** where the resolver gave a name that
fails the test or does not count, write `- FQDN: none`, so
later connections do not probe again. Where it was skipped
or gave nothing — a timeout and a name that does not exist
look alike there — write `- FQDN: unknown`, which the next
connection reads again.

## Short Names Matching More Than One Server

In remote mode, when the user names a host without a dot,
scan `memory/servers/`, skipping symlinks, for directories
whose name or `- FQDN:` line in `memory.md` has that first
label, ignoring case. A directory with `heinzel-memory.md`
and no `memory.md` counts as `rules/heinzel-takeover.md` →
Before its first connection says. A name taken from a
memory directory rather than from the user — the fleet
audit, a scheduled run — is that directory: no scan.

One match or none, or matches that are WSL instances of one
Windows machine, which the port tells apart
(`rules/server-memory.md`): go on as usual. Otherwise, ask
which server is meant before anything reaches the network,
in the picker form of `rules/service-reload.md` → Prompt
Shape When Asking: one option per directory, labelled with
its name and FQDN, and one for another server.

- **A directory:** the session goes on with it as with any
  known host, by the name it is reached by — the directory
  name, its `Reached as:`, or its `Runs on:` in via-host
  mode — and the blacklist and read-only checks run for the
  name as given too. Where the name reaches another address,
  IP Verification below stops it.
- **Another server:** ask for its name with the domain, and
  go on with that name as the user's.

## Subsequent Connections via Alias

Follow the symlink, read canonical `memory.md`. Use
the **alias hostname** (not canonical) for SSH
commands and `user.md` lookups. Each alias can have
its own SSH user.

## IP Verification

On every connection to a known server, verify the
current IP matches `- IP:` in memory. Resolve as in
Detection step 1 and compare against the full set
of resolved IPs: round-robin DNS gives a host
multiple A records, and any overlap with the stored
IP(s) counts as a match. Note multi-A hosts in
server memory instead of alarming. Only when there
is no overlap at all, **stop and tell the user.**
Ask whether the server migrated (update IP) or the
alias now points elsewhere (detach it). Where the
name ssh connects to (Detection step 1) ends in
`.local`, follow `rules/mdns.md` before asking.

That name follows `rules/mdns.md` on any connection
too while `memory.md` has no `- Resolved via:` line
for it.

The port is part of the identity too. Compare the
`port` line of `ssh -G <user>@<hostname>` with
`- SSH port:`, and record it where memory has none.
A different port is a different machine until the
user says otherwise, even on a matching IP: **stop
and tell the user**, whatever the role file says
about a changed address.

## Removing an Alias

1. Delete the symlink from `memory/servers/`.
2. Remove the `- DNS alias:` line from canonical
   `memory.md`, and the `- Resolved via:` line for
   the name ssh reached the alias by, unless another
   of the host's names reaches the same one.
3. Remove the alias from `memory/user.md` if present.
4. Remove its lines from `memory/known_hosts`:
   `rules/host-keys.md` → Removing Names.
