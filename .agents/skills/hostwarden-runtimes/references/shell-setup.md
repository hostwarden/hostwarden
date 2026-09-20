# Making a runtime visible over SSH

Reached from the `hostwarden-runtimes` skill when a runtime is
installed but a non-interactive `ssh host "node --version"`
cannot find it. That is a shell-initialisation problem, not an
install problem, and it is the single most common reason a
deployment fails after a successful install.

## SSH Non-Interactive Shell Setup

**This is critical.** All hostwarden work runs via
`ssh user@host "command"` — a non-interactive,
non-login shell where `.bashrc` is typically not
sourced.

**Check the user's login shell first** — the steps
below are **bash-only**:

```
getent passwd <user> | cut -d: -f7
```

- **bash:** follow the `.bashrc` / `.bash_profile`
  steps below.
- **zsh** (macOS default): put the PATH export in
  `~/.zshenv` — zsh sources it for every
  invocation, including non-interactive SSH
  commands.
- **sh / csh** (FreeBSD root commonly runs these):
  POSIX `sh` reads the file named by `$ENV`
  (commonly `~/.shrc`); `csh`/`tcsh` read
  `~/.cshrc` and use `setenv PATH ...` syntax.

For bash, add both `~/.local/bin` (for the
`mise` binary itself) and the shims directory (for
language runtimes) to `PATH` **at the top of
`~/.bashrc`** — before the interactive guard
(`case $- in ...`). This is the only reliable way to
get mise into `ssh user@host "command"` on
Debian/Ubuntu, because `~/.bash_profile` is **not**
sourced for non-login, non-interactive SSH commands.

```bash
# Insert at the very top of ~/.bashrc.
# The grep guard makes re-runs a no-op.
grep -q '# mise (before interactive guard)' ~/.bashrc || \
sed -i '1i# mise (before interactive guard)\
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"\
' ~/.bashrc
```

Also extend `~/.bash_profile` to source `.bashrc`
for interactive login shells and set XDG_RUNTIME_DIR
(needed for systemd user services over SSH). Back up
an existing file first (`rules/backups.md`), append
rather than overwrite, and guard with a marker so
re-runs are no-ops:

```bash
[ -f ~/.bash_profile ] && \
  cp ~/.bash_profile ~/.bash_profile.bak.$(date +%F)
grep -q '# mise shims' ~/.bash_profile 2>/dev/null || \
cat >> ~/.bash_profile << 'EOF'
# mise shims
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Source .bashrc for interactive login shells
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
```

**Verify it works:**

```
ssh <options> user@host "mise --version; node --version"
```

If neither file is sourced, fall back to:

1. **Explicit PATH prefix** in commands:
   ```
   PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" node -v
   ```
2. **`mise exec`** to run commands in a mise-managed
   environment:
   ```
   ~/.local/bin/mise exec -- node -v
   ```
