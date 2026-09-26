---
sidebar_position: 2
description: Example prompts for common Hostwarden tasks
---

# Example prompts

Starting points for asking Hostwarden to do something. Every prompt
works in Claude Code and in other tools (in tools without a command
palette, ask for the workflow by name or by pointing at the skill).

## Onboarding and questions

```
 ❯ Check on web1.example.com.
```

```
 ❯ Update all Homebrew packages on this Mac
```

```
 ❯ Check if the firewall is configured on this machine
```

More: [Your first session](../getting-started/first-session.md)

## Checks and audits

```
 ❯ Run housekeeping on app.example.com
```

```
 ❯ Run a security audit on app.example.com
```

More: [Housekeeping checks](../features/checks/housekeeping.md),
[Security audit](../features/checks/security-audit.md)

## Many servers

```
 ❯ Which kernel runs on web1, web2 and web3?
 ❯ Run housekeeping on web1 and db1
 ❯ Prüf auf allen Servern, ob nginx läuft
```

```
 ❯ Run a fleet audit
 ❯ Vergleiche die Policies auf allen Servern
```

More: [One task on many hosts](../features/fleet/multi-host.md),
[Fleet audit](../features/checks/fleet-audit.md)

## Fleet administration

```
 ❯ Build the fleet-read bundle
 ❯ Set up fleet read on web1.example.com for ops1
 ❯ Fleet-Read auf web1.example.com einrichten
```

```
 ❯ What goes down if pve1 reboots?
 ❯ Wen trifft ein Neustart von unbound auf dns1?
```

More: [Fleet read](../features/fleet/fleet-read.md),
[What a reboot would hit](../features/fleet/impact.md)

## Changes and planning

```
 ❯ Plan pve1's kernel update for next week
 ❯ When should pve1's update happen?
```

```
 ❯ /plan Migrate the database from MySQL to PostgreSQL
   on db.example.com
```

More: [Planning a maintenance window](../features/fleet/maintenance-windows.md),
[Plan mode](../features/changes/plan-mode.md)

## Guests and hypervisors

```
 ❯ Create a Debian VM on pve1.example.com
 ❯ Leg einen neuen LXC auf pve1 an
```

```
 ❯ Replace the OS on web1.example.com with Debian
 ❯ Set up dual-boot with FreeBSD on this machine
```

```
 ❯ Rename web1.example.com to web2.example.com
```

More: [New guests](../features/guests/new-guests.md),
[Installing an operating system](../features/guests/os-install.md),
[Renaming a host](../features/changes/rename.md)

## Runtimes and deployment

```
 ❯ Install the latest stable Node.js on web1
 ❯ Set up deployment for the shop on web1
```

More: [Language runtimes and deploy users](../features/changes/runtimes.md)

## Email

```
 ❯ Email me the output of "df -h" from app.example.com
 ❯ Mail /var/log/auth.log to ops@example.com
```

More: [Email reports](../features/changes/email.md)

## Migration

```
 ❯ Take my Heinzel in ~/heinzel over
```

More: [Moving over from Heinzel](../running-it/heinzel.md)
