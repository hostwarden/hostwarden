# Windows Server

Rules for Windows Server reached through its OpenSSH server.

**Every Windows host is in read-only mode**
(`rules/access-control.md` → Read-Only Servers), whatever
`memory/readonly.md` says: announce it with this file as the
reason. Hostwarden reads and reports here. It writes its
journal line (Logs below) and, each only after the user's yes,
the two changes in Setting Up PowerShell 7 — nothing else.

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
user that Hostwarden needs PowerShell 7 on this host, and offer
the installation in Setting Up PowerShell 7 below. Without it,
stop.

## Setting Up PowerShell 7

Two changes, each asked for on its own, in this order. Both
need an administrator (`Admin: yes`). Windows has no session
register; `rules/parallel-sessions.md` → Hosts without a
register says what stands in for it.

### Install PowerShell 7

The install runs through Windows PowerShell 5.1, in the bundle
shape with `powershell` in place of `pwsh`. Ask first — *"Install
PowerShell <version> from Microsoft's MSI on <host>?"* — and
name what it adds: `pwsh.exe` under
`C:\Program Files\PowerShell\7\`, on the system `PATH`, updated
through Microsoft Update.

1. **Pick the release** through `rules/version-check.md`: the
   newest stable one whose GitHub release still ships
   `PowerShell-<version>-win-<arch>.msi`, `<arch>` being `x64`,
   or `arm64` where `$env:PROCESSOR_ARCHITECTURE` prints
   `ARM64`. From
   7.7 on there is no MSI, and the MSIX package that replaces it
   changes its path with every version; the fixed path is the
   reason for the MSI. Read the file's SHA-256 from the
   release's "SHA256 Hashes of the release artifacts" section
   on the workstation, never from the host.
2. **Download, check, install and verify** in one call:

   ```powershell
   $v = '<version>'; $a = '<arch>'; $sha = '<sha256>'; $f = Join-Path $env:TEMP "PowerShell-$v-win-$a-$PID.msi"; $ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
   try { Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$v/PowerShell-$v-win-$a.msi" -OutFile $f -ErrorAction Stop; if ((Get-FileHash $f).Hash -ne $sha) { throw 'hash mismatch, not installed' }; $c = (Start-Process msiexec.exe -ArgumentList '/package', "`"$f`"", '/quiet', 'ADD_PATH=1' -Wait -PassThru).ExitCode; "msiexec: $c"; if ($c -in 0, 3010) { "pwsh: $(& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()')" } } catch { "failed: $_" } finally { Remove-Item $f -ErrorAction SilentlyContinue }
   ```

   Hiding the progress bar keeps Windows PowerShell 5.1 from
   slowing a large download to a crawl. The `SecurityProtocol`
   line adds TLS 1.2 to what the session offers, which GitHub
   needs and older Windows PowerShell does not always offer by
   default
   ([Microsoft's form](https://learn.microsoft.com/powershell/gallery/powershellget/install-powershellget)).
   It only adds a protocol; never weaken certificate checks to
   get a download through.

   `msiexec: 0` is success; `3010` is success that waits for a
   restart — report it, and never restart
   ([MsiExec error codes](https://learn.microsoft.com/windows/win32/msi/error-codes)).
   Any other code, or a `failed:` line: report it and stop. The
   `pwsh:` line must print the version just installed.
3. **Record**: the journal line, the local changelog with the
   version, the hash and the exit code, and memory as Version
   Detection → Record lists.

### Set the default shell

Optional, and only after PowerShell 7 works. Hostwarden never
needs it; it makes an interactive login land in PowerShell 7
instead of `cmd.exe`. Ask separately, and say what it changes
for everyone: every SSH login and every command other tools
send over SSH to this host will run in PowerShell 7, so a
script that expects `cmd.exe` syntax breaks. The value goes to
the fixed MSI path only, never to an MSIX path.

A wrong default shell ends every SSH login, so the change runs
through `rules/ssh-safety-net.md`. Its commands here:

- **Back up** (its step 2), the key and the current value:

  ```powershell
  $d = 'C:\ProgramData\hostwarden\backups'; New-Item -ItemType Directory -Force $d | Out-Null; $b = "$d\OpenSSH-$(Get-Date -Format yyyyMMdd-HHmmss).reg"
  "previous: $((Get-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -ErrorAction SilentlyContinue).DefaultShell)"
  reg export 'HKLM\SOFTWARE\OpenSSH' $b /y; if ($LASTEXITCODE -eq 0) { "backup: $b" } else { 'failed: reg export' }
  Get-ChildItem $d -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-30) | Remove-Item
  ```

  An empty `previous:` means no value was set, and `cmd.exe`
  was the default. Stop unless `backup:` printed: without the
  `HKLM:\SOFTWARE\OpenSSH` key there is nothing to back up, and
  the change could not be set either.
- **Check** (step 3): `Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe'`
  prints `True`.
- **Revert**: set the previous value again, or remove
  `DefaultShell` where there was none.
- **Arm** (step 4): Windows has neither `systemd-run` nor `at`;
  a scheduled task run as SYSTEM five minutes from now stands
  in for them. The arm call reads the previous value itself —
  it runs before Apply — and hands the revert to the task
  encoded, so no value can break its quoting. First read
  whether a revert task is already there:

  ```powershell
  Get-ScheduledTask -TaskName 'hostwarden-revert' -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo | Format-List LastRunTime, NextRunTime
  ```

  A task whose `NextRunTime` lies ahead belongs to a session
  that is changing the default shell right now: stop, name it,
  and ask — the journal shows nothing of that session until it
  is done. A task that already ran is left from a revert that
  fired: report when, and remove it with the cancel block before
  arming. The arm call prints the revert command it armed
  (`revert:`) and `armed:`; without both, stop before Apply.

  ```powershell
  try { $prev = (Get-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -ErrorAction Stop).DefaultShell; $cmd = if ($prev) { "Set-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value '" + ($prev -replace "'", "''") + "'" } else { "Remove-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell" }; "revert: $cmd"; $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd)); $sys = (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18').Translate([System.Security.Principal.NTAccount]).Value; Register-ScheduledTask -TaskName 'hostwarden-revert' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -EncodedCommand $enc") -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5)) -Principal (New-ScheduledTaskPrincipal -UserId $sys -LogonType ServiceAccount -RunLevel Highest) -ErrorAction Stop | Out-Null; "armed: $((Get-ScheduledTask -TaskName 'hostwarden-revert' -ErrorAction Stop).State)" } catch { "failed: $_" }
  ```

- **Apply** (step 5), as Microsoft's example does:

  ```powershell
  try { New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value 'C:\Program Files\PowerShell\7\pwsh.exe' -PropertyType String -Force -ErrorAction Stop | Out-Null; 'set' } catch { "failed: $_" }
  ```

- **Test** (step 6): the fresh login runs
  `'$PSVersionTable.PSVersion.ToString()'` with no stdin; the
  version printed is the proof. Microsoft does not say whether a
  running `sshd` picks the value up at once. A login that works
  but still lands in `cmd.exe` has not tested the new value:
  leave the revert armed and let it fire, then report it. A
  restart of `sshd` needs the user's yes
  (`rules/service-reload.md`), and then the whole change runs
  again with `; Restart-Service sshd` added twice: to `$cmd`
  before it is encoded, so the revert brings the old shell back
  as well, and to the Apply line, so the new value takes effect
  before the fresh login tests it. The Apply call may end when
  `sshd` restarts; the fresh login is what counts.
- **Cancel** (step 7):

  ```powershell
  try { Unregister-ScheduledTask -TaskName 'hostwarden-revert' -Confirm:$false -ErrorAction Stop } catch { "failed: $_" }; if (Get-ScheduledTask -TaskName 'hostwarden-revert' -ErrorAction SilentlyContinue) { 'failed: still armed' } else { 'cancelled' }
  ```

- **Console** (step 8): if the host still does not answer
  after the revert, the user runs the revert command at the
  console; the backup path goes with it. A revert that fired
  leaves its task registered: once a fresh login works again,
  remove it with the cancel block.

**Record**: the journal line; the local changelog with the
backup path, a `Rollback:` line naming the previous value, and a
revert that fired; and memory as Version Detection → Record
lists.

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
below. After Setting Up PowerShell 7 changed the default shell,
also `DefaultShell: <path> (was <previous or unset>)`.

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
try { $o = $null; try { $o = Get-WinEvent -LogName Application -MaxEvents 1 -Oldest -ErrorAction Stop } catch { if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw } }; if ($o) { "oldest: $($o.TimeCreated.ToString('s'))" } else { 'oldest: none' }; $e = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'hostwarden'; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue); "entries: $($e.Count)"; $e | Format-List TimeCreated, Message } catch { "failed: $_" }
```

The `entries:` line is the proof the check ran; `failed:`, or
no line at all, means it did not. The `oldest:` line is how far
back the log reaches (`rules/activity-check.md` → How far back
it reached): the Application log is capped by size, and a busy
server or a cleared log can hold less than the seven days.
`Get-WinEvent` reports an
error, not an empty result, when its filter matches nothing,
and the same error when access is denied
([PowerShell#18965](https://github.com/PowerShell/PowerShell/issues/18965)).
So the first statement proves the log can be read, with its
oldest event and an error that stops the line; after that, the
filtered query's error can only mean no match, and is silenced.
Read by name, without a filter, the log tells the two apart: an
empty log raises `NoMatchingEventsFound`, a denied read another
error. So `oldest: none` is a readable, empty log — just
cleared — whose reach is nothing: read the local changelog for
the whole seven days.
The event-log engine does the filtering, which keeps the check
fast on a busy log. A non-administrator may need membership in
`Event Log Reader`.

Windows has no session register: the activity check reads
none, and `rules/parallel-sessions.md` → Hosts without a
register says what stands in for it before a change.

System errors of the last day, the Windows counterpart of the
journal's priority filter:

```powershell
try { $null = Get-WinEvent -LogName System -MaxEvents 1 -ErrorAction Stop; $s = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) } -ErrorAction SilentlyContinue); "errors: $($s.Count)"; $s | Group-Object ProviderName | Sort-Object Count -Descending | Format-Table Count, Name } catch { "failed: $_" }
```

It works like the read-back: an empty result prints
`errors: 0`, and a denied read prints `failed:`.

## Housekeeping and Audits

On Windows this section is the whole of housekeeping and the
security audit (`rules/os-detection.md` → Layers): the skills'
baseline references are written for `sh` and do not run here.
Every block is PowerShell for the bundle in Reaching PowerShell,
prints its result or a `failed:` line, and a `failed:` line is
a check that did not run, never a clean one. Nothing here
changes the host.

The fleet audit's probes are written for `sh`: it skips a
Windows host with a "Windows not yet supported" note.

### Housekeeping

Run two calls. The first holds every check below except the
slow ones. The second, after the first is read, holds the
pending-update search (Automatic Security Updates), the winget
listing (Package Manager) and the second load reading. Uptime
comes from `LastBootUpTime` in this session's Version Detection
call.

**Backup presence.** The generic probe in
`.agents/skills/hostwarden-housekeeping/references/backup-presence.md`
is written for `sh`; ask Windows Server Backup instead. It needs
an administrator. `wbadmin: not installed` means the feature is
missing — an answer, not a failure:

```powershell
if (Get-Command wbadmin -ErrorAction SilentlyContinue) { wbadmin get versions; if ($LASTEXITCODE -ne 0) { "failed: wbadmin exit $LASTEXITCODE" } } else { 'wbadmin: not installed' }
try { Get-Service -ErrorAction Stop | Where-Object { $_.Name -match 'backup|veeam|acronis|commvault|arcserve|bacula|restic|urbackup|cobian' -or $_.DisplayName -match 'backup' } | Format-Table Name, DisplayName, Status } catch { "failed: $_" }
try { Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -match 'backup' } | Format-Table TaskPath, TaskName, State } catch { "failed: $_" }
```

The second and third lines look for another backup product: a
service or a scheduled task that names one. Any match is a
mechanism to name and ask about, not an absence. Only when all
three find nothing is there no mechanism. Rate the result, and
ask the question it may lead to, as that
file's Step 0 and Severity sections say.

**Disk, memory and load:**

```powershell
try { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | ForEach-Object { '{0} {1:N0}% used of {2:N0} GB' -f $_.DeviceID, (100 - 100 * $_.FreeSpace / $_.Size), ($_.Size / 1GB) } } catch { "failed: $_" }
try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; '{0:N1} GB free of {1:N1} GB' -f ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB) } catch { "failed: $_" }
try { "load: $((Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object LoadPercentage -Average).Average)" } catch { "failed: $_" }
```

`LoadPercentage` is a moment's reading, not an average over
minutes; the second call reads it again with the `load:` line.

- A disk over 85% used: **WARN**; over 95%: **CRITICAL**.
- Free memory under 10% of total: **WARN**.
- Both load readings above 90%: **WARN**.

**Updates, reboot, firewall, services, Defender.** The blocks
of Automatic Security Updates, Pending Reboot, Firewall,
Service Manager and Defender above, rated as those sections
say. Pending updates are a **WARN**, with the count and the
titles; the search does not tell security updates apart.
winget's outdated packages are **INFO** with the count, and
winget failing over SSH is **INFO**, never a finding.

**System log.** The System-log block under Logs above, and
for each source over the threshold below, its newest error in
the same call, with the source name from the counts:

```powershell
try { Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = '<source>'; Level = 1, 2 } -MaxEvents 1 -ErrorAction Stop | Format-List TimeCreated, Id, Message } catch { "failed: $_" }
```

- A source with more than 10 errors in the day: **WARN**, with
  the newest message of that source.
- Otherwise **INFO** with the counts.

**Time sync:**

```powershell
w32tm /query /source; if ($LASTEXITCODE -ne 0) { "failed: w32tm exit $LASTEXITCODE" }
```

The source is a server name or address (`,0x…` may follow), `VM
IC Time Synchronization Provider` on a Hyper-V guest, or a local
clock. The local clocks — `Local CMOS Clock` and `Free-running
System Clock`, or their translation — mean the clock is not
synchronized: **WARN**. `w32tm` prints localized text, so judge
the value, not a label.

### Security Audit

**SSH.** `sshd -T` prints the effective configuration, as on
Linux. Run it and every probe of `C:\ProgramData\ssh\` in SSH
calls of their own, outside the PowerShell bundle (Notes
below):

```
ssh … <host> 'sshd -T'
```

Rate its output with
`.agents/skills/hostwarden-security/references/ssh.md`.
Then the key file for administrators:

```
ssh … <host> 'icacls C:\ProgramData\ssh\administrators_authorized_keys'
```

`icacls` prints account names, and they are localized. Resolve
the two that belong there in the PowerShell bundle, which names
no file:

```powershell
'S-1-5-32-544', 'S-1-5-18' | ForEach-Object { try { (New-Object System.Security.Principal.SecurityIdentifier $_).Translate([System.Security.Principal.NTAccount]).Value } catch { "failed: $_" } }
```

- Any other principal with write access — `(F)`, `(M)` or
  `(W)`: **CRITICAL** — whoever can write the file can log in as
  an administrator.
- Any other principal with read access only: **WARN** — sshd
  expects the file restricted to those two and may ignore it,
  so administrators' key logins can fail.
- The file missing while an administrator logs in with a key:
  report where the key came from as unknown, **INFO**.

**Firewall.** The Firewall block above, rated as it says, and
the enabled inbound allow rules of the policy in effect, Group
Policy included — name, profile, protocol, local port, remote and local
addresses:

```powershell
try { $r = @(Get-NetFirewallRule -PolicyStore ActiveStore -Direction Inbound -Enabled True -Action Allow -ErrorAction Stop); "rules: $($r.Count)"; $r | ForEach-Object { $pf = $_ | Get-NetFirewallPortFilter; $af = $_ | Get-NetFirewallAddressFilter; $app = ($_ | Get-NetFirewallApplicationFilter).Program; $svc = ($_ | Get-NetFirewallServiceFilter).Service; '{0} | {1} | {2} {3} | from {4} | to {5} | program {6} | service {7}' -f $_.DisplayName, $_.Profile, $pf.Protocol, $pf.LocalPort, ($af.RemoteAddress -join ','), ($af.LocalAddress -join ','), $app, $svc } } catch { "failed: $_" }
```

Judge only the rules of the profile in use (Firewall above). A
rule opens its ports only to its program and service where it
names one (`Any` means every program or service): a listener
on that port is exposed, to the remote addresses the rule
names, when every scope the rule names matches: the listener's
executable path is the rule's program where the rule names one,
and its bracket holds the rule's service where the rule names
one. A rule that names both reaches only that service inside
that program. A rule whose local addresses (`to`) are not `Any`
reaches only a listener bound to one of them or to a wildcard
address; a listener bound to another address is not exposed by
it. A listener whose path is empty cannot be matched to a
program-scoped rule: report it as unknown, not as covered. A
rule with a local port of `Any` opens every port to the program
or service it names: name the rule.

**Listening services**, TCP and UDP:

```powershell
try { $p = @{}; Get-Process -ErrorAction Stop | ForEach-Object { $p[$_.Id] = "$($_.ProcessName) $($_.Path)" }; $s = @{}; Get-CimInstance Win32_Service -Filter 'ProcessId > 0' -ErrorAction Stop | ForEach-Object { $s[[int]$_.ProcessId] = @($s[[int]$_.ProcessId]) + $_.Name }; 'processes and services read' } catch { "failed: $_" }
try { $l = @(Get-NetTCPConnection -State Listen -ErrorAction Stop); "tcp: $($l.Count)"; $l | Sort-Object LocalPort | ForEach-Object { '{0}:{1} {2} [{3}]' -f $_.LocalAddress, $_.LocalPort, $p[[int]$_.OwningProcess], ((@($s[[int]$_.OwningProcess]) | Where-Object { $_ }) -join ',') } } catch { "failed: $_" }
try { $u = @(Get-NetUDPEndpoint -ErrorAction Stop); "udp: $($u.Count)"; $u | Sort-Object LocalPort | ForEach-Object { '{0}:{1} {2} [{3}]' -f $_.LocalAddress, $_.LocalPort, $p[[int]$_.OwningProcess], ((@($s[[int]$_.OwningProcess]) | Where-Object { $_ }) -join ',') } } catch { "failed: $_" }
```

Each listener names its process, the executable's path, and in
brackets the services that process hosts — `svchost` carries
several. A path can be empty for a process this account may
not open.

Rate it as
`.agents/skills/hostwarden-security/references/listening-services.md`
→ Evaluation says; `0.0.0.0` and `::` are the wildcard
addresses there too.

**Local accounts:**

```powershell
try { Get-LocalUser -ErrorAction Stop | Format-List Name, Enabled, PasswordRequired, PasswordLastSet, LastLogon, SID } catch { "failed: $_" }
```

- An enabled account with `PasswordRequired` `False`:
  **WARN** — it may have an empty password; the flag alone does
  not say it has one.
- The guest account (SID ending in `-501`) enabled: **WARN**.
- The built-in administrator (SID ending in `-500`) enabled
  and in use is common; report it as **INFO**, and name its
  last logon.
- An enabled account that has not logged on in 90 days, or
  never: **INFO**.

The members of Administrators come from Local Administrators
above; name every one that `memory.md` does not explain. On a
domain controller these checks do not apply.

**SMBv1:**

```powershell
try { Get-SmbServerConfiguration -ErrorAction Stop | Format-List EnableSMB1Protocol } catch { "failed: $_" }
```

- `True`: **WARN** — SMBv1 is not installed by default on
  Server 2019 and later, and Microsoft advises against it
  ([SMB protocols](https://learn.microsoft.com/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3)).

**Remote Desktop:**

```powershell
try { Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction Stop | Format-List fDenyTSConnections } catch { "failed: $_" }
try { $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; if (Test-Path $k) { Get-ItemProperty $k -ErrorAction Stop | Format-List fDenyTSConnections, UserAuthentication } else { 'no policy key' } } catch { "failed: $_" }
try { Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -ErrorAction Stop | Format-List UserAuthentication, PortNumber } catch { "failed: $_" }
```

Each setting takes the policy value where the policy key sets
it, and the local value otherwise.

- `fDenyTSConnections` `0` means Remote Desktop is on.
- Remote Desktop on with an effective `UserAuthentication` of
  `0` — no Network Level Authentication: **WARN**.
- Remote Desktop reachable through the firewall from any
  address: **WARN**; name the rule.

**Defender and BitLocker.** The blocks above, rated as those
sections say.

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
- Hostwarden's backups (`rules/backups.md`):
  `C:\ProgramData\hostwarden\backups\`. A registry key is backed
  up with `reg export`, a file with `Copy-Item`, and backups
  older than 30 days are removed, all in one call:

  ```powershell
  $d = 'C:\ProgramData\hostwarden\backups'; $t = Get-Date -Format yyyyMMdd-HHmmss; New-Item -ItemType Directory -Force $d | Out-Null
  reg export '<key>' "$d\<name>-$t.reg" /y; if ($LASTEXITCODE -eq 0) { 'backup ok' } else { 'failed: reg export' }
  try { Copy-Item '<file>' "$d\<name>.$t" -ErrorAction Stop; 'backup ok' } catch { "failed: $_" }
  Get-ChildItem $d -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-30) | Remove-Item
  ```

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
  Where the default shell is a POSIX layer
  (`rules/os-detection.md`), `type` is that shell's builtin
  and `dir` may be missing: read with `cat` and list with
  `ls -l` instead, on the layer's path —
  `/c/ProgramData/ssh/…` under Git Bash and MSYS2,
  `/cygdrive/c/ProgramData/ssh/…` under Cygwin. `icacls` is a
  Windows program and works the same, with the Windows path in
  single quotes.
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
