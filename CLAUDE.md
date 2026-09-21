@AGENTS.md

## Claude Code

`AGENTS.md` above is the whole instruction set and is what every
tool reads. This file adds only what exists here and nowhere else.

- **The taboo guard runs.** `.claude/hooks/guard-taboos.sh` is
  registered as a `PreToolUse` hook on `Bash` and denies in every
  permission mode, `--dangerously-skip-permissions` included. It
  applies to subagents too. Elsewhere the prose rules in `AGENTS.md`
  are the entire safety layer. `guard-settings.sh` also denies
  writing the guard's off switch into a settings file.
- **SessionStart hooks have already run.** They check for repo
  updates and create `~/.cache/hostwarden` with mode 0700, so the
  `mkdir` named under `AGENTS.md` → SSH Options is done. Where hooks
  do not run, it is not. They also report a linked worktree or a
  guard that is off.
- **Ask with `AskUserQuestion`.** Any picker a rule describes —
  the SSH-user interview, the four-way restart question — uses it
  here. The ASCII fallback those rules give is for tools without it.
- **Skills are slash commands.** Every workflow is invocable
  directly: `/hostwarden-housekeeping`, `/hostwarden-security`,
  `/hostwarden-os-install`, and so on.
- **The fleet audit fans out.** `.claude/agents/` holds
  `hostwarden-host-probe`; the fleet-audit skill gives each host its
  own, so raw probe output stays out of this conversation.
  Elsewhere the same audit runs one host after another.
- **Conventions for editing this repository** load from
  `.claude/rules/` when the matching files are read. They are about
  hostwarden's own source, never about a managed host.
