# Access Control

Rules for the server blacklist and read-only server
list. Both use the same file format and lookup logic.

## Shared File Format

Plain list — one entry per line. An optional leading
`- ` bullet is allowed and ignored. Everything after
`#` is a comment; blank lines are ignored. Entries
can be a hostname (matched against the target
hostname) or an IP address (matched against the
resolved IP). IPs are the most robust form — prefer
them. In `memory/readonly.md` only, the entry `*`
matches every host, the local machine included: an
operations host's list holds it
(`hostwarden-fleet-read` skill). Files are created on
first need — do not pre-create them.

```markdown
# Example

- server.example.com   # bullet optional
203.0.113.50
```

The user can add or remove entries by asking Hostwarden
to edit the file, or by editing it directly.

## Shared Lookup Logic

For both files, the check is (stop at the first
match):

1. If the file does not exist, skip (nothing to
   check). In `memory/readonly.md`, is `*` listed?
2. Is the target hostname, or the name
   `rules/dns-aliases.md` → Detection step 1 maps it
   to, listed? The target is the name without a port
   the user wrote with it (`rules/ssh-config.md` → A
   Port the User Names).
3. Resolve the target's IP(s)
   (`rules/dns-aliases.md` → Detection step 1).
   Is a resolved IP listed?
4. Resolve each listed hostname to its IP(s) the
   same way, once per session, and compare against
   the target's IP(s). This catches DNS aliases of
   listed hosts that a plain string match would
   miss.

If nothing resolves — a resolver-unreachable result
(`rules/dns-aliases.md` → Detection step 1) included —
fall back to exact string matching and tell the user
explicitly which of the two it was and that the
IP-level check could not be performed. Err on the side
of caution for anything ambiguous.

On a first connection the user is chosen only after
both checks. Run them as the `Default:` user of
`memory/user.md`, or, where it has none yet, with
`ssh -G <hostname>` and no user, and keep that output:
`rules/first-connection.md` step 3 compares the
chosen user's with it and says when both run again.

## Server Blacklist

**File:** `memory/blacklist.md`

**When to check:** before every connection attempt —
before OS detection, before DNS alias detection,
before any SSH command. This is the very first step
when a user mentions a server.

**On match:** refuse to connect. Tell the user:
"This server is blacklisted in
`memory/blacklist.md`. I will not connect to it."
Do not proceed. Do not ask for override. Do not run
any SSH commands against the server.

**Jump hosts count too.** SSH connects to each jump
host before the target. Its jump hosts come from the
`proxyjump` and `proxycommand` lines of
`ssh -G <user>@<hostname>` with the standard options,
for the user the call will log in as; a `Match user`
block can change either for that user alone. `ssh -G`
prints both with their tokens unexpanded, and ssh
expands them only when it connects: read `%r` as the
target's `user` line, `%h` as its `hostname`, `%p` as
its `port`, `%n` as the name as given and `%%` as `%`
first. The jump hosts, where a line is not `none`:

- **`proxyjump`:** each comma-separated
  `[user@]host[:port]`, an `ssh://` before it
  dropped.
- **`proxycommand` that runs `ssh`**, read as the
  shell would, quotes undone and `~` expanded: its
  destination, the first argument that is neither an
  option nor an option's value, and the address a
  `-o HostName` gives it; each hop of a `-J` or a
  `-o ProxyJump`, as above; a host other than the
  target that its `-W` names; and its remote
  command, read as a `proxycommand` of its own. The
  user is the one `-l`, `-o User` or `user@` names
  first. That ssh reads the file its `-F` names,
  else the user's own configuration, never the
  standard options: the `ssh -G` of its hops reads
  the same.
- **`proxycommand` that runs `nc`, `ncat`,
  `netcat`, `socat` or `connect`:** the proxy it
  names (`-x`, alone or in a cluster such as `-vx`,
  `--proxy`, a socat `PROXY:`, `SOCKS4:`, `SOCKS4A:`
  or `SOCKS5:` address, connect's `-S`, `-H` or
  `-T`), and the host it connects to where that is
  not the target (a socat `TCP:` or `OPENSSL:`
  address among them). Nothing else on the line is a
  host: its other arguments can hold a password,
  never looked up or printed (`rules/secrets.md`).

A host reached other than by an ssh from here — a
proxy, one a `-W` names, anything a jump host's
remote command reaches — is looked up by its name
and addresses alone: its `ssh -G` here says nothing
about how it is reached.

Any other `proxycommand` hides its path: another
program, a tunnel client, a `connect` whose proxy
comes from the environment, a `$`, a command
substitution, a `ProxyCommand` of its own. So does a
chain longer than five hops. An unreadable path is
not a match, and this is the one question the check
asks: name the program alone, never the line, and ask
the user whether its path passes a host on the
blacklist. Connect only when they say it does not;
otherwise refuse as for a listed hop.
The answer holds for this session and is never
recorded: the blacklist and the ProxyCommand are the
user's own, and either can change. A hop whose
`ssh -G` fails cannot be read either, and the
connection would fail on the same configuration: say
so and do not connect.

Run the lookup above for each hop, and for the hops
its own `ssh -G` names in turn, by the hop's name
without `user@` or `:port`, an IPv6 address without
its brackets, and as the hop's own login user: the
one named with it, else the `user` line of `ssh -G`
for that hop. A listed hop blocks the target: name
the hop and refuse, as above.

## Read-Only Servers

**File:** `memory/readonly.md`

**When to check:** right after the blacklist check,
before OS detection and DNS alias detection.

**On match:** announce read-only mode to the user:
"This server is marked read-only in
`memory/readonly.md`. I will connect and inspect,
but I will not make any changes."
Proceed with the connection — unlike the blacklist,
read-only does not block access.

**Allowed in read-only mode:**
- All read-only operations: SSH inspection, status
  commands, reading files and logs
- Housekeeping checks and security audits
- Local memory and changelog updates, including
  creating `todo.md` (a purely local file — only
  the remote host is read-only)
- The journal line on the server (`rules/changelog.md`)

**Blocked in read-only mode:**
- Package install, update, or remove
- Service start, stop, enable, disable, or restart
- Config file edits on the server
- Firewall, user/group, or file write changes
- Reboots

**Deferred modifications:** when a blocked action is
needed, announce it briefly and continue with
read-only work. At session end, present a
modification report in the same format as the
unprivileged mode sysadmin report.

**No override:** read-only mode is a hard constraint.
The user must remove the entry from
`memory/readonly.md` before Hostwarden will modify the
server.

**Read-only by OS file:** an OS file that says every
host of its family is read-only puts the host in this
mode once detection has read it, whatever
`memory/readonly.md` says. Announce it with the OS
file as the reason. Only an override that wins over
that statement lifts it (`rules/overrides.md` →
Precedence). The OS file may name single changes as
exceptions; they are then the only thing the Blocked
list above lets through, and a host listed in
`memory/readonly.md` gets none of them.
