# Privilege Escalation

**Local mode:** when the target is the local
machine, skip the root SSH fallback entirely. If
sudo is unusable, go straight to unprivileged mode
(see `AGENTS.md` → Local mode).

Where the loaded OS file has a `## Privileges`
section, read it first: it adds to the probes below or
replaces them, as it says. Unprivileged mode applies
either way.

## Sudo

When connecting as a non-root user and a privileged
action is first needed, check availability, then
probe:

```
command -v sudo && sudo -n true
```

- **`sudo` not found** -> record
  `- Sudo: unavailable (not installed)`.
  Proceed to root SSH fallback.
- **Probe exits 0** -> sudo works. Record
  `- Sudo: passwordless` in server memory.
- **Probe non-0** -> read the error message to
  tell the cases apart and record the accurate
  reason: `- Sudo: requires password (unusable)`
  for a password prompt, or
  `- Sudo: no sudoers entry (unusable)` for a
  "not in the sudoers file" error.
  Proceed to root SSH fallback.

On subsequent connections, check server memory for
the sudo flag.

## Doas

Where `sudo` may be missing — on Alpine, whose
default is `doas` (`rules/os/alpine.md` → Notes) —
send this probe in place of the one above, before
falling back to root SSH:

```
command -v sudo && sudo -n true && echo sudo=ok
command -v doas && doas -n true && echo doas=ok
```

Judge each tool by its own `=ok` line, never by the
exit status of the whole call: the last command
decides that. Record the sudo line as above, and
`- Doas: passwordless` or
`- Doas: requires password (unusable)` next to it.
When doas works and sudo does not, `doas -n` stands in for
`sudo -n` wherever an instruction names it, for the
whole session.

## Root SSH Fallback

When sudo is unusable and a privileged action is
needed, probe root SSH access once, with the
fresh-login options (`rules/ssh-connections.md`) — a
shared root connection opened earlier would answer
even if root login has been disabled since:

```
ssh -o BatchMode=yes -o ConnectTimeout=5 \
  -o ControlMaster=no -o ControlPath=none \
  root@hostname "id" 2>&1
```

- **Works:** record `- Root SSH: available`.
- **Fails:** keep the recorded sudo line, add the
  following, and enter unprivileged mode:
  ```
  - Root SSH: unavailable
  - Privilege mode: unprivileged
  ```

Only probe when a privileged action is actually
needed. On later connections, read `Root SSH:` from
server memory instead of probing again: a refused
root login can count toward a fail2ban ban
(`rules/ssh-connections.md` → Avoid failed logins).

## Unprivileged Mode

When neither `sudo` nor root SSH is available.

**1. Announce** to the user that you'll work as
the current user and produce a sysadmin report.

**2. Continue with userspace:** read-only inspection,
home directory, user-space tools, user-level cron
and systemd services.

**3. Defer root tasks:** package install/remove,
system services, firewall, system config files,
system users/groups. Announce each deferral briefly.

**4. Sysadmin report** at session end:

```
## Sysadmin Report for [hostname]

These tasks require root access. The server runs
[OS].

### Package Installation
    apt-get install -y nginx
Why: [brief reason]

### Firewall
    ufw allow 80/tcp
Why: [brief reason]
```

Use distro-correct commands, group by category,
include specific commands and brief "why" context.
