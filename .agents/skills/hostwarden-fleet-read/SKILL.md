---
name: hostwarden-fleet-read
argument-hint: "[hostname | bundle]"
description: Set up an operations host that runs the fleet's
  housekeeping unattended, and fleet read — the least-privilege way
  it reads each host. Each host gets a forced-command wrapper that
  runs only a bundle of read-only checks the operator signed, and
  writes one read-only journal line; the bundle is built from the
  housekeeping references and signed by the operator, never by
  Hostwarden. Use when the user asks to "set up an operations host",
  "run the nightly housekeeping from <machine>", "set up fleet read
  on <host>", "let the operations host read <host>", "build the
  fleet-read bundle", "rebuild the bundle", "the bundle expires",
  "remove fleet read from <host>", "richte einen Ops-Host ein",
  "Fleet-Read auf <host> einrichten", "bau das Bündel neu", "das
  Bündel läuft ab", or "nimm <host> aus dem Fleet-Read".
---

# hostwarden-fleet-read

**Overrides.** Load them before anything else, key
`hostwarden-fleet-read`, per `rules/overrides.md`.

An operations host (`references/operations-host.md`) — an always-on
machine that runs Hostwarden without anyone at the keyboard —
reaches each host with one key of its own, and its fleet run
(`bin/hostwarden-fleet-run`) uses nothing else. On the host, that
key is forced to `fleet-read`, a wrapper that accepts exactly two
requests:

- **collect** — run a bundle of read-only checks, but only one the
  operator signed for the namespace `fleet-read` and whose
  `# valid-until:` date has not passed;
- **log** — write one line to the journal, under the tag
  `hostwarden` and a prefix the wrapper sets:
  `[<name> as root] read-only: <line>`.

Nothing else runs: no shell, no other command. Whoever takes the
operations host over can replay a signed bundle until its date and
write read-only journal lines, and that is all. The signature is
the operator's approval of every command in the bundle, and the
signing key never lies on the operations host.

## What stays with the operator

Hostwarden never does these, whatever mode the session runs in:

- **Making the operations host's key** and adding its line to
  root's `authorized_keys` on each host. The taboo guard blocks
  both, and `AGENTS.md` → Critical Safety Rules forbids them
  anyway; the session writes out the line for the operator.
- **The signing key.** It is the operator's, kept where they keep
  keys that sign — a password manager's SSH agent, a hardware key —
  and never on the operations host or in the workspace. Only its
  public half enters the workspace.
- **Signing a bundle.** The session builds it, shows it, and hands
  over the command. A session that could sign would make the
  signature worthless.

## The workspace

Everything lives in `memory/fleet/fleet-read/`, a fleet master as
`rules/deployed-files.md` → Where the master lives describes:

- `files/usr/local/sbin/fleet-read` — the wrapper, copied from
  `templates/fleet-read/fleet-read` in this checkout.
- `files/etc/fleet-read/allowed_signers` — one line per signing
  key, public halves only.
- `src/<bundle>.sh` and `src/<bundle>.sh.sig` — each bundle and the
  operator's signature of it (`references/bundle.md`).
- `README.md` — what fleet read is here: the operations hosts that
  use it and their names, where the signing key lives (the kind of
  place, never a path to a private key), and the bundles.

**First use.** When the directory is missing, create it: copy the
template into `files/`, and ask the operator for the public half of
their signing key — its `.pub` line, pasted or as a path to read.
Write it as one line, the principal and the namespace fixed:

```
fleet-read namespaces="fleet-read" ssh-ed25519 AAAA… alice@example.com
```

A second signing key — a teammate's, a replacement — is a second
line. Commit the directory (`rules/changelog.md` → The Workspace).

**A newer wrapper.** When `templates/fleet-read/fleet-read` differs
from the master, a Hostwarden update changed it. Say so with the
diff whenever this skill runs, and offer to take it into the
master; the hosts then show "master changed, not deployed"
(`rules/deployed-files.md` → Drift) and each is updated when the
user agrees.

## The operations host

`references/operations-host.md`: what it holds, what it runs, the
workspace, and setting one up.

## Setting up a host

`references/install.md`. The host needs OpenSSH 8.1 or later.

## Building and signing a bundle

`references/bundle.md`.

## Changing the signing key

A signing key that is replaced, or may have leaked:

1. The operator makes the new key and gives its public half; add
   it as a line to the master's `allowed_signers`.
2. Deploy the signers file to every host that carries it
   (`grep -l fleet/fleet-read memory/servers/*/deployed.md`).
3. The operator signs every bundle again with the new key.
4. Remove the old line from the master and deploy once more.

A leaked key goes first, before steps 1 to 3: remove its line and
deploy, and let the nightly run fail until new signatures exist.
A bundle it signed runs anywhere the line is still present.

## Removing fleet read from a host

The key line goes first, and it is the operator's step. Once
`grep -c 'command="/usr/local/sbin/fleet-read ' /root/.ssh/authorized_keys`
on the host prints `0`, remove the wrapper and `/etc/fleet-read/`
(`rules/deployed-files.md` → Removing), and the `Fleet read:` line.
A wrapper removed first leaves a key line that still logs in and
fails; harmless, but it is the operator's to clean up.

## Server memory

One line in the host's `memory.md`, owned by this skill:

```markdown
- Fleet read: ops1 (bundle linux, key line present, 2026-09-23)
- Fleet read: ops1 (bundle linux, waiting for the key line, 2026-09-23)
```

The name is the one in the key line's command, the bundle is the
one the operations host sends this host, and the date is the last
check run that passed. The wrapper and the signers file are in
`deployed.md` like every deployed file.

## Changelog

Log each installation per `rules/changelog.md`:

```bash
logger -t hostwarden "[alice as root] ops1 can now run \
operator-signed read-only checks here through fleet-read, and \
nothing else — because the nightly housekeeping runs from ops1"
```
