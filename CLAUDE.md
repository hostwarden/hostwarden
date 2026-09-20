@AGENTS.md

## Claude Code

`AGENTS.md` above is the whole instruction set and is what every
tool reads. This file adds only what exists here and nowhere else.

- **The taboo guard runs.** `.claude/hooks/guard-taboos.sh` is
  registered as a `PreToolUse` hook on `Bash` and denies in every
  permission mode, `--dangerously-skip-permissions` included. It
  applies to subagents too. Elsewhere the prose rules in `AGENTS.md`
  are the entire safety layer.
- **SessionStart hooks have already run.** They check for repo
  updates and create `~/.cache/hostwarden` with mode 0700, so the
  `mkdir` named under `AGENTS.md` → SSH Options is done. Where hooks
  do not run, it is not.
- **Ask with `AskUserQuestion`.** Any picker a rule describes —
  the SSH-user interview, the four-way restart question — uses it
  here. The ASCII fallback those rules give is for tools without it.
- **Skills are slash commands.** Every workflow is invocable
  directly: `/hostwarden-housekeeping`, `/hostwarden-security`,
  `/hostwarden-os-install`, and so on.
- **Conventions for editing this repository** load from
  `.claude/rules/` when the matching files are read. They are about
  hostwarden's own source, never about a managed host.
