# DrayOS

Base: none
Hardware: vendor

DrayOS is DrayTek's own firmware for its Vigor routers. It is not
Linux and has no POSIX shell: SSH leads to DrayTek's command line,
whose commands this file lists, and to nothing else. No rule or
skill command written for `sh` runs here, `LC_ALL=C` and the
`sh -s` bundle included. Where `AGENTS.md`, a rule or a skill
expects something of a Linux server, this file says what to read
instead, or that there is nothing.

**The router is everyone's way out.** A wrong WAN, firewall or
management change cuts off every device behind it, not just your
SSH session. Every change here needs an explicit request, one
command at a time, each confirmed by the user, and the user must be
able to reach the router's web UI from the LAN before a change to
management access.

DrayTek documents much of the command line only as a reference for
one model and says that other models support a subset. A command
this file names can be missing on a given router, which then
answers that it does not know it. Read that as "not available on
this model", never as a fault.

Sources unless noted: DrayTek's *Telnet Commands for DrayOS
Routers* v1.4, written for the Vigor2862 on firmware 3.8.8
(<https://www.i-lan.net.au/dfaq/DrayTek/misc/DrayTek_Telnet%20Commands%20V1.4.pdf>,
a distributor's copy), DrayTek UK's knowledge base
(<https://www.draytek.co.uk/support/guides>) and its security
advisories (<https://www.draytek.co.uk/support/security-advisories>).

## Version Detection

- **This file covers DrayOS 3.x and 4.x**: the command line with
  `sys`, `mngt`, `wan`, `ip` and `show`, on the Vigor 2862, 2865,
  2866, 2926, 2927, 2135, the 276x series and the 2962, 3910 and
  3912 on firmware 4.x. The Vigor 391x runs DrayOS inside a Linux
  host of its own; the command line is still DrayOS's.
- **Stop on the others**, as `rules/os-detection.md` → Layers says,
  and change nothing:
  - DrayOS 5 (Vigor 2767, 2928, C410ax, C510ax, 2136AX), whose
    command line is a different one, with `exec sysinfo` and the
    like
    (<https://www.draytek.co.uk/support/guides/kb-top5-drayos5-commands>);
  - the Linux-based Vigor 3900, 2960 and 300B, and a Vigor 2760 on
    firmware 1.x
    (<https://www.draytek.co.uk/support/guides/os-versions-on-vigor-2760-series-routers>);
  - VigorSwitch and VigorAP, which have command lines of their own.
- `sys version` prints the router's model, its firmware version and
  build date. Record `- Appliance: DrayOS <firmware>, <model>` and
  `- Model: <model>`.

## Access and Shell

- **Detection.** The first call of `rules/os-detection.md` ends in
  `exec request failed`, with or without `on channel 0` (a shared
  connection leaves it off): DrayOS takes no command on
  the ssh command line. Ask the user what the device is; where the
  answer is a DrayTek Vigor router, or the user named one before,
  go on here.
- **Login.** DrayOS takes a password, not a key: the admin account
  of the web UI, or a local administrator where the model has
  them. Set it up as `rules/ssh-passwords.md` says before the first
  call. The SSH server calls itself `DraySSH_2.0`.
- **Old algorithms.** Older firmware offers only old key exchange
  methods, host key types or ciphers, and a current ssh refuses to
  connect with `no matching …`. Add what ssh named as the offer to
  the host's block, as `rules/ssh-config.md` → What memory/ssh_hosts
  Holds allows, after telling the user that the router runs weak
  cryptography and a current firmware may not. A host key of type
  `ssh-dss` cannot be added: current OpenSSH has no DSA at all. Say
  so, and stop until the firmware is updated.
- **The channel.** Commands go to the command line on stdin, one per
  line, the last one `exit`. Try this first, on the first
  connection, with the one read-only command:

  ```bash
  ssh -F "/srv/hostwarden/memory/ssh_config" -T admin@rtr1.example.com <<'EOS' | tr -d '\r'
  sys version
  exit
  EOS
  ```

  `/srv/hostwarden` stands for the checkout. Where it prints the
  model, record `- CLI channel: stdin`. Where it prints nothing, or
  only a prompt, repeat it once with `-tt` in place of `-T`, which
  asks for a terminal; the reply then echoes each command and its
  prompt. Where that works, record `- CLI channel: terminal`, and
  every later call uses `-tt`. Where neither works, stop and show
  the user both replies.
- **One call per step**, the commands in one here-document, as the
  bundle of `rules/ssh-connections.md` → Bundle commands is for a
  shell. Give the call a timeout: a session that does not end on
  `exit` holds it open.
- **A command that asks** — a `(y/n)`, a menu, a line waiting for
  input — is never answered: send `exit` and stop. The same
  questions reboot the router or reset it.
- The password never goes into a here-document. The helper gives
  it to ssh (`rules/ssh-passwords.md`).

## Configuration Model

- A change on the command line takes effect at once, in memory.
  `sys commit` writes the running configuration to flash; without
  it, the next reboot loses the change. After a change the user
  asked for, say so, and run `sys commit` only once the user has
  seen that the router still works.
- **Before any change, a backup** from the web UI: System
  Maintenance > Configuration Backup, which writes an encrypted
  `.cfg` file
  (<https://www.draytek.co.uk/support/guides/kb-config-backup>).
  The command line has no documented export. Ask the user to save
  one and to say where it is, and record that in the changelog
  entry, never the file's password.
- The web UI and the command line change the same configuration.
  Hostwarden changes nothing on its own initiative here; it reads,
  reports and suggests, and a suggested change names the web UI
  page as well as the command.

## Commands That Change or Destroy

Treat each as the `AGENTS.md` rule for its kind says:

- **Reboot:** `sys reboot`, and `sys autoreboot`, which schedules
  one. Ask first, as for any reboot.
- **Factory reset:** `sys cfg default`. Never, unless the user asks
  for exactly this: it drops every setting, the admin password and
  management access included.
- **Management access:** `mngt accesslist`, `mngt lanaccess`,
  `mngt sshport`, `mngt httpsport`, `mngt rmtcfg`. A mistake locks
  everyone out of management, Hostwarden included. A firewall and
  network change: `rules/ssh-safety-net.md` first.
- **Network:** `wan disable`, `ip addr`, and every `ipf` command
  that adds, edits or removes a filter rule. A firewall and network
  change.
- **Credentials:** `sys passwd`, `sys adminuser`. A credential
  rotation: ask first, and set the new password up again as
  `rules/ssh-passwords.md` says.
- **Never run** `sys adminuser view`, which prints the local
  administrators' passwords in clear text
  (`rules/secrets.md`), nor `log -F` or `ip arp flush`, which
  empty the log and the neighbour table.

## Updates

- DrayOS updates only as a firmware image, through the web UI
  (System Maintenance > Firmware Upgrade) or DrayTek's own tools.
  Hostwarden never installs one: it names the version to install
  and where it comes from, and the user installs it.
- The current firmware for the model comes from a live web search
  of DrayTek's download pages (`rules/version-check.md`), never
  from memory.
- Compare the running firmware with DrayTek's security advisories.
  DRAY:BREAK (October 2024, CVE-2024-41583 to CVE-2024-41596) and
  CVE-2025-10547 (October 2025) are remotely exploitable through
  the web UI, and each advisory names the first fixed firmware per
  model
  (<https://www.draytek.co.uk/support/security-advisories/kb-advisory-cve-2025-10547>,
  <https://www.forescout.com/research-labs/draytek-dray-break/>).
  Read the advisories live: later ones exist.
- A model past DrayTek's end of support gets at most critical
  fixes, and after that none
  (<https://www.draytek.co.uk/support/product-lifecycle>).

## Automatic Security Updates

DrayOS has none. The baseline's expectation of automatic security
updates is not a finding here; a firmware behind the advisories is
(Housekeeping and Audits).

## Logs

- DrayOS has no journal Hostwarden can write. The journal headline
  of `rules/changelog.md` goes to the local changelog only, and
  the changelog entry says so once per session: `journal: none
  (DrayOS)`.
- The activity check has nothing on the host to read: say
  `not read: DrayOS has no journal`, and read the local changelog.
  Nothing on the router tells one session from another either: no
  register and no journal, so `rules/parallel-sessions.md` → Hosts
  without a register cannot run here. Before a change, say that no
  other session can be seen on the router, and ask the user whether
  someone else is working on it now.
- `log -t` prints the router's own log, `log -w` its WAN log;
  `sys cmdlog` lists the commands run on the command line, where
  the model has it. DrayOS keeps them in memory only: a reboot
  empties them. A syslog server set in the web UI keeps them
  longer.

## Housekeeping and Audits

- The Linux baseline does not apply. Housekeeping reads, in one
  call through the channel above:

  ```
  sys version
  show status
  wan status
  sys ver systeminfo
  sys iface
  ip route status
  srv dhcp status
  show session
  log -t
  exit
  ```

  `sys ver systeminfo` gives CPU and memory load
  (<https://www.draytek.co.uk/support/guides/kb-draytek-cpu>).
  Findings: a WAN that is down, CPU or memory load that stays high,
  a NAT session table near its limit, errors in the log, a firmware
  behind the advisories (CRITICAL where an advisory names it as
  remotely exploitable), a model past its end of support (WARNING).
- A security audit reads, in one call, instead of the `sshd`,
  firewall and account checks:

  ```
  mngt rmtcfg status
  mngt accesslist list
  mngt lanaccess -v
  ipf view -r
  exit
  ```

  and reports:
  - management from the internet (`mngt rmtcfg`): enabled at all
    is a finding; HTTP, HTTPS, Telnet or SSH from the WAN without
    an access list is CRITICAL, since DrayTek's advisories name the
    WAN-facing web UI as the way in;
  - Telnet enabled on any interface: WARNING, it sends the password
    in clear text;
  - an access list that admits any address;
  - filter rules that pass traffic from the WAN to the router.

  SSL VPN from the WAN is a web UI setting the command line of
  this file does not read: ask the user for it once, as
  `rules/os-detection.md` → Layers says for settings only the web
  UI shows, and rate it like remote management. The same holds for
  two-factor login to the web UI, where the firmware has it.
- Fleet audit: DrayOS takes part in none of its probes; list the
  host as not audited, with the reason.
