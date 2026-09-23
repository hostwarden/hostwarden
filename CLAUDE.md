@AGENTS.md

## Claude Code

`AGENTS.md` above is the whole instruction set and is what every
tool reads. This file adds only what exists here and nowhere else.

- **The taboo guard runs.** `.claude/hooks/guard-taboos.sh` is
  registered as a `PreToolUse` hook on `Bash` and `Monitor`, which
  both run shell commands, and on the edit tools, which it judges
  by the file they write. It denies in every permission mode,
  `--dangerously-skip-permissions` included. Stopping or deleting
  a system container or VM, writing sshd's configuration or keys
  into a guest that has never started or clearing its image's old
  host keys, and the routine storage changes `rules/storage.md`
  lists, it asks about instead, and denies only where no prompt
  reaches a human. The `PowerShell`
  tool, whose commands it cannot read, is denied outright. It
  applies to subagents too. Elsewhere the prose rules in `AGENTS.md`
  are the entire safety layer. The off switch counts only for a
  session that started with it; `guard-settings.sh` keeps it out
  of settings files.
- **The mode is announced and enforced.** A SessionStart hook
  names the mode `AGENTS.md` → Development or Operations
  describes, and `.claude/hooks/guard-mode.sh` holds the session to
  it: no server from a development checkout or a worktree, no edit
  to shipped files in an operations one. The taboo guard's
  disable variable does not reach it. In development the same
  SessionStart hook puts `.claude/hooks/shim/` first on the
  `PATH` of every Bash call, subagents' included: `ssh`, `scp`,
  `sudo` and the rest print the refusal on stderr and fail
  however they are started. A `Monitor` command gets no such
  promise from Claude Code, so there `guard-mode.sh` itself
  refuses them by name as well. `git push` reaches the real `ssh`
  through `GIT_SSH_COMMAND`, which is `.claude/hooks/git-ssh.sh`.
- **SessionStart hooks have already run.** They have:
  - in an operations checkout, checked for repo updates and
    pulled the workspace;
  - created `~/.cache/hostwarden` with mode 0700, the `mkdir`
    under `AGENTS.md` → SSH Options;
  - run `bin/hostwarden-doctor --quiet`, whose output, if any,
    names the workstation tools that are missing;
  - reported a linked worktree or a guard that is off, if either
    applies.

  Where hooks do not run, `rules/session-start.md` says what to do
  instead.
- **Ask with `AskUserQuestion`.** Any picker a rule describes —
  the SSH-user interview, the four-way restart question — uses it
  here. The ASCII fallback those rules give is for tools without it.
- **Sessions on this machine can be reached.** When a host's session
  register names your own `user@workstation`
  (`rules/parallel-sessions.md`), or a development session hands a
  question over (`rules/server-check-handoff.md`), `ListAgents`
  lists the sessions here and `SendMessage` reaches them. With none
  in the operations checkout, the one command is
  `claude "<question>"`, run there — never a task chip, which starts
  in a new worktree.
- **Skills are slash commands.** Every workflow is invocable
  directly: `/hostwarden-housekeeping`, `/hostwarden-security`,
  `/hostwarden-os-install`, and so on.
- **The fleet audit fans out.** `.claude/agents/` holds
  `hostwarden-host-probe`; the fleet-audit skill gives each host its
  own, so raw probe output stays out of this conversation.
  Elsewhere the same audit runs one host after another.
- **Conventions for editing this repository** load from
  `.claude/rules/` when the matching files are read. They are about
  Hostwarden's own source, never about a managed host.
