---
sidebar_position: 4
description: Read-only housekeeping and security reporting for
  Windows Server over OpenSSH.
---

# Windows Server

Hostwarden reports on Windows Server over OpenSSH.

Every Windows host is read-only: housekeeping and the security
audit run in PowerShell and cover updates, services, the event
log, disks, Defender, BitLocker, backup, sshd, the firewall
profiles, accounts, SMBv1 and Remote Desktop. Updates are
reported, never installed. The two things it changes, each after
its own yes: it installs PowerShell 7 from Microsoft's package
with its checksum checked, and makes it OpenSSH's default shell
under the SSH safety net. A Windows client is refused and pointed
to WSL 2. Windows hosts get no fleet audit and no fleet read.
