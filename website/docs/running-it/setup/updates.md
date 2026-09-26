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
changes.

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
