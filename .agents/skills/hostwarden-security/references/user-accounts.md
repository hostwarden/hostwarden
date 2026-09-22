# User Account Hygiene — Linux, FreeBSD and macOS

## Empty Password Accounts

Check for accounts with empty password fields in `/etc/shadow`.
Requires root.

```bash
awk -F: '($2 == "") {print $1}' /etc/shadow
```

- Any account found → **CRITICAL** per account
- No accounts → OK

**Unprivileged fallback:** this check cannot be performed without
root. Add to "Skipped" section.

## Multiple UID 0 Accounts

```bash
awk -F: '($3 == 0) {print $1}' /etc/passwd
```

No root needed — `/etc/passwd` is world-readable.

- Only `root` has UID 0 → OK
- Any other account with UID 0 → **CRITICAL**

## System Accounts with Login Shells

Check for system accounts (UID < 1000) that have interactive
login shells.

```bash
awk -F: '$3 < 1000 {
  s = $7; sub(/.*\//, "", s)
  inert = (s == "nologin" || s == "false" || s == $1)
  if (s ~ /sh$/ || inert == 0) print $1 ":" $7
}' /etc/passwd
```

Inert shells are `nologin`, `false`, and a binary named after
its account (`sync`, on RHEL also `shutdown` and `halt`), which
`s == $1` catches without spelling a name. A shell ending in
`sh` is reported regardless, so an account named after its
shell (`bash` with `/bin/bash`) cannot hide.

**Three traps this shape avoids; do not "simplify" it back:**

- Printing only shells that end in `sh` fails open: `ksh93`,
  `python3` and an empty field (which means `/bin/sh`) go
  unreported. A security check reports what it does not
  recognize.
- A regex of inert shell names writes `shutdown` and `halt`
  into the command, and `guard-taboos.sh` denies it (see
  `AGENTS.md`, Critical Safety Rules).
- awk's `!~` (and any `!`) does not survive SSH + zsh quoting:
  zsh reads `!` as history expansion, even inside quotes.

No root needed.

Expected exceptions: `root` (has `/bin/bash` or `/bin/sh`), and
on Debian/Ubuntu `postgres` (the `postgresql-common` package
ships it with `/bin/bash`). Flag all others.

- Any unexpected system account with a login shell → **WARN** per
  account
- Only expected exceptions → OK

## FreeBSD

Where the hashes live and how a locked field reads is in
`rules/os/freebsd.md` → Accounts. One pass as root covers empty
passwords, UID 0 and `toor`, and prints only verdicts:

```bash
awk -F: 'NF > 1 {
  if ($1 ~ /^[#+-]/) next
  if ($2 == "") print "empty password: " $1
  if ($3 == 0) print "uid 0: " $1
  if ($1 == "toor") {
    v = ($2 ~ /^[*]/) ? "locked" : "password set"
    print "toor: " v
  }
}' /etc/master.passwd
```

Lines starting with `+` or `-` are NIS entries. Unprivileged, run
the UID 0 check above on `/etc/passwd` and list empty passwords as
skipped.

- Empty password → **CRITICAL** per account, `root` included
- UID 0 other than `root`, `toor` and an account the loaded OS
  file names as expected → **CRITICAL**
- `toor` with a password → **INFO**: a second root login
- Otherwise OK

The system-account check above runs on FreeBSD's `/etc/passwd`
as it stands, except that names starting with `+` or `-` are NIS
entries, not accounts: ignore them. Expected there besides
`root`: `toor` (empty shell field) and `uucp`
(`/usr/local/libexec/uucp/uucico`).

## macOS

Accounts live in the local directory service, not in
`/etc/passwd`, which lists only a handful of system accounts. Read
them with `dscl`; no root needed:

```bash
dscl . -list /Users UniqueID | awk '$2 == 0 || $2 >= 500'
dscl . -read /Groups/admin GroupMembership
dscl . -read /Users/root AuthenticationAuthority 2>&1
defaults read /Library/Preferences/com.apple.loginwindow 2>&1
```

From the `loginwindow` domain, `autoLoginUser` and
`GuestEnabled` count.

- **UID 0:** any account but `root` → **CRITICAL**, as above.
- **People:** accounts from UID 500 up. Report them with the
  members of `admin`; an admin nobody recognises → **WARN**.
- **root:** disabled on a Mac by default. A `ShadowHash` entry
  in its `AuthenticationAuthority` without a `DisabledUser` entry
  means root has a password and can log in → **WARN**.
- **Automatic login** set to a user → **WARN**: whoever opens the
  lid is that user. FileVault turns it off, so with FileVault on
  (`references/macos-security.md`) a leftover value is **INFO**.
- **Guest account** enabled (`1`) → **INFO**.
- **Empty passwords:** not checked (`rules/secrets.md`); say so
  under Skipped.
- The system-account shell check above does not apply: macOS
  system accounts start with `_` and ship with `/usr/bin/false`.
