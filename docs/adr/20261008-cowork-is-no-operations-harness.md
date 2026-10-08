---
id: 20261008-cowork-is-no-operations-harness
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [guard, harness, safety]
---

# A VM apart from the workstation is its own mode

## Context

Claude Cowork runs the agent's shell in a Linux VM apart from the
workstation: no `~/.ssh`, no agent socket, and no hook of
`.claude/settings.json` fires there (anthropics/claude-code#40495,
open since March 2026; #63360 closed as not planned). Claude Code
on the web uses the same kind of VM but does run hooks;
`dev-tools.sh` already reads `CLAUDE_CODE_REMOTE` there. The VM
protects the workstation from the agent's code, not a server from
the agent. `20260924-marker-decides-session-mode` rejected an
environment variable as the source of the mode, because a
forgotten one would drift; that holds for granting operations, not
for taking it away.

## Decision drivers

- Every script and hook that tests `= operations` must fail closed
  in the VM without an edit of its own.
- In Cowork, only prose and what the session runs reach the model.
- The sign is observed, not documented, so it may fall silent; a
  stray value on a workstation must never count.

## Considered options

### A fourth mode value, `remote`, in `hostwarden_mode` — chosen

An operations checkout reads `remote` when `CLAUDE_CODE_REMOTE` is
`true`, the value `dev-tools.sh` reads, beside a Linux kernel.
Every consumer that tests for operations fails closed, the mode
guard and the shim refuse on the web, and the doctor prints the
way out for Cowork. Against it: a value that is not operations but
carries a workspace, so each consumer that restricts *because* the
checkout is operations — the edit guard, the wrap hook, the mirror,
the lab, init — has to name `remote` too; the taboo guard keeps
the full scope, and the read-only rule holds by prose where the
edit guard does not yet.

### A probe of its own, read by the doctor alone

`hostwarden_harness` beside `hostwarden_mode`. Lost: `update`,
`ssh-config`, `impact` and `sync` still answered operations in the
VM, so the refusal held only while the model obeyed the doctor's
line.

### A `Match exec` lock in `memory/ssh_config`

Lost: it locks a file that finds no key in the VM anyway, and a
change to Cowork silences it with no line saying why.

## Decision

`hostwarden_mode` answers `remote` for an operations checkout whose
shell runs in a VM apart from the workstation. The session start,
the mode guard, the shim and `bin/hostwarden-doctor` all name the
way out: the same checkout in Claude Code on the workstation.

## Consequences

A Cowork session fails in one line instead of late and confusingly;
a web session is refused mechanically. The variable can only take
operations away, so a forgotten or stray value is safe. Development
in the VM stays allowed. `lib/mode.sh` and `AGENTS.md` → Development
or Operations carry the constraint.

## Confirmation

`tests/hooks/guard-mode.sh` reads `remote` with the variable set on
Linux and operations on a Mac; a Cowork release that drops the
variable shows up as a session that reaches for a key it lacks.
