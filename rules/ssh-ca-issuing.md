# SSH CA Issuing Rules

What a CA that signs user certificates lets people get, whatever
the software: who receives a certificate, for which principals,
and for how long. Hostwarden does not run the CA
(`rules/ssh-ca.md`). It reads these rules read-only where the CA
runs on a managed host, asks the user for them where it does not,
and reports.

Read it in the security audit of a host that trusts a user CA,
when the CA runs on the host or the user hands its rules over, and
when a login fails on the principal. Products and field names
change between releases: check the upstream documentation for the
version in use before relying on a name here (`AGENTS.md` → Verify
Before Running).

## Findings

- Anyone who can reach the CA gets a certificate, with no group
  or directory restriction → **WARN**.
- The requester chooses the principals, so anyone can ask for
  root or a role account → **CRITICAL**.
- Principals come from identity claims, but nothing keeps root
  and the role accounts out → **WARN**: an identity whose name or
  address starts with `root` gets root.
- The rule that signs user certificates also signs host
  certificates → **WARN**.
- A maximum lifetime above 24 hours → **INFO**: a leaked
  certificate stays valid that long unless it is revoked.

Record the result on the CA's line in `memory/network.md`
(`rules/ssh-ca.md` → Memory), as
`issuing: groups server-admins, root denied, 16h`.

## Where to Read Them

Read-only, and never a whole configuration file, a secret or a
token (`rules/secrets.md`). For each product, the four places
below answer, in order: who may get one; whether the requester
picks the principals, and whether host certificates come from the
same rule; what keeps root out; the lifetime.

- **Plain OpenSSH** (`ssh-keygen -s`): whoever holds the CA
  signing key signs any principal (`-n`) for any time (`-V`). The
  signing process is the rule set: ask the user who runs it and
  how, and where the key lives (`rules/ssh-ca.md` → User CA
  Trust).
- **step-ca**, on a managed host, as root. `ca.json` holds
  secrets, so only these fields:

  ```bash
  S=$(systemctl show -p Environment step-ca 2>/dev/null \
    | sed -n 's/.*STEPPATH=\([^ ]*\).*/\1/p')
  $SUDO jq '{admin: .authority.enableAdmin,
    policy: .authority.policy, claims: .authority.claims,
    provisioners: [.authority.provisioners[]?
      | {type, name, admins, groups, domains, claims,
         template: .options.ssh.templateFile}]}' \
    "${S:-/etc/step-ca}/config/ca.json"
  ```

  Every provisioner that signs user certificates is a way to
  one. OIDC: its `groups` and `domains`, and `admins`, who may
  request any principal. JWK (what `step ca init --ssh` creates),
  X5C, K8sSA and Nebula: the requester names the principals, so
  whoever holds the JWK password or the accepted credential gets
  root unless a template or a policy says otherwise. JWK signs
  host certificates as well: the finding on one rule signing both.
  SSHPOP only renews and rekeys certificates that exist, and the
  AWS, GCP and Azure identity provisioners sign host certificates
  only (<https://smallstep.com/docs/step-ca/provisioners/>).
  `policy.ssh.user` with a `deny` for root, or an `allow` list
  without it, keeps root out for all of them;
  `claims.maxUserSSHCertDuration` is the lifetime. With
  `enableAdmin: true` the provisioners live in the CA's database:
  ask the user for the same fields.
- **HashiCorp Vault, OpenBao** (a fork, CLI `bao`), the SSH
  secrets engine: the user runs `vault read <mount>/roles/<role>`
  (`bao read …`) and hands over the output. The policy on
  `<mount>/sign/<role>` and the groups its auth method binds;
  `allowed_users` empty or `*`, and `allow_host_certificates`;
  `allowed_users_template` or `default_user_template` binding the
  principal to the identity; `max_ttl`.
- **Teleport** (its own CA and node service): the user runs
  `tctl get roles`. The roles and their `node_labels`;
  `allow.logins`, often from traits (`{{internal.logins}}`);
  `deny.logins`; `options.max_session_ttl`.
- **BLESS** (an AWS Lambda function): its
  `bless_deploy.cfg`. The function's IAM policy; the caller names
  `remote_usernames` itself; `remote_usernames_blacklist`, and with
  kmsauth `kmsauth_remote_usernames_allowed` (`*` is anyone);
  `certificate_validity_after_seconds` and
  `certificate_validity_before_seconds`.
- **Anything else** — a cloud provider's CA, a script: its
  documentation or the script, with the same four questions.

A CA tool that offers to set up the host (`step ssh config
--host` and the like) writes sshd's configuration: never run it.

## When a Login Fails on the Principal

sshd logs `Certificate invalid: name is not a listed principal`
(`rules/ssh-ca.md` → Failures). The certificate's principals
(`ssh-keygen -L -f <certificate>`) do not contain the account
name, or no line of that account's principals file. The usual
cause is the claim the CA builds principals from. step-ca, for
one, turns the address `alice.smith@example.com` into
`alicesmith`, `alice.smith` and the address itself, while the
directory calls the account `asmith`. Group principals may carry
a path: Keycloak sends `/admins` unless "Full group path" is off.
The fix is the CA's mapping or the principals file, and both are
the user's to change.
