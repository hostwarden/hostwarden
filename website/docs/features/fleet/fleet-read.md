---
sidebar_position: 4
description: Gives an operations host a key limited to read-only
  checks.
---

# Fleet read

An operations host — an always-on machine that runs Hostwarden
unattended, such as a nightly housekeeping run — should not hold a
key that is root on every server. Fleet read gives its key exactly
two things on each host: running a bundle of read-only checks that
you signed, and writing one read-only line to the journal.

```
 ❯ Build the fleet-read bundle
 ❯ Set up fleet read on web1.example.com for ops1
 ❯ Fleet-Read auf web1.example.com einrichten
```

Hostwarden builds the bundle from its housekeeping checks, shows
it to you, and deploys the wrapper (`/usr/local/sbin/fleet-read`)
and your public signing key to each host, which needs OpenSSH 8.1
or later.

## Four steps that stay yours

They decide what the key can do:

1. Making the operations host's key.
2. Adding its line to root's authorized keys on each host, which
   Hostwarden writes out for you.
3. Keeping the signing key, somewhere other than the operations
   host.
4. Signing each bundle, with the command Hostwarden gives you.

## Running the bundle

On the operations host, `bin/hostwarden-fleet-run` uses it every
night and has Claude judge each result
([An operations host](../../running-it/team/operations-host.md)).
A signed bundle stops running on its `valid-until` date, at most a
year ahead, with a warning 30 days before; Hostwarden tells you
when its checks have changed since it was built. Whoever takes
over the operations host can replay what you signed and write
read-only journal lines, nothing more. Everything lives in
`memory/fleet/fleet-read/`. Windows hosts get no fleet read.
