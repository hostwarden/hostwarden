---
sidebar_position: 1
description: Checks every server's SSH host key against the
  workspace's known_hosts file.
---

# Host keys

Hostwarden checks every server's SSH host key against one file in
the workspace, `memory/known_hosts`, and never asks you to log in
by hand first.

## Getting a new host's key

A host that is not in it gets its key in this order:

1. **Through a host that is already verified.** A container or VM
   reached through its hypervisor (`pct exec`, `qm guest exec`,
   `incus exec`, …) has its key read inside. Registering a
   hypervisor's guests records their keys this way, and so does
   creating a new guest where the hypervisor can enter it.
2. **From the known_hosts files your own ssh reads**
   (`~/.ssh/known_hosts`, the system-wide `/etc/ssh/ssh_known_hosts`
   and any others your ssh configuration names), imported with a
   note saying so. An `@cert-authority` line found there is shown
   to you first.
3. **Otherwise it asks:** accept the key on first use, compare it
   with the fingerprint you read at the console, or stop. An
   override can take the first option away.

## What gets recorded

Every entry starts with a comment line saying when and how the key
was obtained. In a team the file is shared, so each host's key is
accepted once for everyone, and the workspace's history shows who
added it. A host whose key changed stops every call to it; nothing
is replaced until you say so, and never from your own known_hosts.

`@cert-authority` lines work in the same file, so SSH host
certificates from your own CA need no per-host lines.
