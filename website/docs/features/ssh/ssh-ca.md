---
sidebar_position: 2
description: Audits an existing SSH CA and uses it wherever it
  sets up SSH trust.
---

# SSH certificates and your CA

If you already run an SSH CA — `ssh-keygen` with a script, step-ca,
Vault or OpenBao, Teleport — Hostwarden audits it and uses it
wherever it sets up SSH trust. It does not build a CA for you,
never signs a certificate, and never touches a CA signing key or
the configuration of an sshd that runs. A CA it finds on a server
is only a finding until you confirm it as yours; only then is it
carried anywhere.

## Audit

Each host certificate's expiry, names and renewal job, and whether
sshd presents the certificate on disk; which user CA each server
trusts, its principals and its revocation list, and whether that
list exists, since a missing one locks out every key login. Where
it can read them, the CA's issuing rules: who gets a certificate,
for which accounts, for how long. A signing key found on a server
is a finding.

## Fleet audit

Which CA and which revocation list every server trusts, so a
revocation that missed a server stands out.

## Your workstation

Every host with a host certificate from your CA is covered by its
line in `memory/known_hosts`. A missing line is offered; another
CA for the same name stops the connection.

## Servers that connect to others

Get the host CA's line in their global known-hosts file when you
say yes.

## New guests

Trust your user CA from their first boot; a container from the
Proxmox VE baseline template, which shares the template's setup,
gets the lines to add instead. Their host keys are handed to you
to sign; installing the certificate is yours.

## Baseline

Once you confirm a CA as yours and say which servers it covers, a
server there that does not trust it, has another principals setup
than the rest, presents no valid host certificate, or has no
revocation list where the others have one, is a finding, and you
get the lines to add.
