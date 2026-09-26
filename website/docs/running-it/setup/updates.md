---
sidebar_position: 3
description: Which updates a checkout takes, how it updates itself,
  and how to choose, follow or pin a release.
---

# Updates and versioning

Hostwarden uses [semantic versioning](https://semver.org). The
current version is in the `VERSION` file; released changes are
listed in `CHANGELOG.md`, changes not released yet in `changelog.d/`.

## Which updates a checkout takes

From the first release of 1.0.0 or later on, an operations checkout
follows the major line of the newest release: it checks out release
tags and moves to each new one on that line, never to `main` in
between. A checkout that was on `main` and never chose anything
settles on that line with its next update, and keeps it when the
next major is released. Before any such release exists, it follows
`main`. A development checkout never settles on a line by itself.

## Release signatures

Every release tag from v1.0.0 on is an annotated tag signed with
Hostwarden's release key, an SSH key used for nothing else:

```text
release@hostwarden namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0cMXwoEAtpFv+0ptBS/Za6djrMigZ6P6NIUZq8YHI7
```

Its fingerprint is
`SHA256:Ut0GmoL9jbqB/BRdlNZmyjdakDDLKsR1Y/OcU8l8nmk`. The same line
is in `.github/release-signers`, which the release workflow checks
each tag against before it pushes it. To check a tag yourself, save the
lines above to a file outside the checkout and run:

```bash
git -c gpg.ssh.allowedSignersFile=<that file> verify-tag vX.Y.Z
```

Take the lines from this page, not from the checkout: a file in the
checkout proves nothing about the tag that brought it. A key retired
in the normal course stays listed, bounded with `valid-before`, so
an older release still verifies; a key that leaked is removed.

An operations checkout does this itself before every checkout of a
release tag, with `--follow`, `--pin` and every update on a line.
The key it trusts is the `.github/release-signers` of the version it
is on, copied aside before anything is fetched, never the file of the
tag it checks; a checkout on `main` settling on its first release
line uses `main`'s. Each release in between that verifies hands its
own file on, so a new key listed by a release the old key signed is
trusted from there on, even where the update skips that release. A
tag that does not verify, or carries another release's name, is
refused: the update says so and stops, and the checkout stays where
it is, `main` included. `--check` names such a tag too. Verifying
needs git 2.34 and OpenSSH 8.7 or later, which
`bin/hostwarden-doctor` checks. After a refusal, compare the
checkout's `.github/release-signers` with the lines above. Where
they differ, as after a leaked key was replaced, check the tag by
hand with the lines from this page, as above, and only once it
verifies, `git checkout vX.Y.Z`; from there on the updater trusts
the new key. A development checkout verifies nothing.

## Automatic updates

On every session start in an operations checkout, a hook (Claude
Code) moves to the newest release on the line — or, on `main`, runs
`git pull` — and reports version changes. No action needed.
Auto-update is skipped in a development checkout, when pinned to a
tag (see [below](#pinning-a-version)), when on a non-`main` branch,
or when `HOSTWARDEN_NO_UPDATE=1` is set.

## Updating by hand

With OpenCode or any other tool:

```bash
bin/hostwarden-update           # update
bin/hostwarden-update --check   # check without updating
```

## Choosing a release line

```bash
bin/hostwarden-update --follow 1     # every 1.x.y release
bin/hostwarden-update --follow 1.2   # 1.2.x fixes only
```

The choice is kept in this checkout's own git config
(`hostwarden.follow`), so each machine chooses its own. An update
writes it only once, when a checkout that never chose settles on its
line. The auto-update checks out the highest `vX.Y.Z` tag on the
line; pre-releases do not count. Only the newest release gets fixes
([SECURITY.md](https://github.com/hostwarden/hostwarden/blob/main/SECURITY.md)):
once a release outside the line is out, every update and `--check`
say so, and name the line to follow next and where to read what it
changes, or, where that release does not verify, that an update
refuses it.

## Following main

To test what is not released yet:

```bash
bin/hostwarden-update --unpin        # follow main
```

The checkout then pulls `main` on every update, and stays there.
After each pull, `bin/hostwarden-update` says how the changes no
release has yet moved, under "On main, not released yet": the lead
clause of each entry that is new or changed in `changelog.d/` or
under `## Unreleased` in `CHANGELOG.md`, and each one no longer
listed: withdrawn, reworded under another lead clause, or only on
the branch it left.

## Pinning a version

To skip auto-updates for a stable version:

```bash
bin/hostwarden-update --pin vX.Y.Z   # pin
```

A pin replaces a release line or `main`; `--follow` or `--unpin`
leaves it again.

## Turning auto-update off

Without pinning:

```bash
export HOSTWARDEN_NO_UPDATE=1
```

In the desktop app, set it in the `env` of
`.claude/settings.local.json` instead — see
[Claude Code Desktop](../../getting-started/ai-tools.md#claude-code-desktop).
