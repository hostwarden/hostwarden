---
sidebar_position: 1
---

# Installing Hostwarden

The short path is in the
[README](https://github.com/hostwarden/hostwarden#how-to-install). This page has
the details behind each prerequisite and the setup
for Windows.

## Prerequisites

- **An AI coding assistant** that runs in the
  terminal — e.g.
  [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  or [OpenCode](https://opencode.ai) — or the Claude
  desktop app's Code tab, set up as described in
  [Claude Code Desktop](ai-tools.md#claude-code-desktop).
- **[jq](https://jqlang.org)** for Claude Code's
  guard hooks. Without it they cannot read what a
  tool call does, and the mode guard refuses
  whatever it cannot show to be safe.
- **SSH access** to the target server — either as a
  normal user or as root. The SSH connection must
  not prompt for a password or passphrase (use
  key-based authentication without a passphrase).
  This is not needed for local administration
  (localhost / your own machine).

  Hostwarden shares one SSH connection per host and
  keeps it open for 10 minutes after the last call.
  The sockets live in `~/.cache/hostwarden` (mode 0700),
  so any process of your local user can use an open
  connection without asking for the key again.

  Quick setup: generate a key with `ssh-keygen`,
  copy it to the server with `ssh-copy-id user@host`,
  and test with `ssh user@host`. See the
  [Arch wiki SSH keys guide](https://wiki.archlinux.org/title/SSH_keys)
  for details.

- Linux (any distribution), FreeBSD, or macOS on the
  target machines; these can also be managed locally
  without SSH. Windows Server is a target over SSH
  only, mostly read-only (`rules/os/windows.md`); a
  Windows workstation runs Hostwarden in WSL 2, under
  [Windows](#windows).
- **A checkout that supports symbolic links.**
  Hostwarden uses them in two load-bearing places:
  `.claude/skills` links to `.agents/skills/`, and
  DNS aliases become symlinks under
  `memory/servers/`. macOS, Linux, FreeBSD and WSL
  handle them out of the box; a clone without them is
  repaired as described under
  [Symbolic links](#symbolic-links).
  A session-start hook says so whenever the skills are
  out of reach, because a session without them is
  otherwise silent about it;
  `sh .claude/hooks/instructions-test.sh` reports the
  state at any time.
- **Workstation:** Linux, macOS or FreeBSD, and on
  Windows a WSL 2 distribution — see
  [Windows](#windows).
- **Local tools.** `bin/hostwarden-doctor` lists
  what Hostwarden needs on your workstation, what is
  missing, and the command to install it.

## Windows

Hostwarden runs in a
[WSL 2](https://learn.microsoft.com/windows/wsl/install)
distribution, never on Windows itself. Inside WSL it
runs exactly as on Linux, with nothing extra to set
up.

1. Install WSL 2 with Ubuntu, Microsoft's default and
   the distribution this page assumes. It needs
   Windows 10 version 2004 or later, or Windows 11.
   In a PowerShell run as administrator:
   ```
   wsl --install
   ```
   Then restart Windows. Where WSL is already
   installed, this prints its help instead; install
   the distribution with `wsl --install -d Ubuntu`
   (`wsl --list --online` shows the names). A
   distribution still on WSL 1 (`wsl --list
   --verbose` shows the version) converts with
   `wsl --set-version Ubuntu 2`.
2. Open Ubuntu, create the Linux user it asks for,
   and install git and jq:
   ```
   sudo apt-get update
   sudo apt-get install git jq
   ```
   `bin/hostwarden-doctor` names the rest once the
   clone is there.
3. Clone into the distribution's own filesystem —
   under `~`, not under `/mnt/c` — as the
   [README](https://github.com/hostwarden/hostwarden#steps) describes.
4. Give the distribution an SSH key it can use. The
   `ssh` inside WSL does not see Windows' ssh-agent or
   a password manager's agent on Windows. Either keep
   a key in `~/.ssh` inside the distribution, or relay
   the Windows agent into WSL with a tool built for
   that. Pointing `ssh` at Windows' `ssh.exe` does not
   work: it cannot share a connection, and in a
   development checkout the guard refuses it.
5. Start Claude Code or OpenCode inside the
   distribution. In the Claude desktop app, pick the
   distribution in the Code tab's environment picker
   ([Claude Code Desktop in WSL](https://code.claude.com/docs/en/desktop-wsl)).

`bin/hostwarden-doctor` checks steps 3 and 4 inside
WSL.

Git Bash, PowerShell and `cmd.exe` are not supported
as the shell Hostwarden itself runs in. The guard
hooks are POSIX shell scripts, neither Windows' own
OpenSSH nor Git Bash's ssh can share a connection
(`ControlMaster`), and Claude Code's PowerShell tool
would bypass every guard. `.claude/settings.json`
therefore denies the PowerShell tool, and
`bin/hostwarden-doctor` reports a native Windows shell
as a required item missing.

## Symbolic links

When git cannot create a link, it writes a small text
file holding the target path instead, **without an
error**. `.claude/skills` then leads nowhere, and
Hostwarden runs without a single skill. To repair a
clone, allow links for it — it may have recorded
`core.symlinks=false` for itself — and check the
result; no output means it is fine:

```
git config core.symlinks true
rm .claude/skills
git checkout -- .claude/skills
sh .claude/hooks/check-skills.sh
```

An archive download (ZIP) cannot be repaired this way,
because it is no git clone: clone the repository instead.

A DNS alias that became a directory rather than a link
(`ls -l memory/servers/` shows which) has its own copy
of the server memory. It has diverged from the canonical
host's and has to be merged back by hand before the
directory is replaced with a link.
