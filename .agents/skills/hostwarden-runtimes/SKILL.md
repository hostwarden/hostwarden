---
name: hostwarden-runtimes
argument-hint: "[hostname] [runtime@version]"
description: Install or upgrade a programming language runtime on
  a server — Node.js, Python, Ruby, Go, Java, Elixir, Rust and
  anything else mise carries. Use when the user asks to "install
  Node on <host>", "put the latest stable Ruby on this server",
  "upgrade Python", "which Node version is on web1", "install
  Rails", or names any language or framework that needs a runtime
  before it can run. Also covers the non-interactive shell setup
  that makes the runtime visible over SSH.
---

# mise — Language Runtime Manager

Installing programming languages on servers using
[mise](https://mise.jdx.dev). Applies to every distro family and
to macOS and FreeBSD alike.

**The policy, before the procedure:** a language runtime comes
from mise, never from the distribution's packages and never from
nvm, rbenv, pyenv or asdf. `rules/best-practices.md` carries the
reasoning under "Runtime via apt/dnf/zypper"; what it adds here
is that a second version manager on the same host is a second
source of truth. Either is fine when the user asks for it by
name — never by default, and never silently.

## When to Use mise

Use mise for **language runtimes** — Node.js, Ruby,
Python, Elixir, Go, Java, etc. Do **not** use mise for
system tools or services (nginx, PostgreSQL, etc.) —
those should come from the distro's package manager.

## Common Pitfalls

- mise must be installed as the SSH user, not root.
  Running `mise use` as root installs runtimes for
  root only.
- The shims PATH setup in `~/.bashrc` must be
  **before** the interactive guard (`case $- in ...`).
  If placed after, `ssh user@host "command"` won't
  find mise-installed binaries.
- After installing a language, always verify over SSH:
  `ssh user@host "node --version"`. If it fails, the
  PATH setup is wrong.
- `mise use --global` sets the default version. Without
  `--global`, it creates a local `.tool-versions` file
  in the current directory.
- For standalone installs, `~/.local/bin` must be in
  PATH for the `mise` binary itself. This is separate
  from the shims directory (`~/.local/share/mise/shims`)
  which provides the language runtime binaries. Both
  must be in PATH.

## Pre-Install Check

Before installing mise, check whether it is already
present on the system. A system-wide installation
(via package manager) is preferred over a per-user
standalone install.

**Step 1 — Check if mise exists for the SSH user:**

```
# Remote — the standard SSH options from AGENTS.md apply
ssh <options> user@host "command -v mise"

# Local
command -v mise
```

`command -v` prints the absolute path, so that one call
already answers both questions — whether mise is there
and which kind it is. Do not follow it with `which`.

- **System-wide** (`/usr/bin/mise`,
  `/usr/local/bin/mise`): Use it as-is. Skip the
  Installation section. Proceed to SSH
  Non-Interactive Shell Setup (shims PATH still
  needs to be configured per user).
- **User-local** (`~/.local/bin/mise`): Use it
  as-is. Skip the Installation section. Proceed to
  SSH Non-Interactive Shell Setup if not already
  configured.

If `command -v mise` fails, proceed to Installation.

**Note:** When a system-wide mise is found, do
**not** install a second copy locally. The shims
directory (`~/.local/share/mise/shims`) is still
per-user and still needs PATH setup — only the
`~/.local/bin` part of the PATH setup can be
skipped.

## Installing mise

Only when the pre-install check above found none:
`references/install-mise.md`. It covers the official installer,
the distro-package trap, and the FreeBSD and macOS paths.

## When the runtime is invisible over SSH

`ssh host "node --version"` failing after a successful install is
a shell-initialisation problem, not an install problem:
`references/shell-setup.md`.

## Installing Languages

Install languages **as the SSH user** (not root).
Web-search the current LTS/stable version first —
never trust training data (see CLAUDE.md). Use
`mise use --global` to set a default version:

```
mise use --global node@<current-LTS>
mise use --global ruby@<current-stable>
```

After installing, verify over SSH:

```
ssh <options> user@host "node --version; ruby --version"
```

## Server Memory Convention

When mise and languages are installed, add a single
line to the server's `memory.md`:

```
- mise: node@<version>, ruby@<version>
```

Update this line whenever languages are added, removed,
or upgraded.
