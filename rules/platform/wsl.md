# WSL

The Windows Subsystem for Linux: a Linux distribution that
Windows runs in a utility VM. The distribution's family file
applies to its packages and services. Windows owns the kernel,
the firewall, name resolution and the instance's lifetime.

## Detection

`rules/os-detection.md` → Platforms finds it. The same
`/proc/version` line tells the two apart:

- `microsoft-standard-WSL2` in it — WSL 2. Record
  `Platform: WSL 2`.
- `Microsoft` without it — WSL 1, which has no Linux kernel
  of its own, no netfilter and no systemd. Record
  `Platform: WSL 1`, tell the user that firewall and service
  checks cannot run there, and treat every such check as not
  applicable.

The role is inferred as `workstation` (`rules/os-detection.md`
→ Roles). An instance that runs long-lived services for others
is a server when the user says so.

The instance takes the Windows hostname unless `/etc/wsl.conf`
sets another, and every distribution on that Windows machine
shares it. `rules/server-memory.md` names the memory directory
for this case.

## Privileges

`wsl.exe -d <distribution> -u root`, run through Windows
interop from inside the instance, gives root without a
password. Hostwarden may use it the way it uses passwordless
sudo (`rules/privilege-escalation.md`). Always with `-d` and
the distribution from memory: without it, `wsl.exe` starts the
default distribution, which need not be this one.

## Replace: Firewall

Windows filters what reaches the instance: the Hyper-V
firewall on Windows 11 22H2 and later with WSL 2.0.9 or later,
the Windows Defender Firewall otherwise. Never install or
enable a firewall inside the instance. Report the firewall as
`Windows side, not checked` at **INFO**.

## Add: Automatic Security Updates

The distribution's updater applies as its family file says,
but it runs only while the instance is up. Windows stops an
idle instance, and a systemd service does not keep it alive.

## Add: Common Pitfalls

- **`df /` shows the virtual disk**, not free space on the
  Windows drive that holds it.
- **`wsl.exe --shutdown` and `wsl.exe --terminate` count as
  halting the machine** (`AGENTS.md` → Critical Safety Rules).
  `--shutdown` stops every distribution, including the one
  this session runs in.
- **`/mnt/c` and the other Windows drives** have no Unix
  permissions by default and are slow. Never treat a
  permission there as a finding.

## Housekeeping and Audits

- Disk usage is the virtual disk's; say so in the report.
- The firewall line comes from Replace: Firewall above.
