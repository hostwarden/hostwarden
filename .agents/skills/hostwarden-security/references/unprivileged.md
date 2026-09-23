# Unprivileged Mode

When running in unprivileged mode (no sudo, no root SSH), run the
sshd probe in `references/ssh.md` as it stands: its `sshd -G` needs
no root where the files are readable, and where they are not, use
its config file fallback; beside mixed sudo, only for what it does
not cover (`rules/privilege-escalation.md` → Mixed Mode). For
firewall checks, attempt the command — some firewall status
commands work without root.

Many checks in this audit work without root:

- **Works unprivileged:** `sshd -G` where sshd's configuration
  files are readable (`references/ssh.md`), SSH config file
  parsing, the session user's own SSH client configuration,
  multiple UID 0 accounts, system accounts with login shells,
  listening services (without process names on Linux), all sysctl
  checks, world-writable system files, SUID/SGID audit, mount
  options, unowned files, fail2ban status (`systemctl`,
  `rc-service`), macOS checks (SIP, FileVault, Gatekeeper), host
  certificates (`*-cert.pub` is public; which one sshd serves
  comes with `sshd -G`).
- **Needs root:** `sshd -T`, evaluating sshd's `Match` blocks
  (`sshd -T -C`), the user CA's key file, principals files and
  revocation list where only root reads them, other accounts' SSH
  client configuration and the crontabs other than the session
  user's, empty password accounts
  (`/etc/shadow`), listening services with process names on Linux
  (`ss -tulnp`), cron directory permissions (some dirs may be
  unreadable), and the container audit — except with `docker`
  group membership, or for the session user's own rootless
  containers.

Accounts and sudo (`references/accounts-sudo.md`): the account
source and the local accounts work unprivileged, and so do the
SSH user's own sudo rules (`sudo -n -l`). The sudoers files,
other accounts' rules (`sudo -l -U`), `sssctl`, SSSD's access
rule and other accounts' `.ssh` need root.

On FreeBSD, root is needed for `sshd -T`, `/etc/master.passwd`,
the pf and ipfw rules, and `/var/log/setuid.today`.

On macOS, checks on protected paths follow `Full disk access:` in
memory (`rules/os/macos.md` → Privacy Protection (TCC)).

If a check cannot be performed due to missing privileges, do not
skip it silently. Add it to the report:

```
### Skipped (needs root)

- SSH effective config (sshd -G: sshd_config Permission denied;
  sshd -T requires root)
- SSH Match blocks (2 listed; sshd -T -C requires root)
- SSH client of other accounts (their ~/.ssh unreadable)
- Firewall status (ufw requires root)
- Empty password accounts (/etc/shadow unreadable)
- Listening services process names (ss -p needs root)
```

If config files are world-readable, use the fallback and note
that the result is from config file parsing, not the effective
compiled config.
