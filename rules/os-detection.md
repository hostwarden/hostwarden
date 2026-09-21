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

1. **Determine the OS, the login shell and the
   architecture:**
   ```
   ssh … <host> 'uname -s; ps -o comm= -p $$; uname -m'
   ```
   Send it exactly like this: single quotes, so the
   local shell does not expand `$$`; no pipes,
   redirects or `&&`; and `ps` not last, because bash
   and dash exec the last command of `-c` in place and
   `ps` would then report itself. The account's login
   shell runs it, and that is not always sh: csh and
   tcsh are common on FreeBSD and the firewalls built
   on it.

   If the first line is anything but `Linux`, `FreeBSD`
   or `Darwin` — a menu, a banner, "This account is
   currently not available" — the account has no
   command shell. Stop and show the user the output.
   Never answer a menu over SSH: the same menus reboot
   the machine or reset it to factory defaults.

   The second line is the shell (compare its basename;
   macOS may print `-zsh` or a path). Record it per SSH
   user in server memory (`Shell: csh (root)`). Unless
   it is `sh`, `bash`, `dash`, `ash`, `ksh` or `zsh`,
   every command with sh syntax (`2>/dev/null`, `$(…)`,
   `VAR=x cmd`, `[ … ]`) goes through the `sh -s`
   bundle from `rules/ssh-connections.md` → Bundle
   commands, for the whole session — the activity check
   and the sudo probe included. That also covers an
   error in place of the second line (fish rejects
   `$$`, busybox `ps` may reject `-p`): record
   `Shell: unknown` and wrap.

2. **If Linux** — detect distro and version:
   ```
   . /etc/os-release && \
     echo "${ID}|${VERSION_ID}|${PRETTY_NAME}"
   ```
   Distro families: `debian`, `rhel`, `suse`.
   Map the distro to a family via the os-release
   `ID` and `ID_LIKE` fields (e.g. `ubuntu` →
   `debian`; `centos`, `rocky`, `alma`, `fedora` →
   `rhel`; `opensuse*` variants → `suse`). `ID=haos`,
   and `ID=alpine` inside a Home Assistant app
   container, have no family: see Appliances below. If
   no family file matches (e.g. Alpine, Arch), tell
   the user, proceed cautiously with generic
   commands, and apply extra verify-before-running
   care.
   Read `rules/os/<family>.md`. Gather hardware info
   (`lscpu`, `free -h`, `df -h`).

3. **If macOS** — detect version and arch:
   ```
   sw_vers -productVersion
   ```
   Read `rules/os/macos.md`. Gather hardware info
   (`sysctl` for CPU/RAM, `df -h`).

4. **If FreeBSD** — detect version and arch:
   ```
   freebsd-version
   ```
   Read `rules/os/freebsd.md`. Gather hardware info
   (`sysctl` for CPU/RAM, `df -h`,
   `zpool status` if ZFS).

5. **Check for an appliance.** See Appliances below.

6. Create a server memory file.

## Appliances

An appliance is a product whose vendor runs the OS
underneath: its own updater, its own configuration
model, its own firewall. The family file's rules for
changing the system are then partly wrong, and a file
in `rules/appliance/` says which. A service that merely
runs on a host — Docker, a database, a web server — is
not one.

Probe the markers in the same call as step 2 or 4:

- Linux: `command -v pveversion ha;
  echo "${SUPERVISOR_TOKEN:+supervisor}"` (prints only
  whether the token is set, never the token)
- FreeBSD: `which opnsense-version pfSense-upgrade`

| Base    | Marker                          | Appliance file                  |
| ------- | ------------------------------- | ------------------------------- |
| Debian  | `pveversion`                    | `rules/appliance/proxmox-ve.md` |
| FreeBSD | `opnsense-version`              | `rules/appliance/opnsense.md`   |
| FreeBSD | `pfSense-upgrade`               | `rules/appliance/pfsense.md`    |
| none    | `ID=haos`, or `ha` + Supervisor | `rules/appliance/haos.md`       |

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
`## Housekeeping and Audits` section replaces the
baseline checks of housekeeping and both audits that
it names, and its `## Logs` section, where it has one,
replaces the activity check's block for the base
family.

## On subsequent connections

Subsequent connections run the same pipeline as the
first (see `rules/first-connection.md`), including
the blacklist and read-only checks. Specific to
known servers: read the memory file, changelog, and
`todo.md` (if present) before any work, read the
family file and the appliance file from `Appliance:`,
and verify the OS and appliance versions in one call
— update memory if either changed. Take the shell from
`Shell:` instead of probing it again.
