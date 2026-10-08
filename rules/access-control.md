# Access Control

Rules for the server blacklist and read-only server
list. Both use the same file format and lookup logic.
The user's own lists of paths on a host that stay
untouched, or need a word before they are touched, are
under → Protected Paths.

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

`bin/hostwarden-impact` and `bin/hostwarden-fleet-run`
run this same logic unattended, through
`lib/resolve.sh`, with no one to tell about
an ambiguous result and decide from there: a resolver
that cannot be reached while either checks a host is
treated as if that host matched, never as a clean
miss. `hostwarden-fleet-run` skips the host, the same
outcome an actual match gets, since it is the one gate
before the unattended connection fleet read makes.
`hostwarden-impact` treats the team-telling call the
same way for the blacklist; for the read-only list, an
unresolvable entry defaults every host it checks that
session to read-only, the safe direction, rather than
to registering a write the list might actually forbid.
An entry of either list that cannot be resolved has no
addresses to compare against, so it leaves every host
of that run unverifiable, not only the one it names: a
host that did not match it by name could still be it by
address. A name that genuinely resolves to nothing is
not such an entry; a missing `dig` makes every
name-only entry one.

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

## Protected Paths

The two lists above cover a whole host. A path on a host that
is otherwise writable is protected by the user's own two lists,
in the host's override file `memory/machines/<hostname>/rules.md`
under the subject `# access-control` (`rules/overrides.md` →
Where an override goes), and in `memory/custom-rules/all.md` for
every host. Where both files have the block, the lists add up,
and where they disagree about one path, the host's file decides,
as for any override (`rules/overrides.md` → Precedence):

    # access-control
    ## Protected Paths
    ### readonly
    - /var/www/app/data/**
    - /etc/postgresql/**
    ### confirm
    - /var/lib/docker/volumes/**
    - /etc/fstab

In `all.md` the block starts at `## Protected Paths`, since that
file names no subject. One glob per line, as a `- ` list item. A
list that is not there is empty, and so is the block in a file
that has none, which is the normal case and never worth a line.

**When to read:** with the host's memory, step 6 of
`rules/first-connection.md`, in local mode too; the `all.md`
block is in force from the session-start preflight on. The lists
hold for every command this session runs on that host, and for
every agent it starts for the host (`rules/multi-host.md` →
Agents).

**Globs** start with `/` and match absolute paths in the file
system of the host whose file they are in. `*` matches any run
of characters inside one path component and never `/`; `**`
matches any number of components, none included, so
`/srv/app/**` covers `/srv/app` itself and everything under it,
and `/**/*.sqlite` every such file at any depth. A glob without
a wildcard names one path.

A command is matched by every path it reaches, not only the one
it names: a relative path as the absolute one it resolves to
from the working directory; a symlink or a bind mount as the
path behind it; a shell wildcard as each path it expands to; and
a directory above a matched path whenever the command takes the
tree with it — `rm -r`, `chown -R`, `chmod -R`, `find … -delete`,
`mv` or `rsync` of the directory, a deploy onto it. So with
`/var/www/app/data/**` on a list, `rm -rf /var/www/app` and
`chown -R www-data: /var/www` reach it and are judged by it. A
command that names an object rather than a path — a container
engine's volume, a ZFS dataset or a Btrfs subvolume, a mount —
reaches the object's mount point and everything under it: with
`/var/lib/docker/volumes/**` on a list, removing a volume, or a
compose project with its volumes, is judged by it. A guest
reached through its hypervisor (`rules/first-connection.md` →
Via-host mode) keeps its own lists for what runs inside it, and
a command on the hypervisor that writes into the guest —
`pct push`, `incus file push`, a container engine's copy into a
container, a write under the guest's root file system — is
judged by the guest's lists too, by the path inside the guest,
beside the hypervisor's own. Where step 6 has not read that
guest's file this session, read its block before the command.

**What counts as touching a path:** every command that writes,
creates, deletes, moves, renames, links, truncates or changes the
mode, owner or attributes of a matched path, whatever the tool —
an editor, `tee`, a redirect, `sed -i`, `rsync`, `mv` with the
path as source or destination, `chmod`, `chown`, `touch`, a
script from `memory/tools/`. Reading,
listing and `stat` never count. Judging that is this session's
work alone: the taboo guard sees a remote path only as text
inside the SSH command string and enforces nothing here.

The lists judge what this session writes, and nothing else.
What a package install, upgrade or removal, a service restart,
a container start or a job the session sets up writes on its
own is not theirs: those stay behind the ask-before list and
the rules that govern them, and a package the user wants kept
as it is, the package manager holds (`apt-mark hold` and its
equivalents).

- **`readonly`** — read, list and stat are allowed; everything
  else is denied, with no override in the session: the user takes
  the glob out of the list first. A denied step is a deferred
  modification, reported as → Read-Only Servers says.
- **`confirm`** — anything, but only after the exact command, as
  it will run, has been shown and the user has answered with the
  literal word `CONFIRM`. A yes, an "ok", or the approval the
  ask-before list already takes for the step, is not enough, and
  one `CONFIRM` covers that one command once. With
  `AskUserQuestion`, the question shows the command and offers
  only to cancel or to skip the step, so the word has to be typed
  as the free-text answer; without the tool, print the command in
  a code block and the line `Reply CONFIRM to run it.`, and treat
  any other reply as no.

**Precedence:** the blacklist and the read-only list win over
both lists. Where globs of both lists in one file match a path,
the more specific glob decides: the one whose text before its
first wildcard is longer, so `readonly` `/etc/postgresql/**`
holds under `confirm` `/etc/**`; at equal length the longer
glob, so `readonly` `/etc/*.conf` holds under `confirm`
`/etc/**`; and the same glob on both lists makes a `confirm`
path. The lists add a requirement and lift
none: the absolute taboos, the ask-before list and every other
Critical Safety Rule of `AGENTS.md` hold on a `confirm` path as
on any other, a typed `CONFIRM` is a second word on top of them
and never the explicit request a taboo needs, and a glob over
sshd's configuration, an SSH key or a disk device changes
nothing. On a blocked attempt, say which list and which glob
blocked it, and carry on with the rest of the task.
