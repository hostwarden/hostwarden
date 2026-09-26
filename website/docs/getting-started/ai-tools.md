---
sidebar_position: 4
---

# Supported AI tools

Hostwarden targets Claude Code. Its instruction set is
plain Markdown in the places the wider convention has
settled on, so other tools get most of it for free.
`AGENTS.md` is read by Claude Code, OpenCode, Codex and
Cursor alike, and the `rules/` files are reached by name
from it. Any terminal AI tool that reads project files
and runs shell commands handles the rule layer.

The skills differ by tool. OpenCode, Codex and Cursor
read `.agents/skills/` directly; Claude Code searches
`.claude/` only, and finds them through the
`.claude/skills` symlink — which is why that link is a
prerequisite and not a convenience. Do not remove it
thinking `.agents/skills/` covers Claude Code too; a
checkout without it has no skills at all and says
nothing. On a tool with no Skills support, ask for those
workflows by naming the file —
`.agents/skills/<name>/SKILL.md`.

What is Claude Code only: the taboo guard hook and the
repo conventions in `.claude/rules/`. Elsewhere the
prose rules are the entire safety layer. The
session-start hooks are Claude Code's too: elsewhere
the session runs `bin/hostwarden-doctor` itself at the
start and passes on what it reports. In a checkout for
working on Hostwarden it checks the tools that work
needs instead. The per-host
subagents of the fleet audit and of a task on several
servers are Claude Code's: elsewhere the same work walks
the hosts in turn, and only the time and the context it
takes differ.

OpenCode note: `OPENCODE_DISABLE_CLAUDE_CODE=1` turns
off every `.claude` fallback, and Hostwarden still works
with it set. Both of the things it needs — `AGENTS.md`
and `.agents/skills/` — are paths OpenCode reads
natively; `CLAUDE.md` is a fallback it only consults
when no `AGENTS.md` exists, which is never here.

## Claude Code

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)
is Anthropic's CLI for Claude, and the primary tool
Hostwarden was developed with. It reads `AGENTS.md`
directly. `CLAUDE.md` stays anyway: it imports
`AGENTS.md` with `@AGENTS.md`, which covers the setups
where the direct read does not happen, and it carries
the handful of things that exist only here — the guard
hook, the session-start hooks, the subagents. Keep both.

```
claude
```

## Claude Code Desktop

The Code tab of the Claude desktop app (macOS,
Windows) runs the same Claude Code: `AGENTS.md`, the
skills, the subagents and every hook in
`.claude/settings.json` work there as they do in the
terminal, taboo guard included. Four things need
attention.

**Turn the worktree option off.** The app can start
each session in its own git worktree under
`.claude/worktrees/`. Everything that is yours lives
in `memory/`, which git ignores — so a worktree has
no blacklist, no read-only list, no SSH users and no
machine memory, and what the session learns is
deleted with the worktree. Hostwarden therefore
refuses to reach any machine from a worktree, and a
session-start hook says so at once. Open the
Hostwarden folder itself, with the worktree option
off. (Working on Hostwarden's own source in a
worktree is fine.)

**Environment variables go into
`.claude/settings.local.json`.** There is no shell to
`export` from. The app does pick up variables from
your shell profile, but when it reads them is not
something to rely on for a safety switch. Put them in
the `env` key of `.claude/settings.local.json` — it
is gitignored, so it stays yours — and start a new
session:

```json
{
  "env": {
    "HOSTWARDEN_NO_UPDATE": "1"
  }
}
```

**Switching the taboo guard off works the same way,
by hand.** For the disk steps of an OS install (the
`hostwarden-os-install` skill), add
`"HOSTWARDEN_GUARD_DISABLE": "web1.example.com"` to that
`env` in your editor, with the name of the one host
the disk writes run on (for a guest whose disk is
written from its hypervisor, the hypervisor), or
`localhost` for this machine,
and start a new session. It opens with a note that
the guard is off toward that host — that note is how
you know the setting took effect. The guard stays on
for every other host, and a value of `1` is refused. Remove the line and
start another session when the work is done; the
file outlasts the session, and so would a guard that
is off. Set in the middle of a session, it does
nothing: the guard honours it only for a session that
started with it. Hostwarden cannot set it for you —
`.claude/hooks/guard-settings.sh` denies writing it
into a settings file.

**Permission modes are a menu, not a flag.** Pick
Ask, Accept edits, Plan, Auto or Bypass in the
session's mode selector; which ones you see depends
on your plan. `--permission-mode auto`, `claude -p`
and cron (see
[Command line interface](../running-it/unattended/automation.md#command-line-interface))
need the `claude` CLI, which the app does not put on
your `PATH`. For recurring runs the app has its own
scheduled tasks — they run only while the app is open
and the machine is awake, and need the worktree
option off like any other session. Answer the
prompt's one-time questions in a normal session
first, as described under
[Scheduled housekeeping](../running-it/unattended/scheduled.md).

SSH works as in the terminal. If your key sits in an
agent that your shell profile points to
(`SSH_AUTH_SOCK`), `IdentityAgent` in `~/.ssh/config`
makes that independent of how the app starts.

On Windows, run the session in WSL 2, as described
under [Windows](install.md#windows).

## OpenCode with Ollama

[OpenCode](https://opencode.ai) is an open-source
terminal AI tool that supports many providers,
including local free models via
[Ollama](https://ollama.com). This lets you run
Hostwarden entirely on your own hardware — no cloud
API required.

**1. Install Ollama and pull a model**

```bash
ollama pull qwen3.5:9b
```

**2. Expand the context window**

Ollama defaults to 4096 tokens — too small for
agentic tool use. Create a variant with a larger
context:

```bash
ollama run qwen3.5:9b
>>> /set parameter num_ctx 16384
>>> /save qwen3.5:9b-16k
>>> /bye
```

**3. Configure OpenCode**

Copy the example config and adjust if needed:

```bash
cp templates/memory/opencode.json.example memory/opencode.json
```

Edit `memory/opencode.json` to match your setup —
e.g. change the `baseURL` if Ollama runs on a
different host (`http://192.168.0.3:11434/v1`), or
change the model name. The file is gitignored so
local edits won't conflict on `git pull`.

**4. Launch OpenCode**

```
opencode
```

Select the Ollama model from the model picker (search for qwen).
Start the model picker by typing `/models` in the OpenCode terminal.

> **Note:** Larger models (14B+) produce more
> reliable tool calls. If you have the GPU memory,
> prefer a bigger model. The `tools: true` flag is
> required for agentic features. See the
> [OpenCode provider docs](https://opencode.ai/docs/providers/)
> for more configuration options.
