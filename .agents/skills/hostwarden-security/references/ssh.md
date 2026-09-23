# SSH — Password Authentication & Hardening

**Note:** Reading sshd's configuration is safe. The AGENTS.md
taboo is about *modifying* it, not reading it: read it with `cat`,
`grep`, `sshd -G` or `sshd -T`, never through a language runtime.

## sshd's Effective Configuration

Every sshd check in this file judges the values sshd really uses,
read once per host with the probe below; on macOS, only once
Remote Login is on (→ SSH Password Authentication — macOS).
`sshd_config` and `sshd_config.d/*.conf` in `/etc/ssh` are not all
there is: an `Include` can name any file, a family can keep the
configuration elsewhere, and a daemon started with `-f` reads
another file entirely. `rules/os/<family>.md` → sshd says where
this family keeps it and where a `-f` is set, and names a family
whose files only root can read.

- `sshd -G` prints the effective configuration without loading the
  host keys (OpenSSH 9.3 and newer), so it needs no root wherever
  the configuration files are readable.
- `sshd -T` prints the same after loading the host keys, so it
  needs root. The probe falls back to it for older OpenSSH.
- `-dd` adds a debug line for every file read, includes followed:
  `load_server_config: filename <path>`. Debug lines end in `\r`,
  hence the `tr`.
- A `-f` on a running daemon's command line is carried over, one
  run per file. Without one, sshd reads its default file. The
  `daemon:` lines show that command line whole: a `-o` or `-p`
  there overrides the file for its keyword, and neither run shows
  it.
- Since OpenSSH 10.4 both print keywords in mixed case
  (`PasswordAuthentication`), so always filter with `grep -i`.

The last grep takes every keyword this file and the blocklistd
check in `references/intrusion-prevention.md` judge. The one before
it lists the `Match` blocks (→ Match blocks below). Run the probe
and the SSH client check below in one bundle
(`rules/ssh-connections.md` → Bundle commands):

```bash
PATH=$PATH:/usr/sbin:/usr/local/sbin
D=$(ps ax -o args= | grep '^[^ ]*sshd:\{0,1\} \(.* \)\{0,1\}-[[:alpha:]]')
printf '%s\n' "$D" | sed 's/^/daemon: /'
FS=$(printf '%s\n' "$D" \
  | sed -e 's/^[^ ]*sshd:\{0,1\} \(.* \)\{0,1\}-f \([^ ]*\).*/\2/' \
    -e t -e 's/.*/default/' | sort -u)
for F in $FS; do
  set --
  [ "$F" = default ] || set -- -f "$F"
  echo "== sshd config: $F"
  OUT=$(sshd "$@" -dd -G 2>&1) || OUT=$(sshd "$@" -dd -T 2>&1) || {
    printf '%s\n' "$OUT" | tr -d '\r' | grep -v '^debug' | tail -n 2
    continue
  }
  R=$(printf '%s\n' "$OUT" | tr -d '\r' \
    | sed -n 's/.*load_server_config: filename //p' | sort -u)
  [ -z "$R" ] || { printf 'reads: %s\n' $R
    grep -Hin '^[[:space:]]*match[[:space:]]' $R; }
  printf '%s\n' "$OUT" | grep -iE \
    -e '^(passwordauthentication|kbdinteractiveauthentication) ' \
    -e '^(usepam|authenticationmethods|permitemptypasswords) ' \
    -e '^(permitrootlogin|ciphers|macs|kexalgorithms) ' \
    -e '^(maxauthtries|x11forwarding|use(block|black)list) '
done
```

The `reads:` lines are what the rest of this file calls the files
sshd reads. Where no sshd runs yet — launchd on macOS starts one
per connection, a socket unit on the first — a `-f` sits in the
service definition instead, where `rules/os/<family>.md` → sshd
says. That section also names the tool that checksums a file sshd
reads, for comparing it with a backup or another host's copy.

When both runs fail, the probe prints sshd's own reason, such as
`Permission denied` or `no hostkeys available`. Read the files then
(→ Fallback below) and say in the report that the values come from
the files, not from sshd.

### Which sshd — FreeBSD

Base system or package: `rules/os/freebsd.md` → sshd says which
one is enabled and where its configuration lives. Replace `sshd`
in the probe by the enabled one's full path, and in the fallback
read the files in its configuration directory, not `/etc/ssh`.

### Match blocks

The probe prints the values outside every `Match` block. A block
changes them for the users, groups or addresses its condition
names, so a `Match Address` that allows passwords from one network
is exactly what the probe leaves out. The probe lists the blocks,
`<file>:<line>:Match …`.

For each block, ask sshd for the values a connection it matches
gets: a user, group member or address its condition names, with
the probe's `-f` where it had one, and filter the output with the
probe's last grep. All blocks go in one bundle. `-C` works only
with `-T`, so this needs root; without it, list the blocks under
Skipped (`references/unprivileged.md`).

```bash
sshd -T -C user=<user>,host=<name>,addr=<address>
```

OpenSSH 8.1 and newer accept any of the three. Older releases
refuse a `-C` that lacks an attribute a `Match` line tests, and
releases before 7.7 want `user`, `host` and `addr` every time, so
give all three there. A block whose values fail a check below is
reported under that check, the block named:
`WARN SSH accepts passwords (Match Address 192.0.2.0/24)`.

## SSH Password Authentication — Linux and FreeBSD

Check whether sshd allows password-based logins. Key-based
authentication should be required; password auth should be
disabled. The values come from the probe above.

With `UsePAM yes`, PAM asks for the Unix password over
keyboard-interactive, so `KbdInteractiveAuthentication yes`
accepts passwords although `PasswordAuthentication` says `no`.
FreeBSD ships exactly that combination. Where the `auth` lines of
`/etc/pam.d/sshd`, includes followed, carry no password module
(`pam_unix`) — a token or MFA module only — report the modules as
INFO instead of the warning below.

- **WARN** "SSH accepts passwords" if `passwordauthentication` is
  `yes`, or `kbdinteractiveauthentication` and `usepam` are both
  `yes` — unless `authenticationmethods` requires `publickey` in
  every one of its lists
- **CRITICAL** if `permitemptypasswords` is `yes`
- Otherwise OK

### Fallback (config files)

When the probe gets no values, read the files directly, in one
call: the main file — the one a `-f` names, or the family's
default (`rules/os/<family>.md` → sshd) — and every file its
`Include` lines name, followed the same way.

```bash
cat <main file> <files its Include lines name> 2>/dev/null
```

Parse the files for `PasswordAuthentication`,
`KbdInteractiveAuthentication` (or its older spelling
`ChallengeResponseAuthentication`) and `UsePAM`. FreeBSD lists its
compiled defaults as comments, so a keyword that is only commented
out there keeps the default: both of the latter `yes`. The first
obtained value wins (`sshd_config(5)`), so a drop-in included
at the top overrides the main file; sshd's own output is
authoritative. Some distributions set `PasswordAuthentication no`
in a drop-in, so never assume the compiled default.

- Judge the effective values as above
- If the files are unreadable → note in the report that the
  check could not be performed

## SSH Password Authentication — macOS

### Check if Remote Login is enabled

```bash
systemsetup -getremotelogin 2>/dev/null
```

Or check whether launchd has sshd loaded in the `system` domain
(`rules/os/macos.md` → Service Manager); exit 0 means on:

```bash
launchctl print system/com.openssh.sshd >/dev/null 2>&1
```

- If Remote Login is **off** → **INFO** "Remote Login (SSH) is
  disabled — sshd checks skipped." Skip the sshd checks in this
  file, but still run SSH servers past sshd and the SSH client
  check below: an agent serves its own SSH whether or not Remote
  Login is on, and the client connects out either way.
- If Remote Login is **on** → run the probe above and judge its
  values as on Linux.

## SSH Hardening

These checks read the probe's output above, or the config files as
fallback, on every family.

### PermitRootLogin

Fallback: parse from the files the fallback read.

- `yes` or `prohibit-password` → **INFO** (root SSH is normal in
  Hostwarden — this is informational only)
- `no` → OK

### Weak SSH Algorithms

Fallback: parse `Ciphers`, `MACs`, and `KexAlgorithms` from
config files.

Flag any of these as **WARN**:

- **Ciphers:** `3des-cbc`, `arcfour`, `arcfour128`, `arcfour256`,
  `blowfish-cbc`, `cast128-cbc`
- **MACs:** `hmac-md5`, `hmac-md5-96`, `hmac-sha1-96`,
  `umac-64@openssh.com`
- **KEX:** `diffie-hellman-group1-sha1`,
  `diffie-hellman-group-exchange-sha1`
- **Host key types:** `ssh-dss`

Report each weak algorithm found with its category.

### MaxAuthTries

Fallback: parse from config files. Default is 6.

- Value > 4 → **INFO**
- Value ≤ 4 → OK

### X11Forwarding

Fallback: parse from config files.

- `yes` → **INFO**
- `no` → OK

Skip this check on macOS.

## SSH servers past sshd

Some VPN and tunnel agents let people in without sshd, where none
of the checks above look. Find them in the same batch, no root
needed, with the first block of `rules/mesh-vpn.md` → Probe (no
root), which prints one `<pid> <program>` line per VPN agent. Of
those, `tailscaled`, `netbird`, `newt`, `nebula`, `dnclient` and
`cloudflared` serve SSH themselves.

No line for one of these six → OK, nothing more to check.
Otherwise read `references/vpn-ssh.md`, which reads each of those
agents from its own process.

## SSH Client on the Server — Linux, FreeBSD and macOS

An account that connects out from the server — root, a backup or
deploy account, the users of a jump host — trusts whatever host key
its SSH client accepts. `StrictHostKeyChecking no` accepts any key,
and `UserKnownHostsFile /dev/null` forgets each one it saw, so the
check that would notice a man in the middle is off for every
target in that scope.

Read the system configuration and each account's own, and the
same options given on a command line in a crontab, in the bundle
of the sshd probe. As root this covers every account; without
root, the session user's file and what else is readable
(`references/unprivileged.md`). macOS has no `getent`, so its
homes come from `dscl`. The crontab directories cover every
family's spool, as `rules/file-naming-changes.md` lists them.

```bash
U=$(if command -v getent >/dev/null; then getent passwd | cut -d: -f6
  else dscl . -list /Users NFSHomeDirectory | sed 's/^[^ ]* *//'
  fi | sort -u | while read -r h; do
    [ -f "$h/.ssh/config" ] && echo "$h/.ssh/config"
  done)
grep -Hin -e '^[[:space:]]*\(host\|match\|include\)[[:space:]]' \
  -e '^[[:space:]]*\(stricthostkeychecking\|userknownhostsfile\)' \
  /etc/ssh/ssh_config /etc/ssh/ssh_config.d/*.conf \
  /usr/etc/ssh/ssh_config /usr/etc/ssh/ssh_config.d/*.conf \
  /usr/local/etc/ssh/ssh_config $U 2>/dev/null
grep -rIin -e 'stricthostkeychecking[= ]*\(no\|off\)' \
  -e 'userknownhostsfile[= ]*/dev/null' \
  /etc/crontab /etc/cron.d /var/spool/cron /var/cron/tabs \
  /var/at/tabs /etc/crontabs 2>/dev/null
```

An option belongs to the nearest `Host` or `Match` line above it
in the same file; above the first, it applies to every target. An
`Include` names more files, relative to `~/.ssh` in an account's
file and to `/etc/ssh` in the system one: grep them the same way.
The first value obtained wins, the account's file before the
system one. Where that leaves the effect unclear,
`ssh -G <target>`, run as that account, prints the effective
values for a target without connecting (`false` for `no`). It runs
the command of a `Match exec` line, though, so use it only where
the files have none.

- `StrictHostKeyChecking no` or `off` in any scope, or the same
  on a crontab's command line → **WARN** "SSH client accepts any
  host key", naming the account, the file and the `Host` or `Match`
  line: `WARN SSH client accepts any host key (root, Host
  backup.example.com)`
- `UserKnownHostsFile /dev/null` in a scope where
  `StrictHostKeyChecking` is not `yes`, or on a crontab's command
  line → **WARN**, the same way
- `StrictHostKeyChecking accept-new` → **INFO**: the first
  connection to each target is not checked
- Otherwise OK
