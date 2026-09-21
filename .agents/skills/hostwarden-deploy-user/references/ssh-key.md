# The deploy user's SSH key

Step 3 of the `hostwarden-deploy-user` skill. The key is the
pipeline's whole credential, so it is generated for this one
purpose and never shared with a person's key.

## SSH Key for the Deploy User

Generate a dedicated keypair for the CI pipeline.
Do not reuse personal keys or the server's host
key.

### Generate the keypair

Run locally (not on the server):

```bash
ssh-keygen -t ed25519 -C "deploy@hostname" \
  -f deploy_ed25519 -N ""
```

This produces `deploy_ed25519` (private) and
`deploy_ed25519.pub` (public).

### Install the public key on the server

The taboo guard denies Hostwarden any write to
`authorized_keys` and any `chmod` or `chown` on
`.ssh`, appends included. Hand this block to the
user with the real key path; without a root login,
it takes `sudo sh -c` and passwordless sudo:

```bash operator
ssh root@hostname 'sh -c "
  mkdir -p /home/deploy/.ssh
  cat >> /home/deploy/.ssh/authorized_keys
  chmod 700 /home/deploy/.ssh
  chmod 600 /home/deploy/.ssh/authorized_keys
  chown -R deploy:deploy /home/deploy/.ssh
"' < /path/to/deploy_ed25519.pub
```

Then verify: both paths belong to `deploy`, with
modes `drwx------` and `-rw-------`, and the last
line matches the public key.

```bash
ls -ld /home/deploy/.ssh \
  /home/deploy/.ssh/authorized_keys
tail -n 1 /home/deploy/.ssh/authorized_keys
```

### Store the private key as a CI secret

Tell the user to add the private key as a secret
in their CI system (e.g. GitHub Actions secret
named `DEPLOY_SSH_KEY`). **Never commit the
private key to a repository.**

### Restrict the authorized key (optional)

For maximum lockdown, prepend restrictions to the
key line in `deploy_ed25519.pub` before the
handoff above:

```
no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...
```

Discuss with the user whether these restrictions
fit their workflow.
