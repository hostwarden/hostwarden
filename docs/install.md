# Installing Hostwarden

The short path is in the
[README](../README.md#how-to-install). This page has
the details behind each prerequisite and the setup
for native Windows.

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
  target machines. All supported systems can also be
  managed locally without SSH.
- **A checkout that supports symbolic links.**
  Hostwarden uses them in two load-bearing places:
  `.claude/skills` links to `.agents/skills/`, and
  DNS aliases become symlinks under
  `memory/servers/`. macOS, Linux, FreeBSD and WSL
  handle them out of the box; native Windows needs
  the three settings under [Windows](#windows).
  A session-start hook says so whenever the skills are
  out of reach, because a session without them is
  otherwise silent about it;
  `sh .claude/hooks/instructions-test.sh` reports the
  state at any time.
- **Workstation:** Hostwarden itself runs wherever
  your AI tool runs — Linux, macOS, FreeBSD, or
  Windows.
- **Local tools.** `bin/hostwarden-doctor` lists
  what Hostwarden needs on your workstation, what is
  missing, and the command to install it.

## Windows

**Use [WSL](https://learn.microsoft.com/windows/wsl/)
if you can.** It is a full Linux environment, and
Hostwarden runs in it exactly as on Linux, with
nothing below to set up.

Running natively through
[Git for Windows](https://gitforwindows.org/) works,
but Windows does not create symbolic links for an
ordinary user, and both git and Git Bash fall back to
something else **without an error**:

- git writes each link as a small text file holding
  the target path. `.claude/skills` then leads
  nowhere, and Hostwarden runs without a single skill
  — no housekeeping, no security audit.
- Git Bash's `ln -s`
  [copies the target](https://gitforwindows.org/symbolic-links.html)
  instead of linking to it. A DNS alias then gets its own copy of
  the server memory, and the two drift apart.

So, once, **before cloning**:

1. Turn on Developer Mode (Windows 11: Settings →
   System → For developers). It lets an ordinary user create
   symbolic links; without it, only an elevated shell
   can.
2. Tell git to create real links:
   ```
   git config --global core.symlinks true
   ```
3. Tell Git Bash to link rather than copy, and to fail
   loudly when it cannot — add this to `~/.bashrc`, then
   open a new Git Bash (one already open has not read it):
   ```
   export MSYS=winsymlinks:nativestrict
   ```

Then clone as the
[README](../README.md#steps) describes, and start
Claude Code or OpenCode from **Git Bash**, so the
SessionStart hooks and the `bin/hostwarden-*`
scripts can run. PowerShell and
`cmd.exe` are not supported as the launch shell.

<details>
<summary>Already cloned without these settings?</summary>

After steps 1–3, replace the text file with the
link, then check it; no output means it is fine.
The clone may have recorded
`core.symlinks=false` for itself, which outranks the
global setting, so set it here too:

```
git config core.symlinks true
rm .claude/skills
git checkout -- .claude/skills
sh .claude/hooks/check-skills.sh
```

An archive download (ZIP) cannot be repaired this way,
because it is no git clone: clone the repository instead.

A DNS alias created before step 3 is a directory
where `ls -l memory/servers/` should show a link. Its
memory has diverged from the canonical host's and has
to be merged back by hand before the directory is
replaced with a link.

</details>
