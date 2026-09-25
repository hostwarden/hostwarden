# WSL

The Windows Subsystem for Linux: a Linux distribution that
Windows runs in a utility VM. The distribution's family file
applies to its packages and services. Windows owns the kernel,
the firewall, name resolution and the instance's lifetime.
Hostwarden administers the distribution only; Windows is the
outside `rules/first-detection.md` → Platforms says is read,
never changed.

Source for everything below unless noted: Microsoft's WSL
documentation, <https://learn.microsoft.com/windows/wsl/>, and
for `wslinfo` the WSL source,
<https://github.com/microsoft/WSL/blob/master/src/linux/init/wslinfo.h>.

## Detection

The `/proc/version` line that found it tells WSL 1 and 2
apart:

- `microsoft-standard-WSL2` in it — WSL 2. Record
  `Platform: WSL 2`.
- `Microsoft` without it — WSL 1, which has no Linux kernel
  of its own, no netfilter and no systemd. Record
  `Platform: WSL 1`, tell the user that netfilter and systemd
  unit checks cannot run there, and treat those as not
  applicable. Services started by the distribution's init
  scripts or by hand are checked as the family file says.
  WSL 1 shares Windows' network stack, so the Windows
  Defender Firewall alone decides what reaches it: report the
  firewall as `Windows side, not checked` at **INFO**, naming
  each port that listens beyond loopback.

The role is inferred as `workstation` (`rules/first-detection.md`
→ Roles).

The instance takes the Windows hostname unless `/etc/wsl.conf`
sets another, and every distribution on that Windows machine
shares it. `rules/machine-memory.md` names the memory directory
for this case.

## Windows programs

The Windows drives are mounted under `/mnt/` unless `root`
under `[automount]` in `/etc/wsl.conf` names another
directory. Every `/mnt/` path in this file means that
directory.

This file calls `wsl.exe`, `powershell.exe` and `netsh.exe`
through interop, and `rules/machine-memory.md` calls
`hostname.exe`. `command -v <name>` finds each while the
Windows `PATH` is appended to the Linux one. Where
`appendWindowsPath=false` under `[interop]` keeps it out, call
them by their path on the Windows drive instead:
`/mnt/c/Windows/System32/wsl.exe`,
`/mnt/c/Windows/System32/netsh.exe`,
`/mnt/c/Windows/System32/hostname.exe`,
`/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe`.
Every name below stands for the path found this way.

## Privileges

`wsl.exe -d <distribution> -u root`, run through Windows
interop from inside the instance, gives root without a
password. Hostwarden may use it the way it uses passwordless
sudo (`rules/privilege-escalation.md` → Stand-ins for sudo).
Always with `-d` and the distribution from memory, the name
`rules/machine-memory.md` records for the memory directory:
without it, `wsl.exe` starts the default distribution, which
need not be this one.

Probe it once, when `rules/privilege-escalation.md` → Stand-ins
for sudo calls for a stand-in:

```
wsl.exe -d <distribution> -u root -e true && echo wslroot=ok
```

`wslroot=ok` → record `- WSL root: available` and run
privileged commands as
`wsl.exe -d <distribution> -u root -e sh -s`, with the
bundle on stdin as `rules/ssh-connections.md` → Bundle
commands describes. No `wslroot=ok` → record
`- WSL root: unavailable` with the error and go on as the
rule file says. Name no cause without having seen it: interop
may be off (`[interop] enabled=false` in `/etc/wsl.conf`),
`wsl.exe` may be missing, or a session that came in over SSH
may not reach Windows at all.

## Add: Version Detection

One call reads all four:

```
wslinfo --version; wslinfo --networking-mode; cat /proc/1/comm; uname -r
```

- The first line is the WSL package version. Releases before
  that option print an error there; send
  `wslinfo --wsl-version` instead.
- The second is `nat`, `mirrored`, `consomme`, `bridged` or
  `none`.
- The third is `systemd` when systemd runs, and `init` when
  WSL's own init does.
- The fourth, the kernel release, gives the generation: WSL 2
  runs a Linux kernel whose release ends in
  `-microsoft-standard-WSL2`; WSL 1 has none of its own and
  reports `…-Microsoft`. A custom WSL 2 kernel may carry
  neither; then the generation is `unknown`.

Record them next to the platform:
`Platform: WSL <1|2> (<version>, <networking mode>, <PID 1>)`.

## Add: Package Manager

The WSL kernel and WSL itself are no package of the
distribution: `linux-image-*` and its equivalents are not
installed, and a kernel update comes through WSL's own
updater on Windows. Report the WSL version. When an update
is due, it is the user's to run from Windows, and it takes
effect once every distribution has stopped (Common Pitfalls
below):

```powershell operator
wsl.exe --update
```

## Add: Service Manager

systemd runs only when `/etc/wsl.conf` has `systemd=true`
under `[boot]`. Ubuntu's image sets it; other distributions
often do not, and then `systemctl` fails and services start
through the distribution's own init scripts, if at all.
Check PID 1 (Version Detection above) before any
`systemctl` call.

Turning systemd on is an edit to `/etc/wsl.conf`
(`rules/backups.md` first), which takes effect with the next
restart of the distribution (Common Pitfalls below).

## Replace: Firewall

Windows filters what reaches the instance: the Hyper-V
firewall on Windows 11 22H2 and later with WSL 2.0.9 or later,
the Windows Defender Firewall otherwise. Never install or
enable a firewall inside the instance.

What reaches the instance depends on the networking mode
(Version Detection above):

- `nat` — the default. A port the instance listens on is
  reachable from Windows as `localhost:<port>` unless
  `.wslconfig` sets `localhostForwarding=false` under
  `[wsl2]`, and from nowhere else unless someone forwarded
  it with `netsh interface portproxy` on Windows.
- `mirrored` — the instance shares Windows' interfaces, and a
  port it listens on is reachable from the network as far as
  the Hyper-V firewall lets it through.
- `bridged` — the instance has an address of its own on the
  network.
- `none` — no network at all.

Each mode is rated as follows. A command that fails —
Windows 10, no Hyper-V firewall, a setting only an elevated
shell may read — makes the line `Windows side, not checked`
at **INFO**.

- `none` — **INFO**, nothing to read.
- `nat` — read the forwards Windows holds, read-only:

  ```
  netsh.exe interface portproxy show all
  ```

  Keep only the entries that lead into this instance: the
  connect address is one of `hostname -I`, and a process here
  listens on the connect port. Every distribution shares the
  VM's address, so the listening port is what ties an entry to
  this one. Drop too an entry whose listen address is
  `127.0.0.1` or `::1`: only Windows itself reaches it. None
  left → **INFO**. Any → list them at **WARN**:
  each is reachable from the network as far as the Windows
  Defender Firewall allows, which this does not read.
- `mirrored` and `bridged` — read the Hyper-V firewall's
  setting for WSL once:

  ```
  powershell.exe -NoProfile -Command "Get-NetFirewallHyperVVMSetting -PolicyStore ActiveStore -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'"
  ```

  The GUID is WSL's VM creator ID (Microsoft's Hyper-V
  firewall documentation). Report `Enabled` and
  `DefaultInboundAction`. With a port listening beyond
  loopback, `Enabled: False` or `DefaultInboundAction: Allow`
  is a **WARN**: `DefaultInboundAction` counts only while the
  firewall is enabled. Anything else is **INFO**.
- `consomme`, or anything else — report the mode, and the
  firewall as `Windows side, not checked`, at **INFO**.

## Add: Automatic Security Updates

The distribution's updater applies as its family file says,
but it runs only while the instance is up. Windows stops an
idle instance, and a systemd service does not keep it alive.

## Add: Directory Conventions

- `/etc/wsl.conf` — this distribution's WSL settings: boot,
  automount, network, interop, default user.
- `/etc/wsl-distribution.conf` — the distribution's own
  defaults, shipped with its image. Leave it alone.
- `%UserProfile%\.wslconfig` on Windows, reached as
  `/mnt/c/Users/<windows-user>/.wslconfig` — settings for
  every distribution and the VM: memory, processors, swap,
  networking mode, firewall.
- `/etc/resolv.conf` and `/etc/hosts` are written by WSL at
  every start unless `/etc/wsl.conf` turns that off
  (`generateResolvConf`, `generateHosts` under `[network]`).
  An edit to either is lost at the next start.

## Add: Common Pitfalls

- **`df /` shows the virtual disk**, not free space on the
  Windows drive that holds it. That drive is the one in the
  distribution's `BasePath`, which need not be C: after an
  import or a move:

  ```
  powershell.exe -NoProfile -Command "(Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | Get-ItemProperty | Where-Object DistributionName -eq '<distribution>').BasePath"
  ```

  `df -h /mnt/<letter>` then shows it, with the drive letter
  in lowercase. When the path cannot be read, report the
  virtual disk alone and say the Windows drive is unknown.
- **`free` shows the VM's share**, which `.wslconfig` sets,
  by default half of Windows' memory.
- **Restarting WSL is the user's.** `wsl.exe --shutdown`,
  `--terminate` and `--unregister` are taboos (`AGENTS.md` →
  Critical Safety Rules). `--shutdown` stops every
  distribution on the Windows machine, whatever runs in
  them, this session included; `--terminate` stops one;
  `--unregister` deletes one. Whatever
  needs a restart — a changed `/etc/wsl.conf`, a WSL update,
  a pending `reboot-required` — the user runs from Windows
  once this session is done:

  ```powershell operator
  wsl.exe --terminate <distribution>
  ```

- **`/mnt/c` and the other Windows drives** have no Unix
  permissions by default and are slow. Never treat a
  permission there as a finding.
- **The Windows `PATH` is appended to the Linux one** unless
  `appendWindowsPath=false` under `[interop]`. A command name
  can therefore resolve to a Windows program; `command -v`
  shows which one.
- **VPNs on Windows often break `nat` mode.** A host that
  Windows reaches and the instance does not is a WSL network
  problem, not a server that is down.

## Housekeeping and Audits

- **Disk and memory:** report both as Common Pitfalls
  describes, the Windows drive next to the virtual disk.
- **Reboot required:** there is no kernel to boot. A
  `reboot-required` flag means the distribution needs a
  restart; report it at **INFO** with the command from
  Common Pitfalls.
- **WSL version:** report it at **INFO**. Hostwarden does not
  judge whether it is current.
- **Security audit:**
  - Interop on, which it is by default, lets any process of
    the default user become root through
    `wsl.exe -u root`. Report it at **INFO**, with
    `[interop] enabled=false` as the way to close it, and
    that the change turns off `WSL root` for Hostwarden too.
  - sshd is usually not installed. When it is, the audit
    checks it as on any host, and the networking mode says
    who can reach it.
