---
id: 20260924-guests-get-keys-never-passwords
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guests, security]
---

# Guests get keys at first boot, never passwords

## Context

Decided 2026-09-22 while reviewing PR #130
(`hostwarden-new-guest`). A cloud image or installer defaults to a
password, or to no login at all until one is set by hand — either
way, someone has to touch the console before Hostwarden can reach
what it just created. The sshd taboo already forbids writing
login options into a server that has run; the guest's first boot
was widened to be the one exception, for exactly this.

## Decision drivers

- A guest Hostwarden creates should be reachable by the time
  creation finishes, with nobody handling a secret by hand.
- Hostwarden must never see, type or store a password itself.
- The exception to the sshd taboo has to stay narrow: first boot of
  a guest that has never run, nothing after.

## Considered options

### Keys into first-boot config, password only on request — chosen

Every guest type (cloud-init, Ignition, kickstart, preseed,
autoinstall, AutoYaST, LXC, a pre-boot image) gets the SSH public
key, and later CA trust, written into its first-boot configuration.
A user without a key who asks for a password gets one where the
platform allows it, generated and shown by the guest itself — for
example cloud-init's `chpasswd` with `type: RANDOM`, shown only on
the console. Against it: every guest-creation path has to carry its
own answer to "how does the key get in before boot", instead of one
shared step.

### Default to whatever the image ships, fix it after boot

Accept the image's own password default and change it once
Hostwarden can log in. Lost: it needs a first login Hostwarden
cannot make yet, and a password would pass through Hostwarden's own
hands to get there — the thing the sshd taboo exists to prevent.

## Decision

Every guest but one case is reachable by key from first boot, key
(and later CA trust) placed by its first-boot configuration; a
requested password, where the platform allows it, is generated and
shown by the guest. The exception: a UI with no second ISO falls
back to the installer's own questions, a password the user types,
with their consent.

## Consequences

`AGENTS.md` → Critical Safety Rules carries the widened taboo
exception; `.agents/skills/hostwarden-new-guest/SKILL.md` carries
the per-platform key and password mechanics, and what a guest's
first boot receives when a CA covers it is governed separately
([20260924-ssh-ca-audit-and-consistent-use](20260924-ssh-ca-audit-and-consistent-use.md)).
Designing a new creation or install path starts from how the key
gets in before first boot, never from a password fallback.

## Confirmation

A guest that comes up needing a console login, or a proposal to
have Hostwarden set or relay a password, is the moment to reread
this record.
