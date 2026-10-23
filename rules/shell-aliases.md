# Shell Aliases and Functions

A shell that read the user's profile can answer a command name with an
alias or a function instead of the tool: `rm -i` without a terminal
keeps the file and exits 0, a `ls` or `grep` alias changes the output
a parser reads. The rule is by context, not by command.

## Which calls get the prefix

Every command whose output or effect the session relies on, in a
shell that may have read the user's profile or functions, is written
`command <tool>`: the workstation shell, local mode, a plain
`ssh host 'cmd'` whose remote login shell expands, `bash -lc`,
`bash -ic`, `su -`, `runuser -l`. `command` skips aliases and shell
functions. In csh and tcsh, which have no `command`, write `\<tool>`.
`cp`, `mv` and `rm` are the example to remember: the failure is
silent.

`sudo` is the one case where the prefix goes in front of the tool
too: an alias `sudo='sudo '` expands the next word, so a line the
shell reads itself is `command sudo rm …`.

## Which calls need none

No alias expands inside an `sh -s` bundle, a non-interactive
`sh -c`, a script run as a file, or behind `xargs` and `find -exec`.
The plain tool is right there; the prefix is harmless, and a probe
may keep it.

## Limits

- A shell keyword (`if`, `for`, `while`, `case`) and a builtin that
  changes shell state (`cd`, `export`, `set`, `unset`, `read`,
  `umask`, `source`) take no prefix: zsh, the macOS default, has
  no `command export`, and `command cd` does not move the caller.
  Where an alias hides one, `builtin <name>` bypasses it.
- `command` does not bypass a wrapper earlier in `PATH`, such as a
  mise or Homebrew shim. Where that matters, call the absolute path,
  as `rules/os/macos.md` does for `/usr/bin/log`.
- `type -a <name>` shows what answers a name: alias, function or
  files on `PATH`, in order.
- A `cat` or `tee` that writes a text file through a heredoc is
  written without the prefix: the guard recognises the plain shape
  and reads the body as data, which it does not do behind
  `command`. `btrfs balance status|pause|cancel|resume` and a
  lookup such as `man` likewise stay plain.
- Never `yes |`, and never an added flag, to beat an alias.
