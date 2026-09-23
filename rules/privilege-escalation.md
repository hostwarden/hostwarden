# Privilege Escalation

**Local mode:** when the target is the local
machine, skip the root SSH fallback entirely. If
sudo is unusable, go straight to unprivileged mode
(see `AGENTS.md` → Local mode) — after the stand-in
from Stand-ins for sudo below, where the OS file names
one.

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

## Root-Equivalent Groups

Membership in the `docker` group is root: the daemon
behind the socket starts a container that mounts any
host path on request
(<https://docs.docker.com/engine/security/#docker-daemon-attack-surface>).
A user in it needs no sudo for Docker. Record
`- Root-equivalent group: docker` in server memory,
and use it only for the Docker work
`rules/containers.md` describes. It is one check's
access, not the session's: without sudo and without
root SSH the session stays unprivileged, packages,
the firewall, services and system files are still
reported as skipped, and the run still ends in a
sysadmin report. Never add a user to the group.

The same holds for `libvirt`, `incus-admin` and
`lxd`, whose members manage the host's guests: record
the group the same way, and use it only for the guest
work `rules/hypervisors.md` and
`rules/system-containers.md` describe.

## Stand-ins for sudo

The loaded OS file may have a `## Privileges` section
that names a tool standing in for `sudo -n` where sudo
is unusable: `doas` on Alpine (`rules/os/alpine.md`),
`wsl.exe -u root` on WSL (`rules/platform/wsl.md`).
Probe it as that section says and record the line it
gives. Where it works and sudo does not, it stands in
for `sudo -n` wherever an instruction names it, for the
whole session. It comes before the root SSH fallback,
and in local mode before unprivileged mode.

A probe that runs as one non-interactive call works
out its privilege prefix once, at its top, and never
asks for a password:

```bash
if [ "$(id -u)" = 0 ]; then SUDO=""
elif sudo -n true 2>/dev/null; then SUDO="sudo -n"
elif doas -n true 2>/dev/null; then SUDO="doas -n"
else SUDO=-; fi
```

`$SUDO` goes unquoted in front of a command, so an
empty value disappears. `-` means there is no
privilege path: the probe then prints
`unknown(needs-root)` in place of the answer, never a
degraded one. `wsl.exe -u root` is not a prefix — it
takes the bundle on stdin (`rules/platform/wsl.md`) —
so the snippet leaves it out.

## Root SSH Fallback

When sudo is unusable and a privileged action is
needed, probe root SSH access once, with the
fresh-login options (`rules/ssh-connections.md`) — a
shared root connection opened earlier would answer
even if root login has been disabled since:

```
ssh -F "<checkout>/memory/ssh_config" \
  -o ControlMaster=no -o ControlPath=none root@hostname "id" 2>&1
```

First compare `ssh -F "<checkout>/memory/ssh_config" -G
root@hostname` with the same output for the SSH user, on the
`hostname`, `port`, `hostkeyalias` and `proxyjump` lines. Where
one differs, a `Match user root` block sends root another way:
run steps 1–4 of `rules/first-connection.md` for root's endpoint,
blacklist, read-only list, DNS check and host key, and for each
jump host root's `proxyjump` line names, as
`rules/access-control.md` → Server Blacklist and
`rules/host-keys.md` → Before the First Connection say. A
different port is another machine until the user says otherwise
(`rules/dns-aliases.md` → IP Verification): stop and ask. Either
way, a host key missing for root's endpoint or a hop fails the
probe before it logs in and says nothing about root login: get it
first.

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

The report is where unprivileged mode ends
(`rules/borrowed-rights.md`).
