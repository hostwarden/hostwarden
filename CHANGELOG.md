# Changelog

The notes of this release only. Earlier releases: the `CHANGELOG.md`
at their tag, or
[GitHub Releases](https://github.com/hostwarden/hostwarden/releases).

## 1.4.0 - 2026-10-24

### Added

- **Hostwarden can log in with an SSH key of its own.** Asked once,
  never required: the key lives in Hostwarden's own agent, your
  password manager's agent or a hardware key, and every host's log
  then names its logins. You add the line `bin/hostwarden-identity
  line` prints to each host; once a fresh login with it has worked,
  Hostwarden offers that key there instead of your agent's, and the
  doctor, the guard and the security and fleet audits check it. The
  key can also log in with a certificate from your SSH CA: recorded
  in `memory/user.md`, it is offered to the hosts you record as
  taking it, with no `authorized_keys` line there, and session start
  reads how long it is still valid and names your renewal command
  before it runs out. Hostwarden never signs or renews it, and the
  key ID it carries shows in the audits' login counts.
- **A session on the operations host can change hosts while you
  unlock a write key there.** Hostwarden's own key, in an encrypted
  file you load for a time you name, or certified by your CA for a
  few hours; once it is gone and its connections are closed, the
  machine is read-only again. The nightly fleet run passes no agent
  and uses connection sockets of its own, so an unlocked write key
  stays out of its reach.
- **A server can lock itself against changes.** `allow_changes = false`
  in `/etc/hostwarden.conf`, or in `/etc/heinzel.conf` as Heinzel
  reads it, puts every session into read-only mode for that host,
  local mode included. An unreadable or empty file, any line that is
  not `true`, a `false` beside a `true` among them, and a missing end
  marker lock too. Hostwarden never writes, moves, touches or
  deletes either file, and the taboo guard denies those writes.
- **Hostwarden refuses attacks on any host, yours included.** It
  never recovers a password or key, gets into a system without
  authorization, scans hosts it does not manage, watches people,
  hides traces or turns your servers against others. No story around
  the request and no override changes that, and the guard-disable
  switch does not lift it. A refusal is one sentence, a line in
  `memory/refusals.log`, which stays on your machine (a copy your workspace
  already tracks is removed from it and kept here), and the topic
  stays closed for the session. Defensive work such as auth-log
  reading and the security audit is unchanged.
- **Long jobs run on the host and are read back.** A package upgrade
  or a big `rsync` used to run inside the SSH call, which the tool's
  time limit or a dropped connection ends while the command runs on,
  and its result was lost. A command that can take more than a minute
  now runs as a `nohup` job under `~/.hostwarden-jobs/<id>`, output
  and exit status in files, and one later call reads it back; a job
  not seen to start within five seconds fails the start call. The
  job is registered with the host's other sessions, recorded in the
  host's `todo.md`, stopped by process group and cleaned after seven
  days, and an interrupted command is looked up before it is repeated
  (`rules/ssh-connections.md` → Long jobs,
  `rules/verify-before-reporting.md` → A command without a
  result ran, or it did not).
- **A development session knows where your operations clone is.**
  Record its path once in `~/.config/hostwarden/operations-checkout`
  and every development checkout on the machine names it at session
  start and in each refusal, instead of asking in every session. The
  agent offers to write the file after it has asked. Where a tool
  can offer a session that starts in the operations checkout itself
  on one click, the agent offers that before the terminal command.
- **A container template you built yourself can be adopted.** A
  baked archive on a Proxmox VE node, Heinzel's included, is read
  and measured against the baseline, packages, login, keys and
  updates, instead of rebuilt; onboarding and the Heinzel takeover
  offer it.
- **A login notice for a pending reboot on Debian and Ubuntu.** The
  baseline deploys `/etc/update-motd.d/91-hostwarden-restart`: at
  the next login on the console or over SSH it names the reboot and
  why, whether a package asked for it, a newer kernel is installed
  or CPU microcode waits, and lists the services that still run
  replaced libraries, so a host kept on needrestart's list mode does
  not leave a restart unnoticed. It prints nothing when nothing
  waits, and leaves `/etc/motd` and other motd scripts alone.
  Housekeeping reports a host without it as INFO; a new guest gets
  it from its first boot.
- **The baseline expects needrestart on Debian and Ubuntu, in list
  mode.** A new guest gets the package and a drop-in that sets
  `$nrconf{restart} = 'l'`; housekeeping reports a host without
  needrestart, or without an explicit mode, as INFO, and
  `hostwarden-baseline` offers to install and set it. Automatic
  security updates then leave the services that still run the old
  library visible instead of unseen. On Ubuntu 24.04 and later the
  drop-in also stops unattended-upgrades from restarting services in
  the night, which needrestart does there by default; a decision for
  the host, or an override that replaces the Service Restarts
  section, keeps `a`.
- **The baseline expects SELinux or AppArmor, enforcing.** The
  security audit warns only where the module is disabled; SELinux
  in permissive mode, or AppArmor without an enforced profile, is
  a note. The baseline skill gives you the steps instead of taking
  them, since turning one on can stop a service.
- **The doctor names the agents and key files ssh offers, and warns
  about a key file without a passphrase.** It covers the keys every
  host gets and those of the block in `~/.ssh/config` of a host
  Hostwarden knows, and
  also names a key with a passphrase that no agent holds. In an
  operations checkout it checks at every session start, gives up on
  a step that takes over five seconds, and refuses nothing; no key
  material reaches its output.
- **The security audit reports SSH logins that need two factors.**
  It counts what each method asks for, so a password asked twice is
  one factor, and says so where a PAM stack is too involved to tell.
  An override turns on a note for hosts whose sshd
  accepts one factor, for where NIS2 or BSI IT-Grundschutz applies.
- **On Unraid, Docker is restarted over SSH without the session's
  `XDG_RUNTIME_DIR`.** Restarted as it is, dockerd keeps a runtime
  directory that goes away with root's last SSH session, after which
  every `docker exec` and health check fails; the rule gives the safe
  restart and a check for a daemon already caught that way. It also
  says that the Docker tab's autostart list, not the restart policy,
  decides which Unraid-managed containers come back after a reboot,
  that a staged NVIDIA driver differing from the loaded one means a
  reboot is pending, and where to see whether a User Script ran.
- **A fault is diagnosed in a fixed order.** A new rule has the
  session show the exact symptom with a read-only command, list
  three to five ranked causes for you to correct before it changes
  anything, test one change at a time with its undo decided first,
  and treat a raised log level as a change that is asked for, tagged
  and removed afterwards. The confirmed cause and its evidence go into
  the changelog entry.
- **Freeing disk space sorts every candidate by what it takes to get
  it back.** The agent measures first and reports sizes per class.
  Package caches go as one group with one question. Build caches
  are proposed with their cost. User data, volumes, log files and mail
  are never proposed for deletion. Snapshots, old kernels and
  journal history are each a question of their own, because
  removing them closes a rollback or an audit trail. A log under
  logrotate or journald is still measured against its rotation
  policy before it is ruled out as the cause, since time-based
  rotation caps nothing between runs and a retention limit can
  exceed the disk.
- **Small hygiene rules for servers.** The agent ends a process by its
  one PID and never by name pattern, lists file names before it reads
  fields in a recursive search, keeps log excerpts, mail content and
  personal data out of memory, and knows that a conversation rewind
  undoes nothing on a host. A deploy key goes to the CI secret store
  over stdin, and a user's shell profile gets one marked block, with
  `.bashrc` backed up and a managed file changed at its source.
- **Mail DNS checks for a host that sends or receives mail.** The
  agent reads SPF, the DKIM selector's key length, DMARC, MTA-STS,
  TLS reporting, reverse DNS against the HELO name and CAA, mostly
  from the workstation, and rates each finding. Housekeeping runs
  it for a host with a mail server, and a missing record comes with
  the one to add. Strict values
  such as DMARC `reject` are recommendations, never a baseline
  failure, and a parked domain gets a null MX, `v=spf1 -all` and
  DMARC `reject` as a proposal. It changes no zone.
- **Housekeeping names vendor repositories that automatic updates
  skip.** On Debian and Ubuntu, unattended-upgrades installs only
  from the origins it is given, so Docker CE, NetBird, Grafana or a
  PPA waited for a manual upgrade unnoticed. Each enabled vendor
  repository is now listed with whether an origin covers it and
  which of its packages wait: a warning when updates are pending
  outside the origins, a note when none are yet, and a line marked
  decided where a decision keeps the repository out. A pattern that does not
  name an origin, a site and a component, or holds a wildcard in any value, is
  flagged too, whether or not it takes a repository yet. The baseline adds a
  missing origin as a drop-in per vendor, built from the repository's own
  Release fields with its site always named; on a host under
  configuration management it goes into the playbook instead.
- **Docker engine upgrades are checked for what they restart.**
  An upgrade of `docker-ce` restarts the engine and, without
  `live-restore`, every container. Housekeeping now notes a Docker
  host that upgrades its engine unattended without `live-restore`,
  and warns about a container meant to run that went down with the
  engine's last stop and did not come back, whatever its exit
  code.
- **Web servers get a TLS and header profile.** Installing or
  changing nginx, Apache, Caddy or HAProxy as a web server or
  reverse proxy now follows Mozilla's Intermediate profile: TLS 1.2
  and 1.3 with forward-secret AEAD suites, a certificate from ACME,
  port 80 only redirecting, HSTS, and no version in `Server`. The
  security audit probes the same from the host itself, with a
  deadline on its probes where the host has `timeout`, and rates what it finds.
  HSTS preload, re-encrypting to backends, TLS 1.3
  only and cache limits are offered once and become a decision
  only when you say so.

### Changed

- **The background coordinator session is now called presence:
  rename `Coordinator: off` to `Presence: off`.** A `Coordinator: off`
  line in `memory/user.md` is no longer read, and an override
  `memory/custom-rules/hostwarden-coordinator.md` is read only as
  `hostwarden-presence.md`; stop a running old session once with
  `claude stop` before updating. The skill is `/hostwarden-presence`,
  the session `hostwarden presence`.
- **A host the session is creating is not announced.** A new
  guest's first boot, reboot from inside and the firewall and services set up
  on it have an empty blast radius, so
  `rules/coordination.md` now says there is nothing to announce and
  nobody to inform; the trigger lines in `AGENTS.md`,
  `rules/service-reload.md`, `rules/ssh-safety-net.md` and the
  `hostwarden-new-guest` skill point there. In `rules/coordination.md`, a
  message to sessions is an "announcement", apart from the `Downtime notice:`
  to customers and IT.
- **Proxmox VE containers start lean.** The baseline template now has the
  baseline baked in and no cloud-init, for Debian, Ubuntu, the RHEL family from
  release 9 (not Fedora), openSUSE and Alpine, whichever official template you
  pick:
  a small first-boot service (systemd or OpenRC) places the SSH login before
  sshd first
  starts and runs the first upgrade, so a container carries no cloud-init
  and boots faster. Housekeeping warns when a node's archive differs
  from the recorded checksum, so every node keeps the same template.
- **A version check says `UNKNOWN` where it cannot read what is
  installed.** Software that memory names without a version is read
  from the host, and where that fails the housekeeping report shows
  `UNKNOWN` with the reason, as `INFO`, in place of a comparison that
  never took place.
- **Brute-force protection is rated by exposure.** A service that
  takes a password from the internet with no fail2ban, CrowdSec,
  sshguard or blocklistd watching it is now a warning; with
  key-only SSH and no such service, a missing ban tool is no
  finding. Where one is needed, each OS family names it: fail2ban
  in its normal mode reading the journal, from EPEL on RHEL and
  Package Hub on SLES, and blocklistd on FreeBSD.
- **Hostwarden asks for keys in an agent or on hardware, not
  passphrase-free keys.** The documentation now recommends a key an
  agent confirms per use (1Password, Bitwarden, KeePassXC,
  `ssh-add -c`) or a hardware key, and a key without a passphrase
  only for an operations host's fleet-read key and a deploy user's
  pipeline key. That pipeline key is made by you, with a command
  Hostwarden hands over, under `~/hostwarden-keys/`.
- **An OS replacement makes the new system the boot default before
  the old one goes.** After the one-shot test boot, the new entry is
  set as the permanent default, read back and booted once without
  the one-shot; only then is the old system removed, so a plain
  reboot can no longer land in a loader with nothing behind it.
- **Hostwarden works with the disk a machine has.** It never grows a
  disk, volume or VM at the provider or in the hypervisor, and does
  not propose it for a space problem unless you bring it up. Sizing
  a new guest at creation is unchanged.
- **Memory files and the changelog are edited with the file-edit
  tool.** An in-place `sed` or an interpreter heredoc that names
  `sshd_config` or a key path is denied by the guard; the edit tool
  is judged by the file it writes.
- **The guard blocks boot writers and direct writes to the account
  files.** `efibootmgr` with a write flag, `grub-install`,
  `update-grub`, `grub-mkconfig -o`, `bootctl install` and its
  siblings, `bless` beyond `--info`, `efivar -w` and writes under the
  EFI variables mount are taboos, lifted for OS installation the way
  disk writes are. So are `vipw`, `vigr` and a direct write to
  `/etc/passwd`, `shadow`, `group`, `gshadow` or `master.passwd`.
  Shell commands and the Edit and Write tools are denied alike, in
  every mode; `useradd`, `usermod`, `passwd` and `pw` stay the way to
  change accounts. Reading all of them, the EFI variables mount
  included, is unchanged.
- **Log queries stay inside the time limit and say when they saw only
  part of the journal.** The agent bounds every journal or log read
  by `--since` or `-n` and filters with field matches and `-g`
  instead of piping a whole journal through `grep` or `tail`; a query
  that timed out is narrowed, not repeated. A session user outside
  `systemd-journal`, `adm` and `wheel` checks that it can read the
  whole journal before drawing a conclusion, runs the query under
  sudo where that works, and otherwise reports the result as
  incomplete.
- **The SSH safety net covers more and never runs unarmed.** The
  timed undo now also guards PAM, VPN and tunnel, and network sysctl
  changes, not only firewall, network and login shell. It is armed in
  the same command that applies the change, so the change cannot run
  without it, and on a host with systemd the apply runs detached from
  the SSH session. A key login does not test a PAM auth stack, and
  the rule now says so. When
  a change moves the host's address, the confirming login goes to the
  new address and the timer is cancelled only through it. The rule
  also lists the failures that show later, such as `fstab`, units,
  cron and renewals, to check before any reboot, and forbids a
  reboot inside the window. Where the tool can check the written
  firewall or network file, the check and the cancel run in one
  call, so a failing check leaves the undo armed. Where the undo only
  reverses the runtime, as firewalld's reload and a sysctl do, the
  pending permanent write is noted in the host's to-do first, and a
  failed write is resolved from the backup or by persisting again,
  never by leaving runtime and files apart.
- **A removed host leaves no record behind.** When a guest
  or host is deleted, the answer ends with the DNS records
  that name it: A, AAAA, CNAMEs that target it, MX and PTR. The user
  removes them, or Hostwarden does where the zone is set to `write`.
- **PowerShell 7 on Windows Server is installed from the newest LTS
  line.** The install used the newest stable release that still ships
  an MSI, which could be a release that stops getting fixes a few
  months after the next LTS ships. It now takes the newest LTS line
  still in support, read from Microsoft's lifecycle page. A host that
  already runs a non-LTS 7.x is reported, never downgraded, and an
  LTS line within 90 days of its end of support is a warning
  (`rules/os/windows.md` → Install PowerShell 7, The installed
  PowerShell 7).
- **Windows file reads name their encoding.** A file without a byte
  order mark is read as ANSI by Windows PowerShell 5.1 and as UTF-8
  by PowerShell 7; the rule now asks for an explicit `-Encoding` and
  rules out the system-wide UTF-8 switch (`rules/os/windows.md` →
  Common Pitfalls).

### Fixed

- **An alias or function no longer changes a command the session
  relies on.** In a shell that may have read the user's profile —
  the workstation, local mode, a plain `ssh host 'cmd'`, `bash -lc`
  — sessions write `command <tool>` (`\<tool>` in csh) for every
  command whose output or effect they use, and `command sudo` where
  a `sudo` alias expands the next word. `rm -i` without a terminal
  keeps the file and exits 0, the case that shows it. Calls inside
  `sh -s`, scripts and behind `xargs` need none; the limits are in
  `rules/shell-aliases.md`.
- **A community script's application is version-checked against what is
  installed.** Housekeeping counted such a guest's application among
  the software it always checks, but memory held only the script's
  name, so there was nothing to compare. Memory now also says where
  the version is read, worked out from the script's install and update
  code, and again every 14 days. Each check reads the version from the
  guest, where the script's engine keeps it, and before the guest's
  first update from the file the install script wrote. An application
  the script installs from a package repository is left to the pending
  updates, until a script's update function moves it to a deploy helper
  and the file is there; one it builds from source has no version to
  read.
- **A NetBSD, OpenBSD, DragonFly, illumos or AIX host is no longer
  refused as a menu.** The first-call gate stopped on any first line
  other than Linux, FreeBSD or Darwin, so a real Unix shell was treated
  like a banner. Such a host now gets its own outcome: Hostwarden says it
  has no OS file for it, reads with generic POSIX commands, and
  asks before changing anything. A menu or banner is still refused.
- **Housekeeping checks every Time Machine destination on its own.**
  A Mac that backs up to a local disk and a network share gets one
  state per destination; one that is not mounted or unplugged reads
  "last backup unknown", not "no backup", and the backup is never
  rated CRITICAL while Time Machine is set up.
- **Pending updates include those that need a new package.** The count
  came from a plain upgrade simulation, which holds back an upgrade
  that pulls in a new dependency, so such an update never showed.
- **The auto-mode block goes where Claude Code reads it.** The rule
  told you to put `autoMode` in the project's `.claude/settings.json`,
  which Claude Code ignores, so writes over SSH stayed blocked. It now
  names `~/.claude/settings.json`, lists your servers as trusted
  hosts, and points to `/auto-mode-setup` with three checks for its
  draft. A refusal of any server write, not only a reload, now stops
  the work and names that fix.
- **Example commands now follow the same conventions as the rest.**
  Package installs on Debian, SUSE, FreeBSD and the mise setup run
  non-interactively, appliance API reads and calls on a new
  environment such as a container or another user set an English
  locale, and the shell setup for a runtime edits `~/.bashrc`
  portably on FreeBSD and macOS as well.

### Security

- **The taboo guard blocks the partition and RAID tools of NetBSD,
  OpenBSD and illumos.** `disklabel`, `mbrlabel`, `fmthard`,
  `raidctl` and `bioctl` rewrote a partition table or a RAID set
  without the guard stopping them. Their write options are now
  denied, in every permission mode, while the display forms stay
  allowed.
- **The guard holds an SSH key or sshd_config against a file name
  spelled in Unicode.** On macOS a ligature, a sharp s or a zero-width
  character in a path opens the same file, so Edit or Write on
  `sshd_conﬁg` reached it past the guard. The target is now also
  matched with the characters Unicode folds onto ASCII letters spelled
  out and with all other non-ASCII removed. Without jq a relative or
  JSON-escaped target is denied, and every path key of a call is judged,
  not the first.
- **Hostwarden's SSH calls never forward your agent, your display or
  a port.** `memory/ssh_config` sets `ForwardAgent no`,
  `ForwardX11 no` and `ClearAllForwardings yes` ahead of your own
  `~/.ssh/config`, so a `ForwardAgent yes`, a `ForwardX11 yes` or a
  forwarding under `Host *` no longer reaches a managed server. A
  port forwarding a session needs goes through the shared
  connection's socket, and the security audit reports
  `AllowAgentForwarding yes` as INFO.
