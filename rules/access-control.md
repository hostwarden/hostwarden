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
them. Files are created on first need — do not
pre-create them.

```markdown
# Example

- server.example.com   # bullet optional
203.0.113.50
```

The user can add or remove entries by asking hostwarden
to edit the file, or by editing it directly.

## Shared Lookup Logic

For both files, the check is (stop at the first
match):

1. If the file does not exist, skip (nothing to
   check).
2. Is the target hostname, or the name `ssh -G`
   maps it to (`rules/dns-aliases.md` → Detection
   step 1), listed?
3. Resolve the target's IP(s)
   (`rules/dns-aliases.md` → Detection step 1).
   Is a resolved IP listed?
4. Resolve each listed hostname to its IP(s) the
   same way, once per session, and compare against
   the target's IP(s). This catches DNS aliases of
   listed hosts that a plain string match would
   miss.

If nothing resolves, fall back to exact string
matching and tell the user explicitly that the
IP-level check could not be performed. Err on the
side of caution for anything ambiguous.

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
- `logger -t hostwarden` entries on the server

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
`memory/readonly.md` before hostwarden will modify the
server.

## Linked Worktrees

**When to check:** before the blacklist check, once
per session. A linked worktree is a development
checkout (`AGENTS.md` → Development or Operations);
where hooks run, the session was told so at its
start and the mode guard enforces it. Elsewhere,
read `.git` in the hostwarden directory: a file whose
`gitdir:` names a directory holding a `commondir`
file means a linked worktree; a directory, or a
submodule's `.git` file, does not.

**Why:** `memory/` is gitignored, so a worktree
carries none of the user's state — no
`blacklist.md`, no `readonly.md`, no `user.md`, no
server memory. Both checks above would find no file
and let everything through, and whatever the session
writes to server memory is deleted with the
worktree. The Claude Code desktop app can start
every session in one.

**On match:** refuse to reach any machine, localhost
included. Tell the user: "This session runs in a git
worktree, where the blacklist, the read-only list
and server memory do not exist. Start a new session
in the hostwarden checkout itself, with the worktree
option off." Name that checkout: the parent of the
common git directory.

**No override:** do not point the session at the
main checkout's `memory/` and carry on. Every rule
names `memory/...` relative to where it runs, so one
missed path reads or writes the empty tree here
instead. Working on hostwarden's own source is what
a worktree is for; that reaches no machine and needs
no check.
