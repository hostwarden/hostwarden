# Windows Server

Rules for Windows Server reached through its OpenSSH server.

**Every Windows host is in read-only mode**
(`rules/access-control.md` → Read-Only Servers), whatever
`memory/readonly.md` says: announce it with this file as the
reason. Hostwarden reads and reports here; its journal line
(Logs below) is the only thing it writes.

Only a server is a target; `rules/os-detection.md` → Windows
stops at a client. Local mode never reaches Windows: on a
Windows machine the local machine is the WSL instance
(`rules/platform/wsl.md`).

## Reaching PowerShell

OpenSSH on Windows starts `cmd.exe` unless the registry value
`DefaultShell` under `HKLM:\SOFTWARE\OpenSSH` names another
shell. Hostwarden never depends on it: every call after
detection starts PowerShell 7 itself and feeds it the commands
on stdin, whatever the default shell is:

```
ssh … <host> 'pwsh -NoProfile -NonInteractive -Command -' <<'EOS'
<PowerShell lines>
EOS
```

This is the Windows form of the `sh -s` bundle
(`rules/ssh-connections.md` → Bundle commands). **Every
PowerShell block in this file is the stdin of that call.** Join
the blocks a task needs into one call, each behind its own
marker line (`'@firewall'`), and keep the shape:

- **One statement per line.** PowerShell reads stdin one
  statement at a time, as if typed at a prompt, and skips a
  statement that does not parse. Join statements with `;`,
  and close a `{ … }` block on the line that opens it.
- **The exit status says little.** It is 0 or 1, from the last
  statement only. Errors go to stderr, which SSH delivers apart
  from stdout, so an error line can land under any marker and
  names no step. Where a step's failure must be told apart,
  wrap it on its line as
  `try { <step> -ErrorAction Stop } catch { "failed: $_" }`,
  which puts the error on stdout after its marker. A missing
  marker, or a `failed:` line after it, is a failed step; a
  marker followed by nothing is a query that found nothing. A
  cmdlet that does not exist fails its own statement and the
  next one still runs.
- **No PowerShell remoting.** Its SSH transport needs a
  `Subsystem` line in `sshd_config`, which is never changed
  (`AGENTS.md` → Critical Safety Rules).

When `pwsh` is not recognized, PowerShell 7 is missing or not
on `PATH`. The MSI installs it to
`C:\Program Files\PowerShell\7\pwsh.exe`; where that file
exists, call it by that path — from cmd.exe as
`'"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile …'`, and
where `DefaultShell` is PowerShell with the call operator,
`'& "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile …'`.
Where it does not, Windows PowerShell 5.1 (`powershell`, same
flags) runs the detection probe and nothing after it: tell the
user that Hostwarden needs PowerShell 7 on this host, installed
from Microsoft's MSI to the fixed path above, and stop. Name the
release through `rules/version-check.md`, and whether it still
ships an MSI from the install page that procedure cites; a
release without one installs an MSIX package, whose path
changes with every version.

## Version Detection

The detection probe, and on later connections the call after
`cmd /c ver`:

```powershell
'@os'
try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; $os.Caption; $os.Version; $os.ProductType; $os.LastBootUpTime } catch { "failed: $_" }
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').InstallationType
'@shell'
$PSVersionTable.PSVersion.ToString()
(Get-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -ErrorAction SilentlyContinue).DefaultShell
'@admin'
whoami
(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
'@hardware'
try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop; (Get-CimInstance Win32_Processor -ErrorAction Stop).Name; $cs.NumberOfLogicalProcessors; [math]::Round($cs.TotalPhysicalMemory / 1GB) } catch { "failed: $_" }
try { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | Format-Table DeviceID, Size, FreeSpace } catch { "failed: $_" }
```

`@hardware` runs on the first connection only.

- `Caption` is the product name and can be localized; record
  it as it is. `Version` is `10.0.<build>`: Server 2016 is
  build 14393, 2019 is 17763, 2022 is 20348, 2025 is 26100
  ([release information](https://learn.microsoft.com/windows/release-health/windows-server-release-info)).
- `ProductType` decides as `rules/os-detection.md` → Windows
  says.
- `InstallationType` is `Server Core` on Server Core.

Record, besides the usual fields: `OS: <Caption> (build
<build>)`, `Installation: Server Core` or `Desktop Experience`,
`PowerShell: <version>`, `Shell: cmd (<user>)` or the program
`DefaultShell` names, and the `Admin:` line from Privileges
below.

## Privileges

Windows has no sudo, and an administrator's SSH session is
already elevated: no UAC prompt. Windows' own `sudo` does not
work over SSH
([microsoft/sudo#121](https://github.com/microsoft/sudo/issues/121)).
The `@admin` lines answer the question: `True` means the
account is an elevated administrator. Record it next to the
account `whoami` printed:

```
- Admin: yes (example\alice)
```

`False` records `- Admin: no (<account>)` and enters
unprivileged mode. There is no root SSH fallback: never try
`Administrator` or another account on your own
(`rules/ssh-user.md`). On later connections read the `Admin:`
line from memory.

## Package Manager

- **Windows Update** carries the OS and its components. It
  has no cmdlet that lists pending updates; Automatic Security
  Updates below reads it through its COM API.
- **winget** exists only on Windows Server 2025 with Desktop
  Experience — not on Server Core, not on Server 2022 or
  earlier — and only once someone has signed in to the desktop
  once. Over SSH it can fail to reach its source
  ([winget-cli#5579](https://github.com/microsoft/winget-cli/issues/5579)),
  and as SYSTEM it misses upgrades a user session finds
  ([winget-cli#4332](https://github.com/microsoft/winget-cli/issues/4332)).
  List upgrades only, and let a prompt fail rather than hang:

  ```powershell
  winget upgrade --disable-interactivity
  ```

  Never pass `--accept-source-agreements` or
  `--accept-package-agreements`: accepting terms is the
  user's. A failure is reported as `winget: not usable over
  SSH`, not as a finding.
- **Chocolatey, Scoop and other third-party managers** are
  out of scope. Report that one is installed; never run it.

## Firewall

Windows Defender Firewall has three profiles — Domain, Private,
Public. Read the policy in effect, which merges local settings
and Group Policy:

```powershell
try { Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop | Format-Table Name, Enabled, DefaultInboundAction, DefaultOutboundAction } catch { "failed: $_" }
try { Get-NetConnectionProfile -ErrorAction Stop | Format-Table InterfaceAlias, NetworkCategory } catch { "failed: $_" }
try { $r = @(Get-NetFirewallRule -ErrorAction Stop | Where-Object Name -eq 'OpenSSH-Server-In-TCP'); "sshrule: $($r.Count)"; $r | Format-Table Name, Enabled, Profile, Action } catch { "failed: $_" }
```

- Without `-PolicyStore ActiveStore` the cmdlet reads the local
  store only and misses what Group Policy sets.
- The profile a network card uses is its `NetworkCategory`;
  judge that profile first. A profile that is **disabled**, or
  whose `DefaultInboundAction` is `Allow`, is a **WARN**.
  `NotConfigured` falls back to the built-in default, which is
  `Block`
  ([Intune firewall settings](https://learn.microsoft.com/intune/device-configuration/endpoint-security/ref-firewall-settings#windows-firewall-profile)):
  rate it as `Block` and report it as `NotConfigured (Block)`.
- `OpenSSH-Server-In-TCP` is the rule OpenSSH's installation
  creates for port 22. `sshrule: 0` means it is missing. Missing
  or disabled while SSH works
  means another rule lets it in, or the profile is off: name
  which.

## Automatic Security Updates

Policy lives in `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`
and its `AU` subkey
([Windows Update settings](https://learn.microsoft.com/windows/deployment/update/waas-wu-settings)):

```powershell
try { $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; if (Test-Path $k) { Get-ItemProperty $k -ErrorAction Stop | Format-List WUServer } else { 'no WindowsUpdate key' } } catch { "failed: $_" }
try { $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; if (Test-Path $k) { Get-ItemProperty $k -ErrorAction Stop | Format-List NoAutoUpdate, AUOptions, UseWUServer, ScheduledInstallDay, ScheduledInstallTime } else { 'no AU key' } } catch { "failed: $_" }
try { Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 5 | Format-Table HotFixID, Description, InstalledOn } catch { "failed: $_" }
```

| Policy                                 | Rating                        |
| -------------------------------------- | ----------------------------- |
| `NoAutoUpdate` = 1                     | **WARN** — turned off         |
| `AUOptions` = 4                        | OK — installs on a schedule   |
| `AUOptions` = 2, 3 or 7                | **WARN** — waits for an admin |
| `AUOptions` = 5                        | **WARN** — local admin picks  |
| `UseWUServer` = 1                      | **INFO** — name `WUServer`    |
| no `AU` key                            | **WARN** — no policy set      |

`UseWUServer` means WSUS or a similar service decides what
installs; its own settings are not visible from the host.
`Get-HotFix` shows only updates from Component Based Servicing;
an MSI-installed update is not in it.

Pending updates come from the Windows Update Agent's search,
which contacts Windows Update or the WSUS server and can take
minutes. Run it in a call of its own, after the rest of the
report is in:

```powershell
try { (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0').Updates | ForEach-Object { $_.Title }; '@done' } catch { "failed: $_" }
```

`@done` prints only after a search that succeeded; a `failed:`
line, or no `@done` at all because it timed out, means the
list was not read — report it that way. The API documents its download
and install calls as refused from a remote computer; whether an
SSH session counts is untested, and Hostwarden never installs.

## Service Manager

`Get-Service`, or `Get-CimInstance Win32_Service` for the start
mode and the last exit code. A service with `StartMode` `Auto`
that is not `Running` is the Windows form of a failed unit:

```powershell
try { $v = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction Stop); "stopped: $($v.Count)"; $v | Format-Table Name, State, ExitCode, DelayedAutoStart } catch { "failed: $_" }
```

Rate each stopped service by what it is, never by its exit
code:

- A service `memory.md` lists: **CRITICAL**.
- A trigger-start service stops by design when it has no work.
  `sc.exe qtriggerinfo <name>` shows its triggers; one with a
  start trigger is **INFO**.
- `DelayedAutoStart` `True` within minutes of the last boot is
  **INFO**: it may not have started yet.
- Every other stopped automatic service: **WARN**, with its
  exit code.

## Defender

```powershell
try { Get-MpComputerStatus -ErrorAction Stop | Format-List AMServiceEnabled, AMRunningMode, AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, AntivirusSignatureAge, QuickScanAge } catch { "failed: $_" }
```

- `AMRunningMode` other than `Normal` means another product is
  the primary antivirus. Name it if the user knows; it is not
  a finding by itself.
- `RealTimeProtectionEnabled` `False` in normal mode is a
  **WARN**. Signatures older than 7 days are a **WARN**.
- A `failed:` line means Defender is not installed, not
  running, or not readable by this account: report that as it
  is.

## BitLocker

BitLocker is not installed on Windows Server by default. Where
the feature is missing the cmdlet does not exist, and the
`failed:` line says it is not recognized — an answer, not a
failure; any other `failed:` line is a check that did not run:

```powershell
try { Get-BitLockerVolume -ErrorAction Stop | Format-Table MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage } catch { "failed: $_" }
```

Report the state. An unencrypted server disk is **INFO**: many
servers sit in data centres where the physical risk is
someone else's. Recovery keys are secrets (`rules/secrets.md`):
never read `KeyProtector` values into the conversation.

## Local Administrators

```powershell
try { Get-LocalGroupMember -SID S-1-5-32-544 -ErrorAction Stop | Format-Table Name, ObjectClass, PrincipalSource } catch { "failed: $_" }
```

- Use the SID, never the name `Administrators`: the name is
  localized.
- The module works natively in PowerShell 7 on Windows
  Server 2019 and later, but not in a 32-bit PowerShell on a
  64-bit system.
- A domain controller has no local accounts of its own. If
  the cmdlet fails there, report local administrators as not
  applicable; the domain's groups are outside this check.

## Pending Reboot

Windows has no single flag. Three registry locations, listed
by Microsoft's own scripting blog rather than in reference
documentation, are the usual signal:

```powershell
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
try { $null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction Stop).PendingFileRenameOperations } catch { "failed: $_" }
```

Any `True` is a pending reboot: **WARN**, with the last boot
time from Version Detection.

## Logs

The journal is the Application event log, under the source
`hostwarden`. Heinzel never ran on Windows, so there is no
second tag to read.

**Write** (`rules/changelog.md`), one event per headline:

```powershell
eventcreate /l APPLICATION /so hostwarden /t INFORMATION /id 1 /d '[alice as alice] read-only: checked firewall and pending updates'; if ($LASTEXITCODE -eq 0) { 'logged' } else { "failed: eventcreate exit $LASTEXITCODE" }
```

The headline goes in single quotes; write an apostrophe in it
twice (`don''t`).

`eventcreate` is documented as an administrator's tool and
registers the source the first time it is used. In a session
without administrator rights expect the write to fail. `logged`
means the event was written; `failed:` means it was not, and the
headline goes to the local changelog only.

**Read back** (`rules/activity-check.md`):

```powershell
try { $null = Get-WinEvent -LogName Application -MaxEvents 1 -ErrorAction Stop; $e = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'hostwarden'; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue); "entries: $($e.Count)"; $e | Format-List TimeCreated, Message } catch { "failed: $_" }
```

The `entries:` line is the proof the check ran; `failed:`, or
no line at all, means it did not. `Get-WinEvent` reports an
error, not an empty result, when its filter matches nothing,
and the same error when access is denied
([PowerShell#18965](https://github.com/PowerShell/PowerShell/issues/18965)).
So the first statement proves the log can be read, with one
event and an error that stops the line; after that, the
filtered query's error can only mean no match, and is silenced.
The event-log engine does the filtering, which keeps the check
fast on a busy log. A non-administrator may need membership in
`Event Log Reader`.

The session register (`rules/parallel-sessions.md`) is not
read: in read-only mode no session registers.

System errors of the last day, the Windows counterpart of the
journal's priority filter:

```powershell
try { $null = Get-WinEvent -LogName System -MaxEvents 1 -ErrorAction Stop; $s = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) } -ErrorAction SilentlyContinue); "errors: $($s.Count)"; $s | Group-Object ProviderName | Sort-Object Count -Descending | Format-Table Count, Name } catch { "failed: $_" }
```

It works like the read-back: an empty result prints
`errors: 0`, and a denied read prints `failed:`.

## Directory Conventions

- Programs: `C:\Program Files\`, 32-bit ones in
  `C:\Program Files (x86)\`.
- Machine-wide data and configuration: `C:\ProgramData\`
  (`$env:ProgramData`). OpenSSH keeps its configuration and
  host keys in `C:\ProgramData\ssh\`.
- Configuration of the OS and most services: the registry,
  `HKLM:\SOFTWARE` and `HKLM:\SYSTEM`.
- Logs: the event logs (`Get-WinEvent -ListLog *`), plus
  per-product files under `C:\ProgramData\` or
  `C:\Windows\Logs\`.
- User profiles: `C:\Users\`.

## Notes

- **Accounts.** There is no `root`. A domain account logs in
  as `domain\user`; OpenSSH resolves it in that form. A POSIX
  shell eats the backslash in `domain\user@host`, so pass it
  quoted as its own option, `ssh -l 'domain\user' … <host>`,
  with the standard options. Keys of
  members of Administrators are read from
  `C:\ProgramData\ssh\administrators_authorized_keys`, not from
  the user's profile.
- **Files under `C:\ProgramData\ssh\`.** `sshd_config` and the
  key files there fall under the taboo list and its probing
  rule (`AGENTS.md` → Critical Safety Rules): probe them in an
  SSH call of their own, never inside a PowerShell bundle.
  `type` is for `sshd_config`, the `.pub` files and
  `administrators_authorized_keys` only. A private host key
  (`ssh_host_*_key` without `.pub`) is a secret
  (`rules/secrets.md`): look at it only with `dir` or
  `icacls`, and take its fingerprint from its `.pub` file.
- **Windows Server 2025** has the OpenSSH server installed by
  default; earlier versions add it as a capability. Membership
  in the local group `OpenSSH Users` can be what lets an
  account log in.

## Common Pitfalls

- **Localized names.** `Caption`, group names and event
  messages follow the system language. Match on SIDs, numbers
  and property names, never on display text.
- **Halting.** `Stop-Computer` and `shutdown /s` power the
  server off (`AGENTS.md` → Critical Safety Rules).
- **Profiles.** `-NoProfile` keeps an admin's profile script
  out of every call; never drop it.
- **Paths in single quotes.** Inside the bundle, write a path
  with spaces or `$` in single quotes; a double-quoted `$`
  expands.
