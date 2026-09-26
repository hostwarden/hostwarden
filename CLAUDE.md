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
  are the entire safety layer. The off switch names one host, or
  `localhost`, and opens the guard only toward it; it counts only
  for a session that started with it, and `guard-settings.sh`
  keeps it out of settings files.
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
  - in an operations checkout, checked for repo updates,
    pulled the workspace and written `memory/ssh_config`
    (`AGENTS.md` → SSH Options);
  - created `~/.cache/hostwarden` with mode 0700, where the
    shared SSH connections keep their sockets;
  - run `bin/hostwarden-doctor --quiet`, whose output, if any,
    names the workstation tools that are missing — in a
    development checkout, the ones working on Hostwarden needs —
    and a shell for Claude Code that is not a Bash 4 or newer;
  - reported a linked worktree or a guard that is off, if either
    applies;
  - in an operations checkout, started the coordinator in the
    background where none runs and `memory/user.md` has no
    `Coordinator: off`, and said so in one line
    (`rules/coordination.md` → The coordinator).

  Where hooks do not run, `rules/session-start.md` says what to do
  instead.
- **Ask with `AskUserQuestion`.** Any picker a rule describes —
  the SSH-user interview, the four-way restart question — uses it
  here. The ASCII fallback those rules give is for tools without it.
- **Sessions on this machine can be reached.** When a host's session
  register names your own `user@workstation`
  (`rules/parallel-sessions.md`), or a development session hands a
  question over (`rules/server-check-handoff.md`), `ListAgents`
  lists the sessions here and `SendMessage` reaches them; the
  coordinator is `hostwarden coordinator`. With none
  in the operations checkout, the one command is
  `claude "<question>"`, run there — never a task chip, which starts
  in a new worktree.
- **Coordination runs in operations checkouts.**
  `.claude/hooks/presence.sh`, a PreToolUse and PostToolUse hook on
  `Bash` and `Monitor`, keeps the local presence map
  `rules/coordination.md` → Presence map describes.
  `.claude/hooks/impact.sh`, a PreToolUse hook on `Bash`, denies a
  disruptive command aimed at a host with another live session on
  it until `bin/hostwarden-impact announce` has run, and refuses
  once, informing rather than holding, a command aimed at a host
  inside another session's active impact (`rules/coordination.md`
  → The hooks). Neither reaches the taboo guard's disable
  variable, and both run only where `mode.sh` reports operations.
- **Markdown wraps itself.** `.claude/hooks/wrap-markdown.sh`, a
  PostToolUse hook, runs `bin/hostwarden-wrap` on each `.md` an
  edit tool writes, and after a shell command on each `.md` git
  sees as changed or new: the checkout's in development, those in
  `memory/` in operations. In operations it never rewraps a shipped
  file. Leave the wrapping to it; its message names any line it
  could not wrap.
- **Skills are slash commands.** Every workflow is invocable
  directly: `/hostwarden-housekeeping`, `/hostwarden-security`,
  `/hostwarden-os-install`, and so on.
- **Work on several hosts fans out.** `.claude/agents/` holds
  `hostwarden-host-probe`, which the fleet-audit skill gives each
  host, and `hostwarden-host-task`, which `rules/multi-host.md` gives
  each host of any other task, so raw output stays out of this
  conversation. Elsewhere the same work runs one host after
  another.
- **Conventions for editing this repository** load from
  `.claude/rules/` when the matching files are read. They are about
  Hostwarden's own source, never about a managed host.
