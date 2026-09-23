# Account and Sudo Probes

The read-only probe behind `rules/accounts.md`, one call, and how
to read what it prints: where a host's accounts come from, whether
a first login gets a home, which sudo rules exist and who holds
them, and the local accounts. The security audit and the fleet
audit run it too. Windows keeps its accounts apart:
`rules/os/windows.md` → Local Administrators.

## Probe

It opens with the privilege prefix from
`rules/privilege-escalation.md` → Stand-ins for sudo. The account
source needs no root; the sudo rules, the SSSD and nslcd access
rules and sshd's key settings do, and without a privilege path
they print `unknown(needs-root)`.

It runs in an SSH call of its own, never bundled with another
probe: it names a key path, and the taboo guard denies any command
that also holds an interpreter, such as the `awk` of the other
audit probes. It uses none itself. Linux and FreeBSD:

```bash
PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
echo "@nss"
NS=
for f in /etc/nsswitch.conf /usr/etc/nsswitch.conf; do
  [ -e "$f" ] || continue
  NS=$f
  echo "$f"
  grep -E '^(passwd|group|sudoers):' "$f"
  break
done
if [ -d /run/systemd/system ]; then
  for d in sssd nslcd winbind oddjobd; do
    echo "$d=$(systemctl is-active "$d" 2>/dev/null)"
  done
else
  echo "running: $(ps -Ao comm= 2>/dev/null \
    | grep -xE 'sssd|nslcd|winbindd|oddjobd' | sort -u | tr '\n' ' ')"
fi
command -v realm >/dev/null 2>&1 && realm list 2>/dev/null
command -v authselect >/dev/null 2>&1 && authselect current 2>/dev/null
for f in /etc/samba/smb.conf /usr/local/etc/smb4.conf; do
  grep -HiE '^[[:space:]]*(security|realm)[[:space:]]*=' "$f" 2>/dev/null
done
grep -RHE 'require_membership_of' /etc/security/pam_winbind.conf \
  /etc/pam.d /usr/lib/pam.d 2>/dev/null
echo "@mkhomedir"
grep -RlE 'pam_(oddjob_)?mkhomedir' /etc/pam.d/ /usr/lib/pam.d/ 2>/dev/null
echo "@sssd"
if [ "$SUDO" = "-" ]; then
  echo "unknown(needs-root)"
else
  k='access_provider|simple_(allow|deny)|ldap_access'
  k="$k|ad_access_filter|ad_gpo_access_control"
  k="$k|(fallback|override)_homedir"
  C=
  for d in /etc/sssd /usr/local/etc/sssd; do
    C="$C $d/sssd.conf $($SUDO ls "$d/conf.d" 2>/dev/null \
      | sed -n "s|.*\.conf\$|$d/conf.d/&|p")"
  done
  for f in $C; do
    $SUDO grep -HE "^[[:space:]]*(\[domain/|($k))" "$f" 2>/dev/null
  done
  for f in /etc/nslcd.conf /usr/local/etc/nslcd.conf; do
    $SUDO grep -HE '^[[:space:]]*(uri|base|pam_authz_search)[[:space:]]' \
      "$f" 2>/dev/null
  done
  if command -v sssctl >/dev/null 2>&1; then
    for d in $($SUDO sssctl domain-list 2>/dev/null); do
      $SUDO sssctl domain-status "$d" -o
    done
  fi
fi
echo "@sudoers"
rd() {  # a rules file, continuation lines joined, comments out
  $SUDO sed -e ':a' -e '/\\$/N' -e 's/\\\n/ /' -e 'ta' "$1" \
    2>&1 | grep -vE '^[[:space:]]*($|#([^0-9]|$))' \
    | sed "s|^|$1:|"
}
wh() {  # print a rule up to its first command, never an argument
  sed -E -e 's#setenv[[:space:]]*\{[^}]*\}#setenv { <withheld> }#' \
    -e 's#([[:space:]]cmd[[:space:]]+[^[:space:]]+)[[:space:]].*#\1 <rest withheld>#' \
    -e 's#([[:space:],!:=)^])(/[^[:space:],]*)[[:space:]].*#\1\2 <rest withheld>#'
}
R=
O=
if [ "$SUDO" = "-" ]; then
  echo "unknown(needs-root)"
elif command -v visudo >/dev/null 2>&1; then
  V=$($SUDO visudo -c 2>&1)
  rc=$?
  printf '%s\n' "$V" | wh
  echo "visudo-rc=$rc"
  echo "sudo: $(sudo -V 2>/dev/null | head -n 1)"
  F=$(printf '%s\n' "$V" | sed -n 's|^\(/[^:]*\): .*|\1|p' | tr '\n' ' ')
  if [ -z "${F% }" ]; then
    M=$($SUDO sudo -V 2>/dev/null \
      | sed -n 's/^Sudoers path: //p' | tr : ' ')
    for m in ${M:-/etc/sudoers /usr/local/etc/sudoers}; do
      [ -e "$m" ] && { F=$m; break; }
    done
  fi
  S=
  for pass in 1 2 3; do
    for i in $($SUDO sed -nE -e 's/^[@#]includedir[[:space:]]+/d:/p' \
      -e 's/^[@#]include[[:space:]]+/f:/p' $F); do
      L=${i#?:}
      [ "${i%%:*}" = d ] && L=$($SUDO ls -A "$L" 2>/dev/null \
        | sed "s|^|${i#d:}/|")
      for x in $L; do
        if [ "${i%%:*}" = d ]; then
          case ${x##*/} in *.*|*~)
            case " $S " in *" $x "*) ;; *) S="$S $x" ;; esac
            continue ;;
          esac
        fi
        case " $F " in *" $x "*) ;; *) F="$F $x" ;; esac
      done
    done
  done
  for x in $S; do echo "skipped: $x"; done
  R=$(for f in $F; do rd "$f"; done)
  printf '%s\n' "$R" | wh
else
  echo "sudoers=none"
fi
if command -v doas >/dev/null 2>&1 && [ "$SUDO" = "-" ]; then
  echo "@doas"
  echo "unknown(needs-root)"
elif command -v doas >/dev/null 2>&1; then
  echo "@doas"
  C=$($SUDO ls -d /etc/doas.conf /usr/local/etc/doas.conf 2>/dev/null
    $SUDO ls -A /etc/doas.d 2>/dev/null \
      | sed -n 's|.*\.conf$|/etc/doas.d/&|p')
  O=$(for f in $C; do rd "$f"; done)
  printf '%s\n' "$O" | wh
fi
echo "@groups"
echo "root groups: $(id -Gn root | tr ' ' ,)"
command -v getent >/dev/null 2>&1 && D= || D=dscl
{ printf '%s\n' "$R" | sed -nE \
    's/^[^:]*:[[:space:]]*("%([^"]*)"|%(([^[:space:],\\]|\\.)+)).*/\2\3/p' \
    | sed 's/\\\(.\)/\1/g'
  printf '%s\n' "$O" | sed -E 's/setenv[[:space:]]*\{[^}]*\}//' \
    | sed -nE \
    's/^[^:]*:[[:space:]]*permit[[:space:]]+([a-z]+[[:space:]]+)*:([^[:space:]]+).*/\2/p'
} | sort -u | while IFS= read -r g; do
  if [ -n "$D" ]; then
    echo "group $g: $(dscl . -read "/Groups/$g" GroupMembership 2>&1)"
    continue
  fi
  e=$(getent group "${g#\#}") || { echo "group $g: not found"; continue; }
  src=directory
  cut -d: -f1 /etc/group | grep -Fxq "${e%%:*}" && src=local
  r=${e#*:*:}
  p=
  while IFS=: read -r u _ _ pg _; do
    [ "$pg" = "${r%%:*}" ] && p="$p$u,"
  done < /etc/passwd
  echo "group $g ($src): ${r#*:} primary: $p"
done
echo "@local"
min=$(sed -n 's/^UID_MIN[[:space:]]*//p' /etc/login.defs \
  /usr/etc/login.defs 2>/dev/null | head -n 1)
min=${min:-1000}
K=
N=
while IFS=: read -r u _ uid _ _ h sh; do
  [ "$uid" -ge "$min" ] 2>/dev/null && [ "$uid" -lt 65534 ] || continue
  echo "$u uid=$uid home=$h shell=$sh groups=$(id -Gn "$u" | tr ' ' ,)"
  K="$K $h/.ssh/authorized_keys"
  N="$N $u"
done < /etc/passwd
[ -n "$K" ] && ${SUDO#-} ls -l $K 2>&1
if [ "$SUDO" = "-" ]; then
  echo "sshd=unknown(needs-root)"
else
  $SUDO sshd -T 2>/dev/null \
    | grep -iE '^(usepam|authorizedkeysfile|authorizedkeyscommand) '
fi
if [ -n "$N" ] && getent -s files passwd root >/dev/null 2>&1; then
  for s in $(sed -n 's/^passwd://p' "$NS" 2>/dev/null); do
    case $s in
      sss|ldap|winbind)
        echo "also in $s: $(getent -s "$s" passwd $N 2>/dev/null \
          | cut -d: -f1 | tr '\n' ' ')" ;;
    esac
  done
fi
```

`$F`, `$K` and `$N` stay unquoted on purpose: one word per file or
name. `${SUDO#-}` is empty where there is no privilege path, so
`ls` then runs as the SSH user. The `PATH` line is there because a
normal user's `PATH` over SSH lacks `/usr/sbin` on Debian, where
`visudo`, `sssctl` and `realm` live. The `sshd` of the host's
family file answers `sshd -T` (FreeBSD: `rules/os/freebsd.md` →
sshd). An argument in a rule can carry a password
(`rules/secrets.md`), so `rd` joins a rule's continuation lines
and `wh` prints it only up to its first command that has
arguments, then `<rest withheld>`: after `=`, `:`, `,`, `)` or a
space in sudoers, after `cmd` in doas, whose `setenv { … }`
values are withheld too. It is stricter than the filter of
`rules/privilege-escalation.md` → Sudo, since a file allows forms
sudo's listing never prints. The groups are read from the
unfiltered rules, which never leave the host. Read a withheld rule
as that section says: never as a narrower one than it may be.

macOS keeps the `@sudoers` and `@groups` parts, whose group lookup
uses `dscl` there, and replaces the rest:

```bash
echo "@ds"
dscl /Search -read / CSPSearchPath
dsconfigad -show 2>/dev/null
echo "@local"
dscl . -list /Users UniqueID | while read -r u uid; do
  [ "$uid" -ge 500 ] 2>/dev/null || continue
  a=$(dscl . -read "/Users/$u" NFSHomeDirectory OriginalNodeName 2>&1)
  h=$(printf '%s\n' "$a" | sed -n 's/^NFSHomeDirectory: //p')
  m=; printf '%s\n' "$a" | grep -q '^OriginalNodeName' && m=" mobile"
  echo "$u uid=$uid home=$h groups=$(id -Gn "$u" | tr ' ' ,)$m"
  ${SUDO#-} ls -l "$h/.ssh/authorized_keys" 2>&1
done
if [ "$SUDO" = "-" ]; then
  echo "sshd=unknown(needs-root)"
else
  $SUDO sshd -T 2>/dev/null \
    | grep -iE '^(usepam|authorizedkeysfile|authorizedkeyscommand) '
fi
```

## Where Accounts Come From

**Linux and FreeBSD** look accounts up through `nsswitch.conf`,
which openSUSE may keep under `/usr/etc` only (`rules/os/suse.md`
→ Vendor Defaults under /usr).

| Source in `passwd:`                | Accounts from                      |
|------------------------------------|------------------------------------|
| `files`, `compat`, `systemd` only  | the local files                    |
| `sss`                              | SSSD (AD, FreeIPA, LDAP)           |
| `ldap`                             | `nslcd` (nss-pam-ldapd)            |
| `winbind`                          | Samba winbind (AD)                 |
| another (`kanidm`, `oslogin`, …)   | an agent (`rules/accounts.md`)     |

An entry is not proof of a directory, and neither is a profile:
installing `libnss-sss` on Debian adds `sss` to the file, and
`sssd` is the default authselect profile on RHEL 8 and 9, both
with no directory at all. A directory is configured where
`realm list` names a realm, SSSD has a domain (a `[domain/…]`
line under `@sssd`, a name from `sssctl domain-list`),
`nslcd.conf` names a `uri`, or `smb.conf` says `security = ads`
for winbind; then its daemon's state decides whether it serves.
`realm list` names the domain, its `server-software`
(`active-directory`, `ipa`) and its `login-policy`; it needs the
realmd service and the system bus, so no output means no realm
joined through realmd, not no directory. `authselect current`
(RHEL, Fedora) names the profile and its features. On FreeBSD
the directory comes from ports (`security/sssd2` with its
configuration under `/usr/local/etc/sssd`, `net/nss-pam-ldapd`);
the base system has no LDAP source, and a `+` or `-` line in
`/etc/passwd` is NIS.
Where systemd does not run — FreeBSD, Alpine, a container, WSL
without systemd — the probe's `running:` line names the daemons
that run instead of `systemctl is-active`.

Alpine's musl has no NSS: `nsswitch.conf` there changes nothing,
`getent` takes no `-s`, and the accounts are the local files.

**Who may log in from the directory.** The `@sssd` lines come
with their file, in the order SSSD reads them: `sssd.conf`, then
the `conf.d/*.conf` snippets alphabetically, a later file winning
for the same domain and setting; copies such as `sssd.conf.bak`
are not read. Each `[domain/…]` line opens the settings that
follow it in its file. A domain admits every directory user unless
its access rule narrows it:

- `access_provider` unset or `permit`: everyone.
- `simple`: only with a `simple_allow_users` or
  `simple_allow_groups` line; deny lists alone, or no lists,
  admit everyone else. `realm permit -g <group>` writes this.
- `ldap`: the `ldap_access_filter`.
- `ad`: the `ad_access_filter` where there is one; without it,
  only expired accounts and the GPO logon rights
  (`ad_gpo_access_control`) keep anyone out.
- `ipa`: the HBAC rules in FreeIPA, which the host cannot show.
  FreeIPA ships the `allow_all` rule enabled, which admits
  everyone until an admin disables it; ask the user.

realmd's `allow-realm-logins` admits the whole domain,
`allow-permitted-logins` only the permitted logins and groups.
`nslcd` admits every directory user unless `nslcd.conf` has a
`pam_authz_search`, and `pam_winbind` unless it has a
`require_membership_of`. sshd runs this PAM account check for key
and certificate logins too. `sssd.conf` and `nslcd.conf` hold the
bind password, so the probe reads them filtered by key and never
whole (`rules/secrets.md`).

`sssctl domain-status <domain> -o` says whether SSSD reaches the
directory. Offline, accounts and sudo rules come from its cache,
and a person removed from the directory may still resolve for a
while.

**Where one account comes from.** The first source in `passwd:`
that knows the name answers. A line in `/etc/passwd` is local;
otherwise `getent -s <source> passwd <name>` (glibc; exit 2: not
there) names the source. On FreeBSD, found by `getent` but not
in `/etc/passwd` means the directory. The details come from
`sssctl user-show <name>` (SSSD, root), `wbinfo -i <name>`
(winbind), `userdbctl user <name>` (systemd), or the agent's own
tool. FreeBSD's `getent` has no `-s`, so the probe prints no
`also in` line there.

**macOS** uses Open Directory. `CSPSearchPath` with
`/Local/Default` alone means local accounts; `/Active
Directory/…` a Mac bound to AD, whose `dsconfigad -show` names
the domain and the AD groups with local admin rights;
`/LDAPv3/<server>` an LDAP directory. A `/Platform SSO` entry
appears on current macOS without Platform SSO configured and
proves nothing alone. For one account,
`dscl . -read /Users/<name> RecordName` succeeds for a local one,
`dscl /Search -read /Users/<name> RecordName` finds it anywhere.
An account the probe marks `mobile` has an `OriginalNodeName`: an
AD account cached in the local node, which the directory still
controls.

## Home Directory at First Login

A directory account has no home until something creates it.
Without one its `~/.ssh/authorized_keys` cannot exist, so key
logins fail; certificate logins and keys from the directory
(`AuthorizedKeysCommand`, such as `sss_ssh_authorizedkeys`)
still work, and the session starts in `/`.

The probe's `@mkhomedir` lists the PAM files that create it.
`grep -R`, not `-r`: authselect makes the files in `/etc/pam.d`
symlinks, which `-r` skips.

- **RHEL, Fedora:** `authselect current` lists `with-mkhomedir`,
  which needs `oddjobd` active.
- **Debian, Ubuntu:** `pam_mkhomedir.so` in
  `/etc/pam.d/common-session`, from
  `pam-auth-update --enable mkhomedir`.
- **FreeBSD:** the `security/pam_mkhomedir` port, listed in
  `/etc/pam.d/sshd`.
- **macOS:** the AD plugin creates local homes unless
  `dsconfigad -show` has the local home option off.

Homes on NFS or autofs are shared, not created: `mount` and
`/etc/auto.master` show them.

**Where homes live** is not always `/home`: macOS keeps them in
`/Users`, and SSSD puts directory users where `fallback_homedir`
or `override_homedir` says, one level deeper where the template
has `%d`. The home roots are the parents of the homes the probe
lists, plus that template.

## The Sudo Model

**Where rules come from.** The files, plus a directory where the
`sudoers:` line in `nsswitch.conf` names one: `sss` for SSSD and
FreeIPA, `ldap` for sudo's own LDAP. No `sudoers:` line means
the files only. The files are the main `sudoers` and what it
pulls in with `@includedir` (`#includedir` in older files),
usually a `sudoers.d` directory with one file per package or
purpose.

The paths differ by OS and build — `/usr/local/etc` on FreeBSD,
two on openSUSE (`rules/os/suse.md` → Vendor Defaults under /usr)
— so the probe takes them from sudo: the files `visudo -c` names,
plus every file an `@include` or `@includedir` (or its `#` form)
pulls in, which the probe follows itself three levels deep. It
reads the rules from those with `grep`. An include with a
relative path or a `%h` in it is not followed: read it by hand.
The files are mode `0440`, so this needs root or `sudo -n`.

- **sudo-rs**, the default `sudo` on Ubuntu 25.10 and later, is
  named on the probe's `sudo:` line. Its `visudo -c` names only
  the main file, which is why the probe follows the includes
  itself, and it reads no rules from SSSD or LDAP: a `sudoers:`
  line naming `sss` or `ldap` changes nothing there.
- **A parse error** stops `visudo -c` at the first bad file, which
  it names with the line; the probe then starts from the main file
  `sudo -V` names. sudo 1.9.3 and later drops only the part of the
  line with the error and applies the rest of the file; an older
  sudo refuses to run at all.
- **A file skipped without a word:** in an `@includedir`
  directory, a name that contains a `.` or ends in `~`. `visudo
  -c` does not list it and its rules are not in effect; the probe
  prints it as `skipped:`.
- **doas**, on Alpine instead of sudo (`rules/os/alpine.md` →
  Privileges) and from ports on FreeBSD: one rule a line,
  `permit [<options>] <user>|:<group> [as <target>] [cmd <command>]`
  with options such as `nopass` or `setenv { … }`,
  printed under `@doas`; a `:group` is resolved under `@groups`
  like a sudoers `%group`.

**Who is in the groups.** Most sudo rights come through a
`%group` rule: `%sudo` on Debian and Ubuntu, `%wheel` on RHEL,
Fedora and FreeBSD, `%admin` on macOS. Only the groups a rule
names count. A group's members are its member list and the
accounts whose primary group it is; the probe prints both, and
whether the group is `local` (in `/etc/group`) or comes from the
`directory`. A group whose name has a space is written
`"%domain admins"` or `%domain\ admins`; a rule may also name a
user by UID, `#1001`, and a group by GID, `%#27`. A directory
group may list no members through `getent`, since SSSD does not
enumerate by default. `id -Gn <user>` lists one person's groups,
directory groups included. The probe's list misses a group inside
a `User_Alias`, after a comma or on a line continued with `\`, and
shows a non-Unix group (`%:"Domain Users"`, from sudo's
`group_plugin`) as not found: read those rule lines, and look such
a group up with `getent group <name>` or in the directory.

**Effective rules for one account**, directory rules included,
which the files alone never show: `sudo -l -U <user>` as root;
`sudo -n -l` as the account itself, which answers without a
password only where some rule has `NOPASSWD`. Either is a sudo
listing: pipe it through the filter of
`rules/privilege-escalation.md` → Sudo, with `LC_ALL=C` in front,
as that section does.

**Run-as.** A rule makes its holder root only where its run-as
list can name root: `ALL`, `root`, `#0`, a `%group` whose members
include root (FreeBSD's `wheel` and macOS's `admin` do; the
probe's `root groups:` line lists them all), a `Runas_Alias`
holding any of these, or no run-as at all while
`Defaults runas_default` is unset or root — unless the list
excludes root, as `(ALL, !root)` does
(`rules/privilege-escalation.md` → Mixed Mode reads run-as lists
the same way). `(backup)`, a list or alias of other accounts and
groups without root, and `(:group)`, which sets only the group and
runs as the calling user, do not; such a rule gives what its
targets can do. A run-as applies to every command after it on the
same line, up to the next one:
`deploy ALL=(backup) NOPASSWD: /x, (root) ALL` holds both. For
doas, a rule without `as`, or `as root`, is root.
A rule that runs as root is a root rule below and in the ratings.

**What to note per user or group:**

- `ALL` or a list of commands, and the run-as of each.
- `NOPASSWD` on `ALL`, on some commands, or none.
- A password rule for people who log in only with a certificate:
  it works only where PAM checks a password they have, such as
  the directory's through SSSD. Otherwise the user chooses:
  `NOPASSWD` for that group only, which makes a certificate root
  for its lifetime where the rule is a root rule, or a password
  for each person.
- `Defaults !authenticate` (no password for anyone), `targetpw`
  or `rootpw` (the target's or root's password), `runas_default`
  (what a rule without a run-as runs as). openSUSE ships
  `ALL ALL=(ALL) ALL` together with `targetpw`.

## Local Accounts

The people's accounts in the local files: UID from `UID_MIN` in
`login.defs` (1000 where it is missing; 500 on macOS, as
`.agents/skills/hostwarden-security/references/user-accounts.md`
→ macOS counts them) up to below `nobody`, macOS mobile accounts
excepted. System accounts below that are that file's. The probe's
`@local` lists each with its home, shell and groups, then which
homes hold an `authorized_keys`. Without root it sees only the
homes it may read: report the others' keys as unchecked, never
as absent.

The probe lists `~/.ssh/authorized_keys` only. Its
`authorizedkeysfile` line names every file sshd reads — by
default `.ssh/authorized_keys` and `.ssh/authorized_keys2`, on
some hosts `/etc/ssh/authorized_keys/%u` — and
`authorizedkeyscommand` a program that hands out keys from
elsewhere. List the other files per account with `ls -l` too, and
report keys from the command as unseen; an account without the
first file is not keyless on that alone.

On a directory host, `also in <source>` names the local accounts
the directory knows too. Such a name exists twice, and only the
first source in `passwd:`, usually `files`, logs in with it.

An account without a password (`!` or `*` in the shadow field)
still logs in with a key or certificate where sshd runs with
PAM. Without PAM — `usepam no`, or no `usepam` line at all, as
from Alpine's PAM-less build — sshd refuses a locked account
(`!`), and an account meant for key logins gets `*` instead.
