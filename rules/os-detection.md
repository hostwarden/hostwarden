# OS Detection (mandatory first step)

Before doing any work on a server, you **must** know
its OS.

Detection is what makes `rules/os/` and
`rules/appliance/` reachable. Those files are not rules
that fire on a situation — they are reference data
addressed by a fact this procedure establishes.
Detection reads **at most one** family file — the family
it just established, and no other — and **at most one**
appliance file on top of it. A distribution no family
covers gets no family file; step 2 below says what to
do instead. Never reach for the nearest file — a Debian
reference on an Alpine host prescribes the wrong
package manager and the wrong firewall.

That cap is on detection, not on the session. A
workflow that deals with two operating systems at once
— an OS replacement, a dual-boot setup — reads the
file for each of them, old and new, because each is a
fact about a real system. The `hostwarden-os-install`
skill says so where it needs it.

## On first connection

0. **Check access control and DNS alias.** For remote
   servers: check blacklist, then read-only list
   (see `rules/access-control.md`), then DNS aliases
   (see `rules/dns-aliases.md`). If the hostname is
   an alias for a known server, skip OS detection.

1. **Probe everything in one call** — OS, login shell,
   architecture, version, hardware and appliance
   markers:
   ```
   ssh … <host> 'uname -s; ps -o comm= -p $$; uname -m;' \
     'echo @release; freebsd-version;' \
     'grep -E "^(ID|ID_LIKE|VERSION_ID|PRETTY_NAME)=" /etc/os-release;' \
     'sw_vers -productVersion; echo @hardware; df -h /;' \
     'nproc; grep -m1 "model name" /proc/cpuinfo; free -h;' \
     'sysctl hw.model hw.ncpu hw.physmem;' \
     'sysctl hw.memsize; echo @appliance;' \
     'which pveversion ha opnsense-version pfSense-upgrade;' \
     'which omv-confdbadm; ls -d /homeassistant; pveversion;' \
     'opnsense-version; cat /etc/version;' \
     'dpkg-query -W openmediavault'
   ```
   `ssh` joins the quoted pieces with spaces into one
   command line. In local mode, run the same commands
   without `ssh`.

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

   **The second line is the shell** (compare its
   basename; macOS may print `-zsh` or a path). Record
   it per SSH user in server memory (`Shell: csh
   (root)`). Because the login shell is not always sh,
   every later call goes through the `sh -s` bundle
   from `rules/ssh-connections.md` → Bundle commands,
   whatever the shell; only this probe goes without
   stdin, so nothing is ever typed into a menu. An
   error in place of the second line (busybox `ps` may
   reject `-p`) records `Shell: unknown`. A shell that
   rejects the whole line (fish rejects `$$`) does too,
   and then the probe goes again through `sh -s`.

2. **Map the OS to a family** from the lines after
   `@release`, and read `rules/os/<family>.md`:
   - **Linux:** the os-release `ID` and `ID_LIKE`
     fields (e.g. `ubuntu` → `debian`; `centos`,
     `rocky`, `alma`, `fedora` → `rhel`; `opensuse*`
     variants → `suse`); the version from `VERSION_ID`
     and `PRETTY_NAME`. `ID=haos`, and `ID=alpine`
     inside a Home Assistant app container, have no
     family: see Appliances below. If no family file
     matches (e.g. Alpine, Arch), tell the user,
     proceed cautiously with generic commands, and
     apply extra verify-before-running care.
   - **FreeBSD:** `freebsd`, version from the
     `freebsd-version` line.
   - **macOS:** `macos`, version from the `sw_vers`
     line.

   Hardware comes from the lines after `@hardware`:
   `nproc`, the CPU model and `free` on Linux, `sysctl`
   elsewhere.
   Add `zpool status` to the next call on a FreeBSD
   host with ZFS.

3. **Check for an appliance** from the lines after
   `@appliance`. See Appliances below. The same lines
   carry the version of Proxmox VE, OPNsense, pfSense
   and OpenMediaVault; any other appliance file says
   how to read its own.

4. Create a server memory file.

## Appliances

An appliance is a product whose vendor runs the OS
underneath: its own updater, its own configuration
model, its own firewall. The family file's rules for
changing the system are then partly wrong, and a file
in `rules/appliance/` says which. A service that merely
runs on a host — Docker, a database, a web server — is
not one.

The probe in step 1 reports the markers. `which`
prints a path for a command that exists; what it
prints for a missing one depends on the shell.

| Base    | Marker             | Appliance file                      |
| ------- | ------------------ | ----------------------------------- |
| Debian  | `pveversion`       | `rules/appliance/proxmox-ve.md`     |
| Debian  | `omv-confdbadm`    | `rules/appliance/openmediavault.md` |
| FreeBSD | `opnsense-version` | `rules/appliance/opnsense.md`       |
| FreeBSD | `pfSense-upgrade`  | `rules/appliance/pfsense.md`        |
| none    | `ID=haos`, `ha`    | `rules/appliance/haos.md`           |

`ha` counts only where `/homeassistant` exists too.
`ID=haos` means the probe reached the HAOS host
itself; its file says to stop there.

On a match, read the family file its `Base:` line
names, then the appliance file on top of it, the way
an override is read (`rules/overrides.md` → The
format): `## Replace:` and `## Remove:` take a section
of the base out, `## Add:` and a heading without a
prefix add to it, and a section the appliance file
does not name applies as the base wrote it.
`Base: none` means no family file at all. The user's
overrides of the family file come before those of the
appliance file. Record `Appliance: …` in server
memory, in the form the appliance file gives.

**On an appliance, the family file with the appliance
file applied is the OS file.** Wherever an instruction
names the loaded OS file or `rules/os/<family>.md`, it
means that. The appliance file's
`## Housekeeping and Audits` section adds checks for
housekeeping and both audits on top, and a baseline
it excludes is skipped.

## On subsequent connections

Subsequent connections run the same pipeline as the
first (see `rules/first-connection.md`), including
the blacklist and read-only checks. Specific to
known servers: read the memory file, changelog, and
`todo.md` (if present) before any work, read the
family file and the appliance file from `Appliance:`.
Shell and hardware come from memory. The first call
still goes without stdin, in the shape of step 1:
`uname -s`, then the version command from the OS
file's Version Detection section and, for an
appliance, its own. Its first line decides as in
step 1. Update memory if a version changed; if a
command fails or the OS no longer matches memory, run
the full probe from step 1.
