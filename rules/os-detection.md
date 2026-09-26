# OS Detection (mandatory first step)

Before doing any work on a server, you **must** know
its OS.

Detection is what makes `rules/os/`,
`rules/appliance/`, `rules/platform/` and
`rules/role/` reachable. Those files are not rules
that fire on a situation — they are reference data
addressed by a fact this procedure establishes.
Detection reads **at most one** family file — the family
it just established, and no other — and on top of it
**at most one** appliance file, **at most one**
platform file and **at most one** role file, in that
order (see Layers below). A distribution no family
covers gets no family file;
`rules/first-detection.md` → On first connection,
step 2, says what to do instead. Never reach for the
nearest file — a Debian reference on an Arch host
prescribes the wrong package manager and the wrong
firewall.

That cap is on detection, not on the session. A
workflow that deals with two operating systems at once
— an OS replacement, a dual-boot setup — reads the
file for each of them, old and new, because each is a
fact about a real system. The `hostwarden-os-install`
skill says so where it needs it.

This file is read on every connection. What
detection settles once and records in machine memory
is in `rules/first-detection.md`: a first connection
reads all of it, a known host only the section that
settles a line its memory lacks (On subsequent
connections below).

## The first call

Every connection opens with a call that goes without
stdin: the full probe of `rules/first-detection.md` →
On first connection, step 1, or on a known host the
short one On subsequent connections below names.
`ssh` joins the quoted pieces with spaces into one
command line. In local mode, run the same commands
without `ssh`. Going without stdin, it types nothing
into a menu. Because the login shell is not always
sh, every later call goes through the bundle from
`rules/ssh-connections.md` → Bundle commands:
`sh -s`, whatever `Shell:` records, or the one the
Windows file names.

Keep its shape: single quotes, so the local shell
does not expand `$$`; no redirects, `&&` or `$(…)`,
because the account's login shell runs it and that
is not always sh — csh and tcsh are common on
FreeBSD and the firewalls built on it; and `ps`
not last, because bash and dash exec the last
command of `-c` in place and `ps` would then report
itself. Every OS lacks some of these commands, so
expect "not found" errors: read what the commands
that exist printed, and nothing else. An error line
can turn up under any `@` marker, because ssh passes
stdout and stderr on separately; never read it as
belonging to the section it lands in.

**The first line decides whether to go on.** If it
is anything but `Linux`, `FreeBSD` or `Darwin` — a
menu, a banner, "This account is currently not
available" — the account has no command shell. Stop
and show the user the output. Never answer a menu
over SSH: the same menus reboot the machine or reset
it to factory defaults.

One exception: when no line reads `Linux`,
`FreeBSD` or `Darwin` and the reply holds an error
that names `uname` as a command the shell could not
find — in whatever language the host speaks — a
shell ran the line and knows no `uname`. That is
how `cmd.exe` and PowerShell answer; PowerShell
also runs the rest, so a bare hostname can come
first. Go on with Windows below.

A first line that starts with `MINGW`, `MSYS_NT` or
`CYGWIN_NT` is a POSIX layer — Git Bash, MSYS2,
Cygwin — that Windows OpenSSH starts as its default
shell. Go on with Windows too, but skip `cmd /c ver`,
whose `/c` such shells may rewrite as a path, and
run the PowerShell probe directly.

## Windows

When the first call ends in the `uname` error, the second
call asks cmd.exe, which every Windows host has
whatever its SSH default shell is:

```
ssh … <host> 'cmd /c ver'
```

A line naming Windows and a version number means
Windows; Microsoft does not document the exact
format, so read it for those two things only.
Anything else: stop and show the user both replies.

Then read `rules/os/windows.md` and run its Version
Detection probe through PowerShell as its Reaching
PowerShell section describes.

**`ProductType` decides whether to go on.** `2` is a
domain controller and `3` a server: carry on. `1` is
a Windows client, which is no managed target: say so,
name the alternative — Hostwarden runs on a Windows
client in WSL 2
(`https://hostwarden.github.io/docs/getting-started/install#windows`)
— and stop. Record nothing.

Windows has no appliance or platform markers: steps 3
and 4 of `rules/first-detection.md` → On first
connection do not apply.

## Layers

Later wins, and each layer is read against the result
of the ones before it:

1. the family file (`rules/os/`);
2. the appliance file (`rules/appliance/`);
3. the platform file (`rules/platform/`);
4. the role file (`rules/role/`);
5. the user's overrides, in the order
   `rules/overrides.md` → Precedence gives.

An appliance file is read on top of the family file
its `Base:` line names, the way an override is read
(`rules/overrides.md` → The format): `## Replace:` and
`## Remove:` take a section of the base out, `## Add:`
and a heading without a prefix add to it, and a
section the appliance file does not name applies as
the base wrote it. `Base: none` means no family file
at all. A platform file has no `Base:` line. It
applies on top of whatever family detection found,
and on top of an appliance file if there is one, with
the same prefixes, so a `Replace:` or `Remove:` names
a section every family file has.

Where the appliance file's Version Detection names the
releases it covers and says to stop on the others,
stop on such a release: tell the user that Hostwarden
has no rules for it, and change nothing on the host.

Where the appliance file lists settings only its web
UI shows, ask the user for them once, record the
answers in machine memory with the date, and name a
setting as unchecked when its record is older than
three months.

**The family file with the appliance and platform
files applied is the OS file.** Wherever an
instruction names the loaded OS file or
`rules/os/<family>.md`, it means that. A role file is
not part of it: it changes no command, only what is
expected and how a finding is rated, and it names
each rule, expectation or check it changes. What it
does not name applies as written.

The `## Housekeeping and Audits` section of the
family, appliance, platform and role file applies to
housekeeping and both audits: it adds checks, changes
the command of those it names, skips those it
excludes and rates some differently. A family file
whose commands are not `sh` (Windows) holds its checks
there in full, and the skills' baseline references do
not run on it.

## On subsequent connections

Subsequent connections run the same pipeline as the
first (see `rules/first-connection.md`), including
the blacklist and read-only checks. Specific to
known servers: read the memory file, the changelog
as `rules/changelog.md` → Reading it says, and
`todo.md` (if present) before any work, read the
family file and the files that `Appliance:`,
`Platform:` and `Role:` name.
Shell and hardware come from memory. The first call
still goes without stdin, in the shape The first call
above gives: `uname -s`, then the version command
from the OS file's Version Detection section and, for
an appliance, its own, then `echo @platform;
cat /proc/version`. Its first line decides as The
first call says. On Windows the first call is
`cmd /c ver`, read as in Windows above — or, where
memory records a POSIX layer as the shell, `uname -s`
read as The first call says; the second is the
Version Detection probe of `rules/os/windows.md`
without its hardware part, in the activity check's
call (`rules/activity-check.md` → What rides in this
call), and its `ProductType` decides as above.
Update memory if a version changed.

The rest is read from `rules/first-detection.md`, one
section at a time and only when a line needs it:
settle the platform (Platforms) when the `@platform`
lines and `Platform:` disagree, and the role (Roles)
when memory has no `Role:` line. When memory has no
`Virtualization:` line or no `Arch:` line, the first
call also carries the `@virt` lines of the full
probe, and for a missing `Arch:` the `model name` and
`hw.model` lines of `@hardware` that name the maker;
on Windows the second call carries its `@hardware`
part, which holds both. Virtualization and step 2 of
On first connection settle them. If a command fails
or the OS no longer matches memory, run On first
connection from step 1.

That is a **full re-probe**, and the user can ask for
one on a known host (`hostwarden-onboard`). A guest
whose memory has `SSH: untested` gets one on its first
own connection, in place of the short first call
(`rules/first-connection.md` step 9). It
rewrites the lines detection owns
(`rules/machine-memory.md` → Who writes which line:
this file's, `rules/first-detection.md`'s, and those
a Version Detection section names) and `FQDN:`
(`rules/dns-aliases.md` → The FQDN) where the probe
reads something else, and says each difference in one
line: `OS: Debian 12 in memory, Debian 13 now`. Every
other line stays. One the user asked for also runs
the full network profile (`rules/network.md` → When)
and, on a hypervisor, the full inventory
(`rules/hypervisors.md` → Inventory).
