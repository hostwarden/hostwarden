# Account Source and Sudo Rules — Linux, FreeBSD, macOS

The probe is `rules/accounts-probe.md` → Probe, in an SSH call of
its own, and that file says what its output means. This file says
how to rate it. Three lines in Checks: Account source, Sudo rules,
Local accounts.

## Account Source

Always one line, such as `OK — local files` or
`OK — SSSD, AD example.com, online`.

- A directory is configured — a realm, an SSSD domain, an
  `nslcd.conf` `uri` or winbind with `security = ads` — but its
  daemon is not active → **WARN**: directory accounts cannot log
  in. An authselect profile alone is no directory
  (`rules/accounts-probe.md` → Where Accounts Come From).
- `sssctl domain-status` says offline → **WARN**: accounts and
  sudo rules come from SSSD's cache.
- A directory whose access rule admits every directory user, as
  `rules/accounts-probe.md` → Where Accounts Come From lists them
  for SSSD, realmd, nslcd and winbind → **WARN**; name the
  domain. `ad` without `ad_access_filter` → **WARN** too, noting
  that GPO logon rights may still narrow it. `ipa` → **INFO**: HBAC in
  FreeIPA decides, and its `allow_all` rule admits everyone until
  disabled; ask the user.
- `sss`, `ldap` or `winbind` in `nsswitch.conf` with no directory
  configured → OK, noted in the line.

## Sudo Rules

`NOPASSWD: ALL` is rated by who holds it. Distributions ship
`%sudo` and `%wheel` with a password; `NOPASSWD` comes from
cloud-init's default user, Hostwarden's own account, or accounts
without a password.

- `ALL ALL=(ALL) ALL` without `Defaults targetpw` or `rootpw` →
  **CRITICAL**: every account becomes root with its own password.
  With `targetpw` → **INFO**.
- `NOPASSWD: ALL` for people who log in with a key or certificate,
  one account or an admin group → **INFO**, with the names: a
  deliberate trade, whose key is a root key.
- `NOPASSWD: ALL` for an account a service or an application runs
  as (`deploy`, `www-data`, …) → **WARN**: a hole in the
  application is root.
- `NOPASSWD: ALL` for a group the probe marks `directory` →
  **WARN**: whoever manages the group decides who is root. It may
  list no members here; say "members from the directory", never
  "0".
- `Defaults !authenticate` → **WARN**: every rule, those meant to
  ask included, runs without a password.
- A `NOPASSWD` command that can start a shell or write any file —
  an editor, a pager, a shell, an interpreter, `find`, `tar`, `cp`,
  `tee` → **WARN**: the rule is as good as `ALL`.
- A parse error `visudo -c` reports → **WARN**: the part of the
  line with the error is not in effect, and a sudo older than
  1.9.3 refuses to run at all. A `skipped:` file → **WARN**: none
  of its rules are in effect.
- `sudoers:` names `sss` or `ldap` and the directory is out of
  reach, daemon inactive or domain offline → **WARN**: admins whose
  rules live there lose sudo, or keep rules the directory has
  already revoked.
- Rules from a directory → **INFO**: the local files show only
  part; list the effective rules per admin (`sudo -l -U <user>`).
- The two above apply to classic sudo only. Where the `sudo:` line
  names sudo-rs, a `sudoers:` line naming `sss` or `ldap` →
  **INFO**: sudo-rs reads the files alone, so rules kept in the
  directory grant nothing on this host.
- The members of each other group with `ALL` and a password →
  **INFO**, with the names. A member the user does not recognize:
  ask.

macOS ships `%admin ALL = (ALL) ALL` with a password → OK; its
members are rated in `references/user-accounts.md` → macOS. AD
groups with local admin rights (`dsconfigad -show`) → **INFO**,
with their names. The same ratings apply to `doas` rules, on
Alpine and wherever the probe prints `@doas`: `permit nopass` is
`NOPASSWD`, a rule without `cmd` is `ALL`.

## Local Accounts

Every host, one line with each local account and what it can do:
`Local accounts  INFO — 3: alice (sudo, keys), bob, deploy (keys)`.
"sudo" is membership of a group a rule names, or a rule naming
the account. A login shell is one "System Accounts with Login
Shells" in `references/user-accounts.md` does not call inert.

With a team roster (`rules/accounts.md` → Team Accounts): a local
account not on it → **WARN**, since nobody recorded it, unless an
agent manages it (`rules/accounts.md` → Which Model a Host Uses;
name the agent); a roster account missing or with another UID →
**INFO**.

On a directory host, also:

- A local name the probe finds `also in` the directory → **WARN**:
  two accounts, one name.
- A local account with sudo, or with a login shell and keys in a
  file sshd reads (`rules/accounts-probe.md` → Local Accounts)
  → **WARN** per account: a way in the directory neither controls
  nor revokes. Where a decision names the account as break-glass,
  its line reads `DECIDED` instead (`rules/decisions.md` → Rating
  findings); the audit offers one only when the user says the
  account is meant. A macOS account the probe marks `mobile` is
  the directory's, not local.

Homes whose owner no longer resolves — a person removed from the
directory, or `userdel` without `-r` → **INFO**, count and names.
Only with the directory reachable, or every directory owner looks
gone. Never delete one without the user. Search the home roots
(`rules/accounts-probe.md` → Home Directory at First Login), one
level deeper where SSSD's template has `%d`; `-H` because a root
may be a symlink. busybox `find` has no `-nouser`: on Alpine,
compare owners as `references/file-permissions.md` → Unowned Files
does.

```bash
find -H <root>... -mindepth 1 -maxdepth 1 -nouser
```

Say when an account last logged in only from a record (`last`,
`lastlog2` where installed). No record is "last login unknown",
never "stale" (`rules/verify-before-reporting.md`).
