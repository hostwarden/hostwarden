---
name: hostwarden-runtimes
argument-hint: "[hostname] [runtime@version]"
description: Install, upgrade, report on or remove a programming
  language runtime on a server — Node.js, Python, Ruby, Go, Java,
  Elixir, Rust and anything else mise carries. Use when the user
  asks to "install Node on <host>", "put the latest stable Ruby on
  this server", "upgrade Python", "which Node version is on web1",
  "what runtimes does this host have", "remove Ruby from web1",
  "install Rails", or names any language or framework that needs a
  runtime before it can run. Also covers the non-interactive shell
  setup that makes the runtime visible over SSH.
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

## Asking is not installing

"Which Node version is on web1", "what runtimes does this
host have" and anything else phrased as a question is
answered and finished. Report what is installed, or that
nothing is — do not install mise, do not install a runtime,
do not offer to as part of the answer. The user asked what
is there.

```
mise ls --current 2>/dev/null || command -v mise \
  || echo "no mise"
```

No mise means no mise-managed runtime; say that, and name
any system package that provides the runtime instead
(`command -v node`) so the answer is about the host rather
than about mise. Installing is a separate request, and the
user makes it.

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
the distro-package trap, and what macOS and FreeBSD do instead.

## Making a runtime visible over SSH

Every install ends here, and so does every
`ssh host "node --version"` that fails after one — a
non-interactive shell does not read the files an
interactive one does, so the runtime is there and
unreachable. `references/shell-setup.md` carries the
per-shell setup and the order the lines have to go in.

## Installing Languages

Install languages **as the SSH user** (not root).

**A version the user named is the version to install.**
`node@20`, "Ruby 3.3", the `runtime@version` argument — take
it as given and do not substitute the current release for
it. Only when the request names no version does the version
have to be looked up, and then by web search, never from
training data (see CLAUDE.md).

Use `mise use --global` to set a default version — without
`--global` it writes a `.tool-versions` into the current
directory instead, which is not what a server-wide install
means:

```
mise use --global node@20          # asked for by version
mise use --global ruby@<looked-up> # no version named
```

Verify each runtime in its own call, and read each status.
Chaining them with `;` reports only the last command's
status, so a failed install hides behind a later success:

```
ssh <options> user@host "node --version"
ssh <options> user@host "ruby --version"
```

Only the runtimes this request installed. Asking a host for
a runtime nobody put there reports a failure that is not one.

## Server Memory Convention

When mise and languages are installed, add a single
line to the server's `memory.md`:

```
- mise: node@<version>, ruby@<version>
```

Update this line whenever languages are added, removed,
or upgraded.
