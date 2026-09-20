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

## Pre-Install Check

Before installing anything, find out whether mise is
already there:

```
# Remote — the standard SSH options from CLAUDE.md apply
ssh <options> user@host "command -v mise"

# Local
command -v mise
```

`command -v` prints the absolute path, so one call answers
both questions — whether mise is there and which kind it
is. Do not follow it with `which`.

Any hit is used as is. Never install a second copy beside
one already there, and go straight to § Making a runtime
visible over SSH: the shims directory
(`~/.local/share/mise/shims`) is per-user whichever kind
was found. A system-wide mise (`/usr/bin/mise`,
`/usr/local/bin/mise`) only lets you skip the
`~/.local/bin` half of that setup.

No hit: install.

## Installing mise

Only when the pre-install check above found none:
`references/install-mise.md`. It covers the official installer,
the distro-package trap, and the FreeBSD and macOS paths.

## Making a runtime visible over SSH

Every install ends here, and so does every
`ssh host "node --version"` that fails after one — a
non-interactive shell does not read the files an
interactive one does, so the runtime is there and
unreachable. `references/shell-setup.md` carries the
per-shell setup and the order the lines have to go in.

## Installing Languages

Install languages **as the SSH user** (not root).
Web-search the current LTS/stable version first —
never trust training data (see CLAUDE.md). Use
`mise use --global` to set a default version — without
`--global` it writes a `.tool-versions` into the current
directory instead, which is not what a server-wide install
means:

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
