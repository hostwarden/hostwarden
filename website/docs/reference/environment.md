---
sidebar_position: 5
description: The environment variables an admin sets, what each does
  and where to set it.
---

# Environment variables

Hostwarden needs no environment variable to run. These are the ones you
may set. In a terminal, export them before you start the session; in
the Claude desktop app, put them into the `env` key of
`.claude/settings.local.json` and start a new session
([Claude Code Desktop](../getting-started/ai-tools.md#claude-code-desktop)).

## Sessions

- **`HOSTWARDEN_NO_UPDATE=1`** — the session start skips the automatic
  update of an operations checkout
  ([Updates and versioning](../running-it/setup/updates.md)).
  `HEINZEL_NO_UPDATE=1` is honoured as well.
- **`HOSTWARDEN_GUARD_DISABLE=<host>`** — switches the taboo guard off
  toward one host, for the disk steps of an OS install on it and
  nothing else: the name Hostwarden reaches the host the disk writes
  run on by (the hypervisor, for a guest's disk), or `localhost` for
  this machine. The guard stays on for every other
  host; `1` or a list is refused. It counts only for a session that
  started with it, and Hostwarden cannot set it for you: you add it
  yourself, and remove it after the install
  ([Hard guardrails](../safety/guardrails.md)).

## Scripts

- **`HOSTWARDEN_MIRROR_TOKEN`** — the token `bin/hostwarden-mirror`
  pushes to your mirror with, read from the environment so it never
  lands on a command line
  ([Your own mirror](../running-it/setup/mirror.md)).
- **`HOSTWARDEN_FLEET_MODEL`** — the model the nightly run of an
  operations host asks for a verdict on each server's output; the
  default is `sonnet`
  ([An operations host](../running-it/team/operations-host.md)).

Variables for working on Hostwarden itself, such as the lab's, are in
[Testing a change](../development/testing.md). Any other `HOSTWARDEN_*`
name in the scripts is set by Hostwarden for its own use.
