# SSH — Password Authentication & Hardening

**Note:** Reading `sshd_config` is safe. The AGENTS.md taboo is
about *modifying* `/etc/ssh/sshd_config`, not reading it.

## SSH Password Authentication — Linux and FreeBSD

Check whether sshd allows password-based logins. Key-based
authentication should be required; password auth should be
disabled.

### Which sshd — FreeBSD

Base system or package: `rules/os/freebsd.md` → sshd says which
one is enabled and where its configuration lives. Call that one by
its full path in every `sshd -T` below, and in the fallback read
the files in its configuration directory, not `/etc/ssh`.

### Preferred method (needs root)

Use `sshd -T` to query the effective compiled configuration.
This resolves Include directives, Match blocks, and defaults —
much more reliable than parsing config files manually. Since
OpenSSH 10.4 it prints keywords in mixed case
(`PasswordAuthentication`), so always filter with `grep -i`.
One call serves every check in this file and the blocklistd
check in `references/intrusion-prevention.md`; the grep below
takes them all.

```bash
sshd -T 2>/dev/null | grep -iE \
  -e '^(passwordauthentication|kbdinteractiveauthentication) ' \
  -e '^(usepam|authenticationmethods|permitemptypasswords) ' \
  -e '^(permitrootlogin|ciphers|macs|kexalgorithms) ' \
  -e '^(maxauthtries|x11forwarding|use(block|black)list) '
```

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

### Fallback method (unprivileged)

If `sshd -T` is unavailable or requires root, read the config
files directly. They are usually world-readable.

```bash
# Main config
cat /etc/ssh/sshd_config 2>/dev/null

# Drop-in configs (OpenSSH 8.2+)
cat /etc/ssh/sshd_config.d/*.conf 2>/dev/null
```

Follow every `Include` line, not just `sshd_config.d/` (macOS
also includes `/etc/ssh/crypto.conf`). Parse the files for
`PasswordAuthentication`, `KbdInteractiveAuthentication` (or its
older spelling `ChallengeResponseAuthentication`) and
`UsePAM`. FreeBSD lists its
compiled defaults as comments, so a keyword that is only commented
out there keeps the default: both of the latter `yes`. The first
obtained value wins (`sshd_config(5)`), so a drop-in included
at the top overrides the main file; `sshd -T` is authoritative.

**Important:** On OpenSSH 8.8+, some distros default
`PasswordAuthentication` to `no` via drop-in files in
`/etc/ssh/sshd_config.d/`. Always check the effective value —
do not assume the compiled default.

- Judge the effective values as above
- If the files are unreadable → note in the report that the
  check could not be performed

## SSH Password Authentication — macOS

### Check if Remote Login is enabled

```bash
systemsetup -getremotelogin 2>/dev/null
```

Or check via launchctl:

```bash
sudo launchctl list com.openssh.sshd 2>/dev/null
```

- If Remote Login is **off** → **INFO** "Remote Login (SSH) is
  disabled — SSH checks skipped." Stop here, no further SSH
  checks needed.
- If Remote Login is **on** → proceed with the same `sshd -T`
  / config file approach as Linux.

macOS sshd config is at `/etc/ssh/sshd_config` (same path as
Linux).

## SSH Hardening

These checks read the `sshd -T` output above, or the config
files as fallback, on every family.

### PermitRootLogin

Fallback:

```bash
grep -i "^PermitRootLogin" \
  /etc/ssh/sshd_config \
  /etc/ssh/sshd_config.d/*.conf 2>/dev/null
```

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
