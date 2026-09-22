# Narrowing what the deploy user can do

Steps 4 to 6 of the `hostwarden-deploy-user` skill, after the
account and its key exist: the directory it owns, sudo scoped
to the single command it needs if it needs any at all, and the
login shell override.

## Deployment Directory

Grant the deploy user write access only to the
directory it needs.

```bash
mkdir -p /var/www/myapp
chown deploy:deploy /var/www/myapp
```

Adapt the path to the actual application. Common
locations:

- `/var/www/<app>` — web applications
- `/opt/<app>` — standalone services
- `/home/deploy/<app>` — when no system path fits
- `/usr/local/www/<app>` — web applications on FreeBSD
- on macOS, `/Users/deploy/<app>`, or under the Homebrew prefix
  (`$(brew --prefix)/var/www/<app>`) for a Homebrew web server

Do not grant ownership of directories outside the
deployment target.

## Restricted Sudo (Only If Needed)

If the deploy user must restart a service after
deployment, grant sudo for that specific command
only. **Never grant general sudo.**

```bash
visudo -f /etc/sudoers.d/deploy
```

Content:

```
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp.service
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl reload myapp.service
```

**Rules for the sudoers entry:**

1. One line per allowed command — full path
   required.
2. Only `restart` and `reload` for the specific
   service. Never `start`, `stop`, or wildcards.
3. `NOPASSWD` is required (the deploy user has no
   password).
4. Validate syntax:
   `visudo -c -f /etc/sudoers.d/deploy`
5. Back up per `rules/backups.md` before writing.

On FreeBSD sudo is a package: check `command -v sudo`
first and install it only if the user agrees
(`rules/version-check.md`). The drop-in sits under
`/usr/local/etc` (`rules/os/freebsd.md` → Directory
Conventions), and the command goes through `service`:

```bash
visudo -f /usr/local/etc/sudoers.d/deploy
```

```
deploy ALL=(root) NOPASSWD: /usr/sbin/service myapp restart
deploy ALL=(root) NOPASSWD: /usr/sbin/service myapp reload
```

If the application can reload without sudo (e.g.
via a signal file or socket), prefer that approach
and skip sudoers entirely.

On macOS the drop-in path is the same, and the command is
launchd's; `brew services` never runs under sudo
(`rules/os/macos.md` → Package Manager). The domain depends on
who started the job: a LaunchDaemon in `/Library/LaunchDaemons`
is `system/<label>` (`sudo launchctl list`), a service started
with `brew services` belongs to the admin who started it,
`gui/<uid>/<label>` with that admin's numeric UID:

```
deploy ALL=(root) NOPASSWD: /bin/launchctl kickstart -k system/<label>
deploy ALL=(root) NOPASSWD: /bin/launchctl kickstart -k gui/<uid>/<label>
```

Keep only the line that fits.

## Login Shell Override for Deployment

The deploy user is created with
`/usr/sbin/nologin` for security, but SSH runs
every command — including `command=` forced
commands — through the user's login shell.
With `nologin` as the shell, every connection is
refused, so a `command=` restriction cannot make
a `nologin` user usable for deployment.

**Preferred:** give the deploy user a minimal
real shell and lock the key down with a forced
command plus restrictive key options:

```bash
usermod -s /bin/sh deploy
```

On FreeBSD: `pw usermod deploy -s /bin/sh`.

On macOS: `dscl . -create /Users/deploy UserShell /bin/sh`.

As the key line:

```
command="/home/deploy/deploy.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAA...
```

The forced command means the key can only ever
run `deploy.sh`, regardless of what the client
requests — the shell is just the interpreter
sshd uses to launch it.

**Alternative:** if the deployment process needs a
full shell (e.g. rsync, multiple commands):

```bash
usermod -s /bin/bash deploy
```

On FreeBSD, bash is a package: check `command -v bash` first,
and install it only if the user agrees (`rules/version-check.md`);
then `pw usermod deploy -s /usr/local/bin/bash`.

On macOS, prefer `/bin/zsh`, the default login shell, or
`/bin/sh`.

Discuss the trade-off with the user: a full shell
without a forced command is more flexible but
increases the attack surface if the key is
compromised.
