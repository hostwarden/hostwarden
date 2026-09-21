# Updates and versioning

Hostwarden uses [semantic versioning](https://semver.org).
The current version is in the `VERSION` file; changes
are listed in `CHANGELOG.md`.

**Auto-update (Claude Code):** On every session start
in an operations checkout, a hook runs `git pull` —
or, on a release line, moves to its newest release —
and reports version changes. No action needed.
Auto-update is skipped in a development checkout,
when pinned to a tag (see below), when on a
non-`main` branch, or when `HOSTWARDEN_NO_UPDATE=1`
is set.

**Manual update (OpenCode / any tool):**

```bash
bin/hostwarden-update           # pull latest
bin/hostwarden-update --check   # check without pulling
```

**Follow a release line** instead of `main`:

```bash
bin/hostwarden-update --follow 1     # every 1.x.y release
bin/hostwarden-update --follow 1.2   # 1.2.x fixes only
```

The line is kept in this checkout's own git config
(`hostwarden.follow`), so each machine chooses its own
and an update never changes it. The auto-update checks
out the highest `vX.Y.Z` tag on the line;
pre-releases do not count.

**Pin to a stable version** (skip auto-updates):

```bash
bin/hostwarden-update --pin vX.Y.Z   # pin
bin/hostwarden-update --unpin        # back to main
```

A pin replaces a release line, and `--unpin` clears
both.

**Opt out of auto-update** without pinning:

```bash
export HOSTWARDEN_NO_UPDATE=1
```

In the desktop app, set it in the `env` of
`.claude/settings.local.json` instead — see
[Claude Code Desktop](ai-tools.md#claude-code-desktop).
