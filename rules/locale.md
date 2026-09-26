# Locale

A host can run in any language, and its tools answer in it. Run
every command on a host with `LC_ALL=C` instead, so that what comes
back is English, whatever reads it next: a match in
a probe, a label a rule quotes, or the session reporting to the
user. A translation breaks a match without an error — under
`de_DE.UTF-8`, `ufw status verbose` labels its policy line
`Voreinstellung:` where a check greps `^Default:`, `sudo -V` says
`Sudoers-Pfad:`, `apt-cache policy` says `Installationskandidat:`,
and `free -h` prints `Speicher:` for `Mem:` and `1,5Gi` for
`1.5Gi`.

## Where it is set

- **A call** opens with `export LC_ALL=C`, before its first
  command: a bundle (`rules/ssh-connections.md` → Bundle
  commands), and a call whose commands go to the login shell in
  `sh` syntax. A single command sent on its own may take
  `env LC_ALL=C` in front instead, which works in any shell.
- **The first call** (`rules/first-detection.md`) runs before the
  login shell is known, and csh takes neither `export` nor a
  `VAR=value` prefix. It puts `env LC_ALL=C` in front of `df`
  and `free`, whose labels and decimal points it reads.
- **Local mode:** each shell call opens with `export LC_ALL=C`.
- **Where a new environment starts,** set it again inside it:
  `su -` and `runuser -l` drop it, and so can a container or
  guest shell (`pct exec`, `incus exec`, `docker exec`,
  `lxc-attach`) and an `ssh` from the host onward. `sudo` keeps
  it as it is configured by default.
- **Never through SSH itself.** `SendEnv`, or a variable set in the
  local shell, reaches the host only where its `AcceptEnv` lets it,
  and nothing says when it did not.

Windows is the exception: its bundle is PowerShell
(`rules/os/windows.md` → Reaching PowerShell), which `LC_ALL` does
not reach, and whose text follows the system's display language.
Read object properties, SIDs and numbers there, never display text
(`rules/os/windows.md` → Common Pitfalls).

## Why these values

- **`LC_ALL`, not `LANG`.** `LANG` is only the fallback: an
  account's `LC_MESSAGES` or `LC_NUMERIC` still wins over
  `LANG=C`. `LC_ALL` wins over every `LC_*` variable and over
  `LANG`.
- **`LANGUAGE` needs nothing.** GNU gettext ignores it once the
  locale is `C`
  (<https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html>).
- **`C`, not `C.UTF-8`.** `C` exists on every system; a
  `C.UTF-8` missing on an older release or an appliance makes
  bash write `setlocale: LC_ALL: cannot change locale` to stderr,
  into any output read with `2>&1`. `C` passes the bytes of a
  UTF-8 value through unchanged, so a name or a comment in the
  output still reads correctly.

## Other output a probe cannot read

- **Pagers.** Where a call runs with a terminal (`ssh -t`),
  `systemctl`, `journalctl` and `git` start a pager, which can
  wait for a key. Pass `--no-pager`.
- **Color.** An account's environment can keep colors in a pipe
  (`CLICOLOR_FORCE` for `ls` on macOS and FreeBSD). Where a tool
  has `--color=never`, a parsed call passes it.
- **Tables.** Read a command's machine-readable form where it has
  one — `nmcli -t`, `ps -o <field>=`, `--output=json` — rather
  than a table laid out for a terminal.
