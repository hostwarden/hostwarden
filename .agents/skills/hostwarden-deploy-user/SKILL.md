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

# CI/CD Deployment Users

When setting up automated deployments (GitHub
Actions, GitLab CI, etc.), **never use the root
account or a personal user account**. Always create
a dedicated deploy user with minimal privileges.

## Never Root for CI/CD

Automated pipelines must not SSH as root. If the
user asks to set up deployment with root, explain
the risk and create a dedicated user instead.

**Risks of root deployments:**

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

```bash
id deploy
grep deploy /etc/passwd
```

The user should have no password set (`!` or `*`
in `/etc/shadow`). Confirm:

```bash
passwd -S deploy 2>/dev/null \
  || grep deploy /etc/shadow
```

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
