---
id: 20260924-guard-hook-over-permissions-deny
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guard, taboos]
---

# PreToolUse hook enforces taboos, not permissions.deny

## Context

Decided in Heinzel commit 6c7fd31b on 2026-06-10, before this
repository's own records existed. Heinzel's absolute taboos —
halting a server, writing a partition table, deleting SSH keys,
editing sshd_config — were prose-only in CLAUDE.md. A
hallucination, a prompt injection from something a server
returned, or an overeager `--dangerously-skip-permissions` session
could still run one; nothing below the model layer stopped it.
Claude Code's own permission system offered `permissions.deny`,
but nearly every command Heinzel runs on a managed host is
wrapped, `ssh user@host "cmd"`, and a deny pattern cannot match
inside that wrapper.

## Decision drivers

- A taboo must hold even when the model is wrong, injected, or
  told to skip permissions.
- Most remote commands are `ssh`-wrapped, which `permissions.deny`
  cannot see inside.
- The check has to work below the model layer, not only in prose.

## Considered options

### PreToolUse hook that regex-scans the whole command — chosen

A hook runs on every Bash and Monitor call, scanning the full
command string so quoting or a wrapper cannot hide a taboo, and
denies in every permission mode. It also covers the edit tools by
the file they write. Against it: every taboo pattern now lives in
a script that has to stay in sync, and a wrong regex either blocks
something innocent or lets something taboo through.

### `permissions.deny` patterns alone

Deny patterns in Claude Code's own settings, unchanged. Simpler,
no script to maintain. Lost: a pattern matches the start of the
command line, so `ssh root@host "poweroff"` slips past a
`Bash(poweroff*)` deny, and a bypass session ignores
`permissions.deny` entirely.

## Decision

`guard-taboos.sh` runs as a PreToolUse hook on Bash, Monitor and
every edit tool, denies unconditionally in every permission mode,
and is the primary layer. A minimal `permissions.deny` —
`halt`, `poweroff`, `mkfs*`, plus `PowerShell` outright — stays
as a second, cheaper layer for a top-level invocation the hook
would catch anyway.

## Consequences

AGENTS.md → Critical Safety Rules names the taboos;
`.claude/settings.json`'s `PreToolUse` matcher and
`.claude/hooks/guard-taboos.sh` carry the mechanism and every
pattern, `guard-taboos-test.sh` the fixture matrix a new taboo has
to extend. `.claude/hooks/instructions-test.sh` checks that Bash
and Monitor stay in that matcher and that `PowerShell` stays
covered too, matcher or `permissions.deny` either one — today the
deny list, not the matcher. A proposal to drop the hook for
`permissions.deny` alone, or to trust prose rules for a tool that
runs shell commands, is answered with this record.

## Confirmation

`instructions-test.sh` would fail if Bash or Monitor dropped out
of the matcher, or if `PowerShell` were covered by neither the
matcher nor `permissions.deny`; `guard-taboos-test.sh` would fail
if a pattern stopped scanning an `ssh`-wrapped command. A taboo
named in AGENTS.md with no matching pattern in the hook is caught
by neither, and is the moment to reread this record.
