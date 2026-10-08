# A Hostwarden login without the write bit

The account mechanism of the `hostwarden-enforce-readonly` skill:
Hostwarden stops logging in as root or as the user's own account
on this host and logs in as a login of its own, which the host's
own permission checks keep out of the protected paths. The
pattern is the deploy user's (`hostwarden-deploy-user`): a system
account, no password, a key, sudo for named commands or none. The
difference is who uses it, so the account gets a real shell and
read access to the paths it must not write.

On a directory host the account is a local one, which
`rules/accounts.md` → Changing Accounts or Sudo Rules allows for
a service account; say so.

## 1. The account

`hostwarden` unless the user names another. A real shell, since
every probe runs through it; `/bin/sh`, which every reference is
written for. No password: the key is the only way in. In the same
call, as root, read whether sshd admits the account at all, since
a `sshd_config` is never written here: a line that leaves
`hostwarden` out keeps it from logging in whatever the key says,
and the user changes that themselves.

```bash
useradd --system --create-home --home-dir /home/hostwarden \
  --shell /bin/sh --comment "Hostwarden" hostwarden && id hostwarden
sshd -T 2>/dev/null \
  | grep -iE '^(allowusers|allowgroups|denyusers|denygroups) '
```

FreeBSD:

```bash
pw useradd hostwarden -m -s /bin/sh -c "Hostwarden" -w no \
  && id hostwarden
```

macOS, as root, with a free UID as `hostwarden-deploy-user` →
macOS picks one; stop when the first line finds an account:

```bash
dscl /Search -read /Users/hostwarden RecordName 2>/dev/null && exit 1
dscl . -create /Users/hostwarden
dscl . -create /Users/hostwarden UniqueID <free-uid>
dscl . -create /Users/hostwarden PrimaryGroupID 20
dscl . -create /Users/hostwarden RealName "Hostwarden"
dscl . -create /Users/hostwarden UserShell /bin/sh
dscl . -create /Users/hostwarden NFSHomeDirectory /Users/hostwarden
dscl . -create /Users/hostwarden Password '*'
dscl . -create /Users/hostwarden IsHidden 1
createhomedir -c -u hostwarden
```

Where Remote Login admits only some users, the group
`com.apple.access_ssh` exists; add the account to it:
`dseditgroup -o edit -a hostwarden -t user com.apple.access_ssh`.
Verify the password state as `hostwarden-deploy-user` → Verify
does, for each family.

Never put the account into `sudo`, `wheel`, `admin` or a
root-equivalent group (`rules/privilege-escalation.md` →
Root-Equivalent Groups): each is root, and root writes anything.

## 2. The key

The user's own public key, the one this session logs in with:
`ssh-add -L` on the workstation, or the `.pub` beside the file
`ssh -G <hostname>` names on its `identityfile` line. No new key
pair: the account is used by the same person from the same
workstation, and a second private key would be a second thing to
protect for nothing. Only the public half ever reaches the host.

No session writes `authorized_keys` or re-permissions `.ssh`
(`AGENTS.md` → Critical Safety Rules), so the user does it, with
the real path of the public key; on macOS the home is
`/Users/hostwarden` and the owner `hostwarden:staff`. In a shared
workspace every operator who is to use the account adds their own
key this way, and each switches their own `memory/user.md`
(step 5):

```bash operator
ssh root@hostname 'sh -c "
  mkdir -p /home/hostwarden/.ssh
  cat >> /home/hostwarden/.ssh/authorized_keys
  chmod 700 /home/hostwarden/.ssh
  chmod 600 /home/hostwarden/.ssh/authorized_keys
  chown -R hostwarden:hostwarden /home/hostwarden/.ssh
"' < ~/.ssh/id_ed25519.pub
```

## 3. Read access to the paths

A `readonly` path may be read. Where the account cannot — the
files are `0600` or `0640` of another group — give it read access
through a group it joins or through an ACL for it alone, never by
widening the mode for everyone. The ACL is an attribute change on
a protected path, and the one kind a `readonly` glob allows
(`rules/access-control.md` → Protected Paths).

Linux, POSIX ACLs on ext4, XFS and Btrfs, the access entry and
the default entry new files inherit in one pass:

```bash
setfacl -R -m u:hostwarden:rX,d:u:hostwarden:rX <dir>
```

FreeBSD on ZFS, NFSv4 ACLs with inheritance; on UFS, POSIX.1e,
which takes `rwx` only and selects the default ACL with `-d`:

```bash
setfacl -R -m u:hostwarden:read_set:fd:allow <dir>
setfacl -R -m u:hostwarden:rx <dir> \
  && find <dir> -type d -exec setfacl -d -m u:hostwarden:rx {} +
```

macOS:

```bash
chmod -R +a "hostwarden allow read,readattr,readextattr,readsecurity,\
list,search,file_inherit,directory_inherit" <dir>
```

Where step 5 shows `WRITABLE` through the `other` bits or a group
the account must stay in, a deny entry for the account alone
closes it, in the same ACL form with the write set denied. A path
with the write bit for everyone, such as `/tmp`, is not worth a
`readonly` glob; say so rather than build an ACL around it.

## 4. Sudo

One file, as `rules/accounts.md` → Changing Accounts or Sudo
Rules writes one: `/etc/sudoers.d/hostwarden`,
`/usr/local/etc/sudoers.d/hostwarden` on FreeBSD,
`/private/etc/sudoers.d/hostwarden` on macOS, with its master
under the host's `files/` and its entry in `deployed.md`
(`rules/deployed-files.md`). One `NOPASSWD` line per command,
full path, root as the run-as user.

The list starts with what the user names, and nothing else: a
file with no line is a valid choice, and leaves Hostwarden in
unprivileged mode on this host. Each command the user names goes
through the three questions of that same section of
`rules/accounts.md`, and the user adds one later when a report
shows `unknown(needs-root)` for a check they want, through the
same gate.

The `Sudo:` line of memory is written by
`rules/privilege-escalation.md` → Sudo on the next connection as
the new login. What sudo does not cover stays deferred: on a host
with an `Enforced readonly: account` line that rule probes no
root SSH fallback, since root would reach every path the account
is kept out of. The user's own key still opens root to them, and
taking it out of root's authorized keys is their step, never a
session's.

## 5. The switch

A fresh login as the new account, with the fresh-login options
(`rules/ssh-connections.md` → Fresh-login options), before
anything in memory changes:

```bash
id && for p in <path> …; do
  test -w "$p" && echo "WRITABLE $p" || echo "ok $p"; done
```

One `WRITABLE` line means step 3's ACLs or the mode still let the
account in, and the switch waits until it is gone. Then replace
the host's `- <hostname>:` entry in `memory/user.md` with
`hostwarden`, write the host's `Enforced readonly: account` line,
and close this session's shared connection to the old login
(`rules/ssh-connections.md` → Share connections), so the next call
is the new account's. The old login's key stays where it is.

The `Accounts:` line of memory gains `hostwarden` among its local
accounts (`rules/accounts.md` → Memory), the security audit lists
the account and its sudo file from then on, as it lists every
local account, and `rules/ssh-user.md` → Account Model takes the
login as fitting the host because of the line.
