# DNS Aliases

The same physical server can have multiple DNS names.
Hostwarden detects this automatically using the `- IP:`
field in server memory files.

**Canonical name** = the first hostname used for a
server. Additional DNS names become filesystem
symlinks to the canonical directory.

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
   cannot run: tell the user so.

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
   `memory.md` is a host taken over from Heinzel
   that nothing has connected to yet
   (`rules/heinzel-takeover.md` → Heinzel's memory).
   Compare its `- IP:` line too, by address alone
   — that file is never edited, so it gets no
   `SSH port:` — and never link on it: Heinzel's
   address may be out of date, and the same address
   may be another port's machine. On a match, ask
   the user whether this is that
   host. A yes makes this name its alias, and this
   connection that host's first one, OS detection
   included; a no makes it a new server.

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
alias now points elsewhere (detach it).

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
   `memory.md`.
3. Remove the alias from `memory/user.md` if present.
4. Remove its lines from `memory/known_hosts`:
   `rules/host-keys.md` → Removing Names.
