# Mandatory Access Control — Linux

Whether the module the host's Mandatory Access Control section
names, across its family and appliance files, is enabled and
enforcing (`rules/baseline.md` → Mandatory Access Control). Where
no loaded file has that section, the line reads
`MAC  n/a (<family>)`; in a container, `n/a (container)`
(`rules/system-containers.md` → What the Host Owns); under WSL,
`n/a (WSL)` (`rules/platform/wsl.md` → Housekeeping and Audits).
On macOS the line reports SIP from
`references/macos-security.md`: `MAC  OK — SIP enabled`.

## Probe

It goes into the same call as `references/kernel-os.md`; the
`aa-status` line counts profiles only as root, and the closing
`true` keeps a host without AppArmor from failing the call:

```bash
cat /sys/kernel/security/lsm 2>/dev/null; echo
getenforce 2>/dev/null
grep -E '^SELINUX=' /etc/selinux/config 2>/dev/null
cat /sys/module/apparmor/parameters/enabled 2>/dev/null
grep -oE '(selinux|enforcing|apparmor|security|lsm)=[^ ]*' /proc/cmdline
[ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = Y ] \
  && aa-status 2>&1 | grep -E 'profiles are (loaded|in enforce|in complain)'
true
```

`/sys/kernel/security/lsm` lists the modules the kernel runs;
`selinux=0`, `apparmor=0` or a `lsm=` list without the module on
the kernel command line explains one that is missing from it.
Where the section names more than one module, judge the one the
module list shows; none of them there → **WARN** "No mandatory
access control".

## SELinux

- `getenforce` prints `Enforcing` → OK.
- `Permissive` → **INFO** "SELinux permissive: denials are logged,
  not enforced". The log still shows what would be blocked, and
  permissive is often chosen on purpose.
- `Disabled`, or `selinux` missing from the module list →
  **WARN** "SELinux disabled", with the kernel parameter that
  disabled it where `/proc/cmdline` names one.
- `SELINUX=` in `/etc/selinux/config` differing from the runtime
  mode → add "`<value>` after the next reboot" to the line, as
  **INFO** where the runtime mode is enforcing.
- Without `getenforce` (`libselinux-utils` not installed), judge by
  the module list and the config line, and say so.

## AppArmor

- `enabled` reads `Y`, `apparmor` is in the module list and
  `aa-status` counts profiles in enforce mode → OK, with the
  counts: `OK — 52 enforce, 4 complain`.
- `enabled` reads `N`, or `apparmor` is missing from the module
  list → **WARN** "AppArmor disabled".
- Enabled with no profile loaded → **INFO** "AppArmor enabled, no
  profile loaded": nothing was turned off. On Debian that is the
  `apparmor` package missing from an install without recommends
  (`rules/os/debian.md` → Mandatory Access Control).
- Profiles loaded, none in enforce mode → **INFO** "AppArmor
  profiles in complain mode only: denials are logged, not
  enforced".
- Without root, report the enabled state alone and list the
  counts under Skipped (`references/unprivileged.md`).
