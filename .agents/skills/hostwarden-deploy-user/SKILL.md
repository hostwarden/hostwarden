---
name: hostwarden-deploy-user
argument-hint: "[hostname] [app-name]"
description: Set up, audit or remove a dedicated account for
  automated deployments — a CI/CD deploy user with a restricted
  shell, its own SSH key, a deployment directory it owns, and
  narrowly scoped sudo if it needs any at all. Use when the user
  asks to "set up deployment for <app>", "add a deploy user",
  "connect GitHub Actions to this server", "GitLab CI should
  deploy here", "give the pipeline SSH access", "einen Deploy-User
  anlegen", or asks how a build server should reach a host. Also
  use when removing such an account. Never hand a pipeline root or
  a person's own account.
---

# hostwarden-deploy-user

**Overrides.** Load them before anything else, key
`hostwarden-deploy-user`, per `rules/overrides.md`.

## Never root, never a person's account

An automated pipeline — GitHub Actions, GitLab CI,
anything else — gets a dedicated deploy user with
minimal privileges. If the user asks to deploy as
root, explain the risk and create one instead:

- A compromised CI secret grants full server access.
- No audit trail separating human from automated
  actions.
- Accidental destructive commands run unchecked.

## Create the Deploy User

Create a system user with no password and no login
shell. Adapt the username to the project if the
user prefers (e.g. `deploy-myapp`), default to
`deploy`.

### Linux

```bash
useradd --system --shell /usr/sbin/nologin \
  --create-home --home-dir /home/deploy deploy
```

### FreeBSD

```bash
pw useradd deploy -d /home/deploy \
  -s /usr/sbin/nologin -m \
  -c "CI/CD deploy user"
```

### Verify

One call, and it has to fail when the account does not
exist. `id` succeeding is already proof of that, so there
is nothing for a `/etc/passwd` grep to add, and the
password state belongs in the same trip — but chained with
`&&`, not `;`. A `;` throws away the `id` status, and an
unanchored `grep deploy /etc/shadow` then matches
`deploy-old` and reports success for an account that was
never created:

```bash
id deploy && { passwd -S deploy 2>/dev/null \
  || grep '^deploy:' /etc/shadow; }
```

The account should have no password set — `!` or `*` in
`/etc/shadow`, or `L`/`NP` from `passwd -S`.

## Auditing one that already exists

When the request is to check an existing deploy user rather
than create one, change nothing. Read the four things this
skill sets up and report each as it is:

```bash
id deploy && getent passwd deploy
ls -ld /srv/deploy 2>/dev/null
sudo -n cat /etc/sudoers.d/deploy 2>/dev/null
```

Then the account's authorized keys, with
`ssh-keygen -lf` rather than by printing the file: it gives
the fingerprint, the type and the comment, which is what
identifies a key, and no key material reaches the report
(`rules/secrets.md`).

What each of these *should* look like is
`references/harden.md` — restricted shell, a directory the
account owns, sudo scoped to named commands or absent, and
a key with the options that pin it to one command. Report
the difference and let the user decide. Fixing it is a
separate request, and it goes through the sections above.

## The key, the directory, the privileges

- `references/ssh-key.md` — generating the deploy key, placing
  it, and what goes into the CI secret.
- `references/harden.md` — the deployment directory, sudo scoped
  to one command when it is needed at all, and the login shell
  override.

## Firewall

No special firewall changes needed. Deployment
uses the existing SSH port (22). Do not open
additional ports for the deploy user.

## Server Memory

After creating the deploy user, update the
server's `memory.md` with:

```markdown
- Deploy user: deploy (CI/CD, SSH key auth)
- Deploy target: /var/www/myapp
- Deploy sudo: systemctl restart myapp.service
```

Omit the sudo line if no sudo was configured.

## Changelog

Log the deployment user setup per
`rules/changelog.md`:

```bash
logger -t hostwarden "Created deploy user 'deploy' \
for CI/CD, key auth, target /var/www/myapp"
```

## Removing one

`references/removal.md`.
