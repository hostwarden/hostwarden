---
sidebar_position: 2
description: Checks SSH hardening, firewall posture, accounts, and
  other security settings.
---

# Security audit

Check security configuration on any server.

```
 ❯ Run a security audit on app.example.com
```

Findings are reported by severity.

## What it checks

### SSH

What sshd really uses (`sshd -G`, a daemon's own config file,
`Match` blocks), password and root login, weak algorithms, host
certificates and user CA trust; the SSH servers built into VPN
agents and who they admit; the SSH client on the server.

### Firewall

Posture and IPv6 coverage of every firewall, legacy iptables rules
counted as one, Docker ports published past it, and a firewall in
front of the host.

### Accounts

Where accounts and sudo rules come from — a role account, a
directory such as AD or FreeIPA, local files, or an agent — who
can become root without a password, empty passwords and extra
UID 0 accounts.

### Containers

Privileged containers, mounted engine sockets and an engine API on
TCP.

### Services

Databases listening on every address, open DNS resolvers, exposed
admin interfaces.

### The system

Kernel hardening, file permissions, SUID and SGID files, fail2ban,
blocklistd or sshguard.

### Management controllers

IPMI over the network, cipher suite 0, factory accounts, Intel
AMT.

### macOS

SIP, FileVault, Gatekeeper, sharing and launchd permissions.

### Windows Server

SSH, firewall, accounts, SMBv1, Remote Desktop, Defender and
BitLocker.

## What gets recorded

Where accounts come from is recorded in the host's memory as one
`Accounts:` line, next to the `Management:` line and the SSH CA
the audit found.
