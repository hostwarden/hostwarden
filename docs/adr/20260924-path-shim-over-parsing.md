---
id: 20260924-path-shim-over-parsing
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guard, development]
---

# Development mode refuses server tools with a PATH shim

## Context

Decided in #41, built in #42. In a development checkout no server is
reached. The mode guard enforced that by reading the shell text of
each command for `ssh`, `sudo` and the rest. Every review round added
a case — `-c`, `eval`, `$(…)`, `env -S`, wrapper options, `find
-exec`, quoted rsync operands — and the list could not be closed: `su
-c`, `script -c`, `watch`, `parallel`, `git -c core.sshCommand` and
make recipes still got through.

## Decision drivers

- A parser of shell text is never complete; each round found the
  next form.
- Claude Code sources `$CLAUDE_ENV_FILE` before every Bash call,
  subagents included.
- `git push` over SSH has to keep working.

## Considered options

### A shim first on PATH — chosen

`session-mode.sh` puts `.claude/hooks/shim/` first on `PATH`:
`ssh`, `scp`, `sudo` and the rest print the refusal and exit 1,
however they are started. Against it: it reaches only what looks
the tool up on `PATH`, so the guard still refuses a path to the
binary, `command -p` and a `PATH` set in front of a command. A
`Monitor` command gets no such promise, and the guard names the
tools there itself.

### Extending the parser

Add each form a review finds. Lost: every round added a case and
found the next one, and the tables grew without closing the gap.

## Decision

In development mode, the refusal happens where the tool runs: a
shim on `PATH`. `guard-mode.sh` keeps only the forms that bypass a
`PATH` lookup. `git push` reaches the real `ssh` through
`GIT_SSH_COMMAND`.

## Consequences

Wrappers, scripts and rsync's own `ssh` are refused without being
parsed. The operations half of the guard is unchanged. The refusal
arrives on stderr, not as a hook's deny, so its text lives in
`mode.sh` for both. A review finding that asks the development
guard to parse another wrapper is answered with this record.

## Confirmation

`guard-mode-test.sh` runs the shim and the remaining forms in
throwaway checkouts; a tool missing from the shim fails there.
