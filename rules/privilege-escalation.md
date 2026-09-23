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
action is first needed, probe in one call:

```
export LC_ALL=C
command -v sudo && sudo -n -l |
  sed -E 's#([ ,!:^])(/[^ ,]*) .*#\1\2 <rest withheld>#'
```

`sudo -n -l` lists the user's rules, and by default
sudo prints it without a password as soon as one of
them needs none
(<https://www.sudo.ws/docs/man/sudoers.man/>, `listpw`).
The filter cuts each line at the first command that
has arguments, a regular expression such as
`^/usr/bin/(mysql|mysqldump)$` included, and prints
`<rest withheld>` in place of the rest: an argument
can carry a password, and sudo-rs prints a comma
inside one unescaped, so no filter can tell where the
next command starts. A path after `=`, as in
`CWD=/srv`, is an option and stays. The pipe also
keeps each rule on one line: sudo wraps its listing
at 80 columns, even inside a command, unless it
writes into a pipe.
`LC_ALL=C` keeps sudo's messages in English, as
quoted below.

Where the loaded OS file's `## Privileges` section
names a stand-in (below), its probe line goes into the
same call. Judge each tool by its own output, never by
the exit status of the whole call. sudo-rs, the
default `sudo` on newer Ubuntu releases, words its
refusals differently; the quotes below name both.

- **`sudo` not found** -> record
  `- Sudo: unavailable (not installed)`.
- **A listing** -> read it as Mixed Mode says: it
  gives `- Sudo: passwordless`, a mixed line, or,
  where it counts no command, the next case.
- **"a password is required" or "interactive
  authentication is required"** -> record
  `- Sudo: requires password (unusable)`. A `listpw`
  setting can ask for a password to list even rules
  that need none; say so once, since only the user can
  change it.
- **"not in the sudoers file", "may not run sudo" or
  "not allowed to run sudo"** -> record
  `- Sudo: no sudoers entry (unusable)`.
- **Any other error** -> record
  `- Sudo: unusable (<sudo's message>)`, such as a
  sudoers file that requires a terminal.

Every result but passwordless and mixed proceeds to
the root SSH fallback. A single command is no probe:
`sudo -n true` prints "a password is required" for a
user with no sudoers entry and for one whose rules
need no password for some commands only, and it
succeeds for a rule that lets `true` alone run.

On subsequent connections, check server memory for
the sudo flag.

## Mixed Mode

The listing gives the user's rules one per line, as
`(<run-as>) <tags>: <command>, <command>`, in the
order sudo applies them. An entry needs no password
when a `NOPASSWD:` tag precedes it on its line, up to
a `PASSWD:` tag, or when the matching Defaults entries
include `!authenticate` and no `PASSWD:` tag precedes
it. A command counts when all of these hold:

- its line runs as root: its run-as list names
  `root` or `ALL` and does not exclude root, as
  `(www-data)` and `(ALL, !root)` do;
- its entry needs no password and has no `!` in front
  of it;
- it stands after the last line the filter cut:
  withheld text can hide arguments, an exception or a
  password rule, and a rule limited to arguments does
  not count;
- no `!` entry for it, and no later entry that needs a
  password and matches it, stands on its line or a
  later line that runs as root: where several match,
  sudo uses the last, and a later `ALL` matches every
  command.

Where the listing's last line is a counted
`NOPASSWD: ALL` and nothing else, record
`- Sudo: passwordless`: the privilege prefix below
takes sudo for exactly this. Where `ALL` counts any
other way — with exceptions after it, by
`!authenticate`, or with rules after it — record
`- Sudo: NOPASSWD for ALL (mixed)`, and each command
a `!` entry or a later entry with a password names
after it as `except <command>`. Otherwise record the
commands that count in one line, full paths as the
listing prints them:

```
- Sudo: NOPASSWD for selected commands (mixed):
  /usr/bin/systemctl, /usr/bin/journalctl
```

Sudo **covers** a command where memory records it
passwordless, or mixed with `ALL` or the command in
its list, and not as an `except`; other rules ask
this one question of the `Sudo:` line. A listed path
with wildcards covers what it plainly matches. A
check that runs several privileged commands is
covered only where sudo covers each of them: run in
part, it reads a refused command's silence as an
answer.

- **Covered:** run it as `sudo -n <command>`, with no
  pre-check. `sudo -n -l <command>` would be none: it
  exits 0 for any call a rule allows, one that asks
  for a password included. A refusal is sudo's own
  line on stderr: where a check runs a covered command
  through `sudo -n` and sends its stderr to
  `/dev/null`, an empty answer counts as unread.
- **Not covered:** go on as if sudo were unusable,
  from Stand-ins for sudo on. Never use a covered
  command to reach one that is not: an editor, a
  pager or a tool that runs other commands opens a
  root shell under sudo, which is escalation the rule
  did not grant.
- **Refused at run time** ("a password is required",
  "interactive authentication is required", "not
  allowed to execute", "I'm afraid I can't do that",
  or the same in the session's language): the command
  is not covered. Run the probe again and write the
  line from the new listing. Where sudo still covers
  the command by it, add
  `except (refused) <command>`. Writing the line from
  a later listing keeps each `except (refused)` whose
  command sudo still covers by it, unless the user
  says the sudo rules changed.

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
gives. Where it works and sudo is unusable or covers
only some commands (Mixed Mode), it stands in for
`sudo -n` wherever an instruction names it, for the
whole session. It comes before the root SSH fallback,
and in local mode before unprivileged mode.

A probe that runs as one non-interactive call works
out its privilege prefix once, at its top, and never
asks for a password:

```bash
a='^ +\((ALL|root)( : [^)]*)?\) NOPASSWD: ALL$'
if [ "$(id -u)" = 0 ]; then SUDO=""
elif sudo -n -l 2>/dev/null | tail -n 1 | grep -Eq "$a"
then SUDO="sudo -n"
elif doas -n true 2>/dev/null; then SUDO="doas -n"
else SUDO=-; fi
```

`$SUDO` goes unquoted in front of a command, so an
empty value disappears. `-` means there is no prefix
for the whole bundle: the probe then prints
`unknown(needs-root)` in place of the answer, never a
degraded one, and the reruns below decide what stays
so. `wsl.exe -u root` is not a prefix — it
takes the bundle on stdin (`rules/platform/wsl.md`) —
so the snippet leaves it out.

The sudo branch takes sudo only where the listing's
last rule lets root run `ALL` without a password, so
it needs no `Sudo:` line and works on a first
connection too; `sudo -n true` would also pass for a
rule that lets `true` alone run. It takes sudo
exactly where Mixed Mode records `Sudo: passwordless`;
every mixed line leaves `$SUDO` at a stand-in or `-`.
The doas branch has the blind spot `rules/os/alpine.md`
names. The listing does not show an `except (refused)`
from memory: a read whose command is one comes back
refused under `$SUDO`, and is reported as
`unknown(needs-root)`, never as its empty output.

Where `$SUDO` is `-`, the privileged reads are not
done yet. Run the sudo probe above first, even where
memory has a `Sudo:` line: a rule changed since would
refuse a read whose error the probe sends to
`/dev/null`. Decide from its result, with memory's
`except (refused)` entries, as a later listing is
read under Refused at run time. Write the line only
where the flow may write memory; a fleet audit's
probe agent does not. This probe serves the rerun
alone and never leads to the root SSH fallback.

Then send again, together in one call, each section
of the probe that skipped a read for want of `$SUDO`,
with a sentinel or without: from the section's start,
with its variables and filters, and with
`SUDO="sudo -n"` in place of the snippet. Send a
section only where sudo covers every command it runs
under `$SUDO` or a prefix built from it, `sh` for one
wrapped in `sh -c`; the reads that take their input
from it, and the probes a bundle adds on its answers,
go with it. A section sudo covers only in part is not
sent: run in part, it would read a refused command's
silence as an answer. What no rerun reads stays
`unknown(needs-root)`.

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
`hostname`, `port` and `hostkeyalias` lines and on the jump hosts
each gives (`rules/access-control.md` → Server Blacklist): a `%r`
there names root's hop login. Where one differs, a
`Match user root` block sends root another way: run steps 1–4 of
`rules/first-connection.md` for root's endpoint, blacklist,
read-only list, DNS check and host key, and for each of root's
jump hosts, as
`rules/access-control.md` → Server Blacklist and
`rules/host-keys.md` → Before the First Connection say. A
different port is another machine until the user says otherwise
(`rules/dns-aliases.md` → IP Verification): stop and ask. Either
way, a host key missing for root's endpoint or a hop fails the
probe before it logs in and says nothing about root login: get it
first, or for a `ProxyCommand` hop tell the user
(`rules/host-keys.md` → Jump Hosts).

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
Beside a mixed `Sudo:` line, `Privilege mode:
unprivileged` holds only for what sudo does not
cover: a covered command still runs as
`sudo -n <command>`, and only the rest is deferred.

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
