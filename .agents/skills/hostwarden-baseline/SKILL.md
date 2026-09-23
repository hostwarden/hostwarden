---
name: hostwarden-baseline
argument-hint: "[hostname]"
description: Bring an existing server up to the Hostwarden server
  baseline — firewall with default deny, automatic security
  updates, time sync, key-only SSH, persistent journal, storage
  maintenance (TRIM, RAID checks, scrubs, smartd), guest agent,
  backup, and the user's own additions such as admin keys,
  timezone, mail relay and monitoring agent. Lists what is missing,
  then applies it one asked step at a time. Use when the user asks
  to "bring web1 up to the baseline", "apply the baseline to
  <host>", "harden this server to our standard", "what is <host>
  missing from the baseline", "zieh web1 auf die Baseline", "bring
  den Server auf unseren Standard", "was fehlt <host> zur
  Baseline". Not for a new guest, which gets the baseline at
  creation (hostwarden-new-guest).
---

# hostwarden-baseline

Measures a running server against `rules/baseline.md` and closes
the gaps the user picks. The pipeline in
`rules/first-connection.md` runs first, as everywhere.

1. **Overrides:** keys `hostwarden-baseline` and `baseline`, per
   `rules/overrides.md`, the host's `# baseline` block included.
2. **Measure.** Take what a housekeeping or security run in this
   session already found. For the rest, run the check each section
   of `rules/baseline.md` names, reading only that section of its
   reference, in as few bundled calls as they allow, and list what
   is missing, one line per section. A section the host's
   appliance, platform or role file replaces is measured by that
   file, and a section one of the host's decisions settles is
   listed as decided, with the decision's heading. Record the
   result in the `Baseline check:` line (`rules/baseline.md` →
   Rendered Versions).
3. **Ask** which to apply, in one question. A section the user
   turns down with a reason is the moment to offer recording it as
   a decision (`rules/decisions.md` → Writing one).
4. **Apply** one section at a time, each under the rules
   `AGENTS.md` → Where the Rest Lives → Before you change something
   names for it.
5. **SSH Login and Admin Keys:** as `rules/baseline.md` → SSH
   Login says.
6. **Record** `- Baseline: retrofitted <date>` in the host's
   memory once every section the user picked is in place and none
   is missing any more, and rewrite the `Baseline check:` line with
   what still is. Log each change (`rules/changelog.md`).
