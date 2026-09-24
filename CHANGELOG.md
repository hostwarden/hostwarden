# Changelog

## Unreleased

Hostwarden grew out of [Heinzel](https://github.com/wintermeyer/heinzel)
by Stefan Wintermeyer and branched off at Heinzel 2.22.0. It continues
as an independent project, keeps Heinzel's history and still takes over
Heinzel's improvements where they fit.

Hostwarden starts its own versioning at 1.0.0; Heinzel's numbers do not
continue here. The entries below describe what is different from
Heinzel 2.22.0. Heinzel's own release notes are in its repository.

### What Hostwarden is

- **Everything carries Hostwarden's name.** Scripts (`bin/hostwarden-*`),
  skills (`hostwarden-*`), environment variables (`HOSTWARDEN_*`), the
  journal tag on servers (`hostwarden`), the backup directories
  (`/var/backups/hostwarden/`, `~/.hostwarden-backups/`) and the SSH
  socket directory (`~/.cache/hostwarden`) carry the new name. A few
  things still understand the old one. The activity check reads `heinzel`
  journal entries as well as its own. A restore looks in Heinzel's backup
  directories too. `HEINZEL_NO_UPDATE` still works.
  `HEINZEL_GUARD_DISABLE` no longer switches the guard off.
- **One instruction set for every AI tool.** The rules are in `AGENTS.md`,
  which Claude Code, OpenCode, Codex and Cursor read natively. `CLAUDE.md`
  only imports it and adds what exists in Claude Code alone: the guard
  hooks, session-start hooks, pickers, slash commands, subagents and
  messaging between sessions. `AGENTS.md` names the moment and the file
  that covers it; the procedure lives in that file, so a session loads
  only what the moment needs.
- **Skills live in `.agents/skills/`.** OpenCode and other tools that
  follow the AGENTS convention find them there. `.claude/skills` is a
  link to that directory, so a checkout needs working symbolic links. A
  session-start check says so when the link is broken, where a session
  would otherwise just have no skills.
- **Rare workflows became skills.** OS installation, dual-boot, EFI
  boot entries, cloud images and partition staging are now
  `hostwarden-os-install`. Language runtimes are `hostwarden-runtimes`.
  CI/CD deploy accounts are `hostwarden-deploy-user`, which now also
  works on macOS. Scheduled housekeeping is part of the housekeeping
  skill. Each loads when you ask for that work and not before. Most
  skill descriptions now also list German requests.
- **OS files are layered.** The family file (`rules/os/<family>.md`) is
  the base. On top come an appliance file, a platform file for what
  the OS runs inside, and a role file for what the machine is for.
  Your overrides come last. Each layer replaces, removes or adds
  sections of the one below it. Detection still picks at most one
  family per host, and none for a distribution no family covers.
- **Runs in the Claude desktop app.** The Code tab runs the same Claude
  Code. `docs/ai-tools.md` says how to open the checkout (with the
  worktree option off), where environment variables go and how to
  schedule runs there.
- **On Windows, Hostwarden runs in WSL 2 only.** Git Bash, MSYS2,
  Cygwin, PowerShell and `cmd.exe` are not supported, and Claude
  Code's PowerShell tool is denied, because the guard cannot read what
  it runs. `docs/install.md` → Windows walks through the setup.
- **`bin/hostwarden-doctor` says what your workstation is missing.** It
  also says which feature each missing tool switches off, and gives the
  install command for your package manager. It runs quietly at every
  session start and never installs anything. Under WSL it warns about a
  clone under `/mnt` and an SSH key WSL cannot reach. When servers
  behind a Windows VPN stop answering from WSL, the unreachable-host
  check names WSL's network as the likely cause.
- **The README is about getting started.** Everything deeper lives
  under `docs/`, indexed by `docs/README.md`: installation, AI tools,
  features, safety, automation, overrides, operations. `CONTRIBUTING.md`
  and `SECURITY.md` are new.

### Safety

The guard hooks run in Claude Code. In other tools the same rules reach
the agent as instructions in `AGENTS.md`, and those are the whole
protection there.

- **The taboo guard sees more of what the agent does.** It judges
  Claude Code's Monitor tool, which runs shell commands in the
  background, exactly as it judges Bash. The edit tools are judged by
  the file they write: an SSH key, `authorized_keys`, a key store or
  sshd's configuration cannot be edited. A note that only mentions
  them stays editable. It applies to subagents too.
- **The guard no longer fails open for want of bash.** Every hook script
  is started with `sh`: without bash, Heinzel's guard never started, and
  Claude Code let every command through without saying so. A guard whose
  helper file is missing blocks instead of passing.
- **The guard can only be switched off before a session starts.**
  `HOSTWARDEN_GUARD_DISABLE` counts only for a session that started
  with it. A value that appears mid-session, for example through a
  settings file, changes nothing, and the agent cannot write the
  variable into a settings file. A session that starts with the guard
  off says so first.
- **The guard asks where a block would be too much.** Stopping or deleting
  a system container, VM or jail, routine storage changes, writing sshd's
  configuration or keys into a guest that has never started, and clearing
  its image's old host keys bring a permission prompt showing the exact
  command, in auto mode too. Where no prompt can reach a person, such as
  `claude -p` or `bypassPermissions`, the guard denies them instead. A
  taboo in the same command always wins.
- **Repairing or destroying storage is a taboo.** Heinzel blocked
  partition-table writes and whole-disk erases. Hostwarden adds `fsck`
  without `-n`, a writing `btrfs check`, `ntfsfix`, removing a volume
  group or a logical volume, shrinking resizes, creating or destroying
  a ZFS pool, a ZFS rewind, destroying a dataset and more. On macOS and
  Windows, `diskutil repairVolume`, `chkdsk /f` and `Repair-Volume` are
  added. Growing a volume, replacing a disk in an array, scrubbing,
  importing a pool or receiving a ZFS stream are asked, not blocked
  (`rules/storage.md`). When storage fails, Hostwarden reads, asks
  about the backup and hands the repair command to you.
- **The Windows taboos hold on any Windows machine**, over SSH and
  under WSL. Blocked:
  - **Power:** `shutdown /s`, `/p` and `/h`, `Stop-Computer`, and
    `wsl --shutdown` or `--terminate`.
  - **Disks:** `diskpart`, `mbr2gpt`, `format X:`, `cipher /w`, the
    Storage cmdlets and `wsl --unregister`.
  - **Boot:** `bcdedit` beyond reading it.
  - **sshd:** writes under `C:\ProgramData\ssh`.

  `shutdown /r` still passes.
- **The SSH taboo covers more SSH servers.** dropbear's configuration
  and keys are protected like sshd's, `uci` writes included. So are
  QNAP's `/etc/config/ssh` and the OpenMediaVault deploy that rewrites
  `sshd_config`, and deleting or moving sshd's revocation list.
  Certificates (`*-cert.pub`) count as public. The one exception is
  the first-boot configuration of a guest that has never run.
- **Ansible and Terraform are held to the same taboos.**
  `ansible-playbook` runs only for syntax checks and listings,
  `ansible-pull` and `ansible-console` never, and an ad-hoc `ansible`
  call is refused when its module partitions, formats, shuts down or
  writes keys or sshd's configuration. `terraform` and `tofu` never
  `apply` or `destroy`.
- **Harder to talk around.** A power-off flag next to a reboot flag is
  still a power-off, a word split by quotes or backslashes is read the
  way the shell runs it, and a refusal says not to reach the same
  effect by another route. It also says how to pass text that only
  names a taboo, for example a commit message given as a file.
- **A firewall, network or login-shell change undoes itself unless
  SSH still works.** Before applying one, Hostwarden arms a revert on
  the host (with `systemd-run` or `at`, or a scheduled task on Windows)
  that fires after five minutes, five to ten on FreeBSD, and is
  cancelled only once a fresh login succeeds. The revert restores the
  files on disk as well as the live rules, so a reboot cannot bring the
  change back. Where nothing can be armed, the change is yours, with
  the console ready.
- **sshd's ports are also read from the running daemon.** Before a
  firewall is enabled or tightened, Hostwarden reads a running
  daemon's own `-f` file, `-p` or `-o Port=` and a socket unit's
  `ListenStream`, besides sshd's effective configuration, and keeps
  every one of those ports open.
- **Probes withhold what can carry a secret.** Cron lines, hooks,
  units, repository and configuration lines are read for their
  structure only. `sudo -l` output is cut before the arguments.
  Comments in firewall listings are masked. More things count as
  secrets: CA signing keys, container environments and VPN
  configurations.
- **No session crosses its limits through someone else.** What one
  session may not do or see — a blacklisted or read-only host, no root,
  a guard block, a development checkout — no other session, subagent,
  job or token does for it, and a request from another session is not
  yours (`rules/borrowed-rights.md`).
- **The sudo probe tells refusals apart.** `sudo -n -l` replaces
  `sudo -n true`, so a user with passwordless sudo for selected commands
  only is recorded as such, and the commands sudo allows run through
  sudo instead of the root SSH fallback. `doas` and `wsl.exe -u root`
  stand in for sudo where that is how a host works. Membership in
  `docker`, `libvirt`, `incus-admin` or `lxd` is recorded and used only
  for that group's work.

### Operations and development checkouts

- **A checkout either operates servers or develops Hostwarden.**
  `bin/hostwarden-init` turns `memory/` into the workspace, a git
  repository of its own, and only a checkout with a workspace reaches a
  server. One without it — a fresh clone, a fork, every git worktree —
  is for changing Hostwarden. In Claude Code, `ssh`, `scp`, `sudo`,
  `ansible` and the other tools that reach a server fail there however
  they are started, while `git push` still works; other tools get the
  same rule as an instruction. A session-start hook names the mode.
- **An operations checkout keeps Hostwarden's files read-only.** In
  Claude Code the edit tools can change `memory/` and other ignored
  files, not the rules or scripts. A request to change Hostwarden gets
  a pointer to a development checkout and a pull request.
- **A development session hands a server question over.** When it
  needs a fact from a live server, it asks a session in the operations
  checkout — in Claude Code directly, elsewhere through a command you
  run there — which runs the access lists and the full pipeline and
  answers.
- **`bin/hostwarden-lab` lets development try commands.** Disposable
  containers for Debian, Ubuntu, RHEL, Fedora, SUSE and Alpine answer
  "what does this command print here" without guessing. A lab VM (with
  OrbStack or Lima) covers systemd, the firewall and the kernel. It
  only runs from a development checkout, and a VM is driven from a
  separate test clone whose blacklist is set.

### Workspace, teams and updates

- **Your servers' memory is a git repository of its own.**
  `memory/` is no longer part of Hostwarden's repository in any mode;
  its examples ship in `templates/memory/`. `bin/hostwarden-sync` pulls
  it at session start, commits the files a session names when it is
  done with a host, and pushes after asking once. It never stashes
  another session's uncommitted changes and never commits them along.
  Changes an ended session left behind are found and committed on
  their own after you say so.
- **Teams share the workspace through a remote.** A private remote of
  its own (`bin/hostwarden-init --clone <url>` to join one) keeps a
  team, or one admin's several machines, in step. Heinzel's team mode,
  which changed the repository's own `.gitignore`, is gone. `user.md`, the
  blacklist and the read-only list stay personal; host memory, host
  keys, decisions and deployed files are shared. Host changelogs from
  two machines merge on their own. Every workspace commit is scanned
  for secrets with betterleaks, which is required once the workspace
  has a remote.
- **Teammates have handles.** The journal line on a server names the
  short `Operator:` handle from `memory/user.md`. In a team it is
  reserved once in the shared `memory/operators.md` so two people
  cannot take the same one.
- **Sessions that change the same host see each other.** Before its
  first change, a session registers on the host itself in
  `/tmp/hostwarden/`, without root: who, from which workstation, doing
  what. Another live entry, a second window or a teammate, is named and
  you decide. In Claude Code, a session on the same machine can be
  messaged directly. Read-only sessions register nothing. Windows hosts
  use journal markers instead.
- **Standing decisions are recorded.** When you settle a standing
  choice with a reason, Hostwarden writes it down with who, when, why
  and what it covers: per host, per cluster or for a group of hosts
  (`rules/decisions.md`). Audits then show the matching finding as
  decided instead of proposing it again.
- **Every file Hostwarden deploys has a master in the workspace.** A
  script, unit, cron file or config drop-in it writes onto a server is
  kept at the same path under `memory/servers/<host>/files/`, or under
  `memory/fleet/` when several hosts share it, with its hash in
  `deployed.md`. Housekeeping reports a file edited on the host,
  removed there, or changed in the workspace without being deployed,
  and overwrites neither side. Work that spans sessions gets a plan in
  `memory/plans/`, and scripts for your own machine go in
  `memory/tools/`.
- **Your own skills travel with the workspace.** A skill in
  `memory/.claude/skills/` is shared like the rest of `memory/`.
- **Overrides mirror the path of what they change.**
  `memory/custom-rules/os/debian.md` overrides `rules/os/debian.md`,
  and `<skill>/<file>.md` overrides one reference of a skill. Session
  start names the overrides it loaded. An override that matches nothing
  shipped is reported, not ignored. `bin/hostwarden-migrate` moves
  Heinzel-era overrides to their new paths and keeps both files where
  one already exists.
- **An operations checkout follows the newest release line.** Its
  first update after a release settles on that release's major line,
  and it moves to each new release on it. `bin/hostwarden-update
  --follow 1.2` takes only 1.2.x fixes, and `--pin` holds one
  version. Once a release outside the line is out, every update says
  so. `--unpin` follows `main` instead, and after each pull names the
  changes that no release carries yet. The auto-update runs only in
  an operations checkout.
- **Your own mirror of Hostwarden stays current unattended.**
  `bin/hostwarden-mirror` fast-forwards a mirror's `main` and its tags
  from a CI or cron job. It fails rather than overwrite commits the
  mirror has of its own. `docs/operations.md` has job examples for
  GitHub Actions and GitLab CI.
- **Backup and restore know the workspace.** `bin/hostwarden-backup`
  leaves the workspace's git history and generated files out. A
  restore refuses to run in a worktree, sets the workspace up with
  `bin/hostwarden-init` and writes a fresh SSH configuration.

### Reaching a host

- **Host keys are checked against one file in the workspace.** Every
  connection trusts `memory/known_hosts` and nothing else, so in a team
  each key is accepted once for everyone and the workspace history
  shows who added it. A missing key is read through a hypervisor that
  is already verified, or imported from your own known_hosts files, or
  asked for: accept on first use, compare with the console, or stop.
  Nobody has to log in by hand first. A changed key stops the session,
  and nothing is replaced until you say so.
- **Every SSH call passes one generated file.** `memory/ssh_config`
  is written for your machine at every session start. It holds the
  connection sharing, keepalives and host-key settings, and reads your
  own `~/.ssh/config` afterwards for what it leaves open, such as a key
  or a user name.
- **Other ports, addresses and jump hosts are recorded.** A server
  that needs one goes into the shared `memory/ssh_hosts`, which accepts
  only `Host`, `HostName`, `Port`, `ProxyJump` and `HostKeyAlias`, so
  a teammate's entry cannot run a command on your machine. A port
  written with the host (`web1.example.com:2222`, `ssh://…`, `-p`) is
  understood and recorded. When port 22 of a new server refuses the
  connection, Hostwarden tries the ports you list as
  `Alternative SSH ports:` in `memory/user.md`, and 2222 where your
  known_hosts has a key for it, then asks. It never scans. Port
  forwardings are never stored.
- **Jump hosts go through the blacklist too.** Each hop of a
  `ProxyJump` or `ProxyCommand` is checked as the user it logs in as.
  A path Hostwarden cannot read is treated as a listed hop and asked
  about. When the chosen SSH user's configuration leads to another
  endpoint, the access checks run again for it.
- **An SSH CA you already run is audited and used.** Hostwarden reads
  each host certificate's expiry and names, the user CA each server
  trusts, its principals and its revocation list, and the CA's issuing
  rules where it can see them. Once you confirm a CA as yours, a host
  CA goes into the workspace's known_hosts, new guests trust your user
  CA from their first boot (containers from the Proxmox VE baseline
  template get the lines to add instead), and the baseline reports
  servers that do not. It never builds a CA, signs a certificate or
  touches a signing key.
- **Detection is one SSH call.** OS, version, login shell,
  architecture, hardware, virtualization and the appliance and
  hypervisor markers come back from one probe that runs in sh, bash,
  zsh, csh and tcsh alike. It stops at a console menu instead of
  answering it. Memory gains `Virtualization:` (container, VM or bare
  metal, and the cloud provider where DMI names one) and `Arch:`.
  Later connections send only a short version check.
- **Short names stay unambiguous.** Each server's FQDN is recorded,
  and a dotless name that matches several servers brings a question.
  For `.local` names, mDNS and DNS are both asked, and a disagreement
  stops for you instead of being taken as an alias.
- **Each host records its way back in.** A `Management:` line holds the
  BMC, Intel AMT, provider console or other path to use when SSH is
  gone. Housekeeping and the security audit settle it; a controller is
  only ever read, never changed.
- **The activity check says how far back it could see.** Every
  read-back prints its log's oldest entry. Where that is less than a
  week, as on hosts that keep their logs in RAM, Hostwarden names the
  date and reads your local changelog for the time before. Entries
  from a login session are told apart from scripts that log under the
  same tag.

### Reviewing servers

- **One written server baseline.** `rules/baseline.md` says what every
  server is expected to have:
  - a firewall that denies by default and keeps SSH open;
  - automatic security updates and time sync;
  - SSH by key only, and SSH CA trust where you run one;
  - a persistent journal and storage maintenance on a schedule;
  - the guest agent in a VM, and a backup.

  Housekeeping and the security audit measure every server against
  it. Your own additions go in `memory/custom-rules/baseline.md`, for
  example admin keys, the timezone, a mail relay or a monitoring
  agent. `/hostwarden-baseline` lists what a server lacks and applies
  it one asked step at a time. It never changes a running sshd; it
  gives you the change to make.
- **Onboarding a host is a skill.** `/hostwarden-onboard <host>`, or
  "onboard web1", runs the first connection now, read-only. It does the
  full probe, the network profile, and on a hypervisor the guest
  inventory, then reports what the host lacks against the baseline. A
  host already known is probed in full again.
- **Several hosts at once.** A question, check or change that names
  several servers runs the full pipeline on each host, in Claude Code in
  one subagent per host (`/hostwarden-multi-host`). Hosts that agree print
  once, so the outlier stands out. A change is asked once for all hosts,
  runs on a canary first, and stops at the first surprise. Firewall,
  network and login-shell changes still go one host at a time.
- **The fleet audit, in Claude Code, gives each host its own subagent**
  and returns one comparison row per host, keeping the raw output out of
  the conversation; elsewhere it probes one host after another. It now
  covers the network stack and resolver, mesh VPNs, accounts and sudo
  rules, SSH CA trust and, on Ubuntu, Pro, ESM and needrestart. It has
  Alpine, FreeBSD and macOS variants of its probes. A setting a family
  does not have reads `n/a`, not drift. Each guest is listed under its
  hypervisor, and a difference you decided on is shown as decided. Windows
  hosts are skipped.
- **Housekeeping checks more.**
  - **Engines and services:** container engines (Docker, Podman,
    containerd), Home Assistant on an ordinary host, Pi-hole, AdGuard
    Home and CasaOS.
  - **Hardware:** USB devices, with an unwatched UPS flagged; CPU
    microcode on bare-metal x86; and the BMC event log.
  - **Connectivity:** mesh VPN agents that are down or whose login is
    about to expire.
  - **Memory:** swap judged by its kind, with the ZFS ARC counted as
    available.
  - **Logs and time:** the persistent journal and the timezone.
  - **macOS:** launchd jobs, kernel panics and Time Machine snapshots.

  In a container, clock and kernel findings belong to the host and are
  not reported twice. Nothing is updated, pruned or restarted.
- **Disks and pools are known and watched.** On bare metal, each disk
  is recorded once with model, serial and firmware in
  `memory/servers/<host>/storage.md`. Housekeeping reads SMART on every
  bare-metal Linux and FreeBSD host and says when a disk appears,
  disappears or its error counts grow. A missing `smartctl` is reported
  as "not checked", not as healthy. ZFS pools and btrfs have their
  settings recorded and rated, for example `sync=disabled`, dedup
  without the RAM for it, or an ARC that crowds out a hypervisor's
  guests. Pool features are reported and never enabled. Whether TRIM,
  RAID checks, scrubs and `smartd` are scheduled is part of the
  baseline.
- **The security audit checks more.**
  - **Firewall:** IPv6 coverage of every firewall, legacy iptables
    rules counted as a firewall, and a firewall in front of the host
    recorded and weighed against the ports that still reach it.
  - **Remote access:** the SSH servers built into VPN agents and who
    they admit.
  - **Accounts:** where accounts and sudo rules come from (local, a
    directory, an agent) and who can become root without a password.
  - **Containers:** privilege, mounted sockets and exposed APIs.
  - **Services:** open DNS resolvers and exposed admin interfaces.
  - **macOS:** accounts, sharing and launchd permissions.

  sshd is read from what it really uses (`sshd -G`, a daemon's own
  config file, `Match` blocks), and the SSH client on the server is
  audited as well.
- **Hostwarden records how a host's network works.** On first contact
  it notes who manages the network. Where a host forwards, bridges or
  NATs, its traffic flow is recorded: hooks, NAT per backend and what
  restores it at boot. Mesh VPN agents are judged per process: which
  runs, whether it is connected, and what would cut the host off. The
  full network profile runs when you ask, on onboarding, and when a
  failure points at the network (`rules/network.md`).
- **Configuration management is respected.** Hostwarden detects
  Ansible, Puppet or OpenVox, Chef or Cinc, Salt, CFEngine and Rudder,
  and records Terraform or OpenTofu as the provisioner when you say a
  host is theirs. A change inside a
  tool's scope goes into that tool's code: Hostwarden edits Ansible
  playbooks when asked, and records a change made by hand as not yet
  in the tool. It never pushes for a tool, and never runs `terraform`
  or `tofu`.
- **Accounts follow the host's model.** Hostwarden records whether
  admins log in through a role account, a directory, local accounts or
  an agent, as one `Accounts:` line, and creates or removes accounts,
  groups and sudo rules the way that model does. It also covers
  certificate logins, team accounts through a user CA, and accounts
  handed out on demand by an identity provider. It never writes to a
  directory, an identity provider or a CA; it tells you what to create
  there.
- **Services in containers are changed where they are defined.** For
  Docker, Podman and containerd, Hostwarden finds the compose file,
  unit or tool that recreates a container and changes that, not the
  running container, and asks before a restart, pull or removal. A
  container an appliance's web UI owns is left to that UI, and
  Kubernetes workloads are reported, never changed.

### An operations host

- **Unattended housekeeping through signed read-only checks.** Fleet
  read (`/hostwarden-fleet-read`) gives an operations host's key two
  things on each server: running a bundle of read-only checks that you
  signed, and writing one read-only journal line.
  Hostwarden builds the bundle from its housekeeping checks and deploys
  the forced-command wrapper. Making the key, authorizing it and signing
  each bundle stay yours. A bundle stops working on its expiry date.
- **`bin/hostwarden-fleet-run` is the nightly run.** It updates
  Hostwarden and the workspace, reads every host through fleet read,
  has each result judged by Claude without tools, and mails the
  report. The script enforces each check's severity floor, so a
  verdict cannot talk a finding down. The operations host has its own
  operator handle and treats every host as read-only.

### Platforms

- **Alpine Linux is a supported family:** apk on stable branches,
  OpenRC, busybox, doas, musl and diskless mode. Every workflow has
  Alpine variants of the checks that assumed systemd or GNU tools.
  Alpine's stock nftables ruleset drops SSH, so Hostwarden opens every
  sshd port before starting it. An Alpine container image is recognised
  as a container, not a host to administer. `rules/busybox.md` lists
  what busybox does differently, on Alpine and OpenWrt alike.
- **Ubuntu servers are covered in their own right.** An inactive ufw
  is how Ubuntu ships, so it gets "enable it", not "install one".
  Ubuntu Pro, ESM, Livepatch and snap refreshes are read and reported.
  cloud-init's hold on network, hostname and SSH settings is
  recognised, and netplan changes run under the SSH safety net.
  Housekeeping reports fixes waiting on Pro and an LTS past standard
  support.
- **apt never stops to ask and never restarts services by itself.**
  Installs and upgrades on Debian and Ubuntu run non-interactively and
  keep locally changed config files. Services that need a restart are
  listed and left to you, also on Ubuntu 24.04 and later, where
  needrestart would otherwise restart them at once.
- **FreeBSD is covered in housekeeping and both audits.** Housekeeping has
  a full FreeBSD baseline, the security audit covers pf, ipfw,
  `master.passwd` and blocklistd, and the fleet audit has FreeBSD probes.
- **macOS knows what it may read.** Hostwarden detects whether SSH
  sessions have Full Disk Access, and reports a read macOS refused as
  not checked rather than absent.
- **Windows Server can be inspected over SSH, read-only.** Housekeeping
  and the security audit cover updates, services, the event log,
  disks, Defender, BitLocker, backup, sshd, the firewall profiles,
  accounts, SMBv1 and Remote Desktop. Updates are reported, never
  installed. When you ask, Hostwarden installs PowerShell 7 and makes
  it OpenSSH's default shell, with a timed revert. A Windows client is
  pointed to WSL 2 instead.
- **WSL is a platform, a workstation is a role.** Under WSL, Windows
  owns the kernel, the firewall and the instance, so Hostwarden reads
  them and leaves them alone. A Mac, a WSL instance and the local
  machine are inferred to be workstations and held to workstation
  expectations, not the server baseline; Hostwarden says so, and you
  can correct it.
- **firewalld changes over SSH are made at runtime first** and become
  permanent only after a fresh login works, so a reload is the way
  back.

### Appliances

- **Appliances get their own rules on top of the OS family.** Each is
  detected by a marker and recorded as `Appliance:` in memory. Its file
  replaces what the family file would get wrong: the updater, where
  settings live, the firewall, the logs. Where an appliance file names
  the releases it covers (Synology DSM, QNAP, Unraid, UGOS Pro,
  ZimaOS), Hostwarden stops on any other release before changing
  anything; UniFi OS works read-only there. The fleet audit compares
  an appliance only with its own kind. Covered:
  - **Proxmox VE:** always `dist-upgrade`; `pve-firewall`; the cluster
    and HA.
  - **OPNsense and pfSense:** the web UI and their own tools instead of
    `sysrc`; audited as routers.
  - **Home Assistant OS:** worked on through the `ha` CLI of an SSH
    app. On request, Hostwarden installs the ha-mcp app so an AI client
    can work on the configuration.
  - **XCP-ng:** XCP-ng's repositories only; pool master first; `xe` and
    Xen Orchestra.
  - **TrueNAS and TrueNAS CORE:** everything through the middleware.
    CORE is end of life and reported as such.
  - **Unraid:** the root-only login and an OS in RAM; array operations
    and updates are left to you.
  - **OpenMediaVault:** the web UI or `omv-rpc`, because OMV
    regenerates `/etc`; `omv-upgrade`; OMV's own firewall.
  - **OpenWrt:** UCI and fw4 with `fw4 check`; apk or opkg, never a
    mass upgrade; `sysupgrade` only after asking.
  - **Synology DSM, UGREEN UGOS Pro, QNAP QTS and QuTS hero, UniFi OS
    and ZimaOS:** each with its own updater, firewall and the settings
    its UI owns.
- **Vendor hardware is off limits for OS installs.** A `Hardware:`
  line says whether an appliance runs on its vendor's hardware or on
  any machine. The OS-install skill refuses to write to a vendor device
  and to any Mac.
- **Appliance APIs are read with read-only accounts.** Unraid (a
  `VIEWER` key), TrueNAS (a Readonly Admin user), Synology DSM and
  UniFi Network are read through their local APIs. A write account
  exists only if you ask for it and is used only for a change you
  approved. Credentials live in 0600 files you write and reach `curl`
  on stdin. A call from the workstation pins the certificate's public
  key you confirmed, and every answer is framed by markers bound to a
  per-call nonce, so a reply cannot forge its own status.

### Guests and hypervisors

- **Containers, VMs and jails are servers of their own.** Each gets
  its own memory and the full pipeline. SSH comes first. The
  hypervisor's tools (`pct exec`, `qm guest exec`, `incus exec`,
  `jexec`, …) are used only when the guest has no SSH server or SSH is
  silent and you agree. Each guest records the host it runs on as
  `Runs on:`, linked by MAC address and VM UUID, never by name alone.
- **A hypervisor's guests are inventoried and registered.** On Proxmox
  VE, XCP-ng, libvirt, Incus, LXD, LXC, bhyve, Hyper-V, VirtualBox and
  FreeBSD jails, Hostwarden lists every guest in
  `memory/servers/<host>/guests.md`, stopped ones and templates
  included. It asks once why stopped guests are off. Each running guest
  the hypervisor can enter gets memory of its own, read-only, and a
  report says what was read, written and left out. Guests on TrueNAS,
  Synology DSM, Unraid and ZimaOS are inventoried read-only.
- **Clusters are inventoried once.** A Proxmox VE cluster, an XCP-ng
  pool and an Incus or LXD cluster live in `memory/clusters/<name>/`
  with their members, HA state and guests. A guest's `Runs on:` follows
  it through a migration or failover.
- **Guest changes are careful.** A snapshot is preferred to a file
  backup before a risky change. What a snapshot leaves out, such as
  bind mounts and passed-through devices, is named first. Stopping or
  deleting a guest shows its disks and newest backup and asks.
  Housekeeping lists what a host passes through to its guests and flags
  a bind mount whose source fell back to the root filesystem.
- **New guests start on the baseline.** `/hostwarden-new-guest`, or
  "create a Debian VM on pve1", creates VMs and containers on Proxmox
  VE, libvirt, Incus, LXD and classic LXC. It starts from the
  distribution's official, checksum-verified image and applies the
  baseline at first boot in whatever form the guest reads: cloud-init,
  Ignition, kickstart, preseed, autoinstall or AutoYaST. You log in with
  your keys from the first boot; a password exists only if you ask, and
  the guest generates it. On Proxmox VE, containers come from a baseline
  template Hostwarden builds; housekeeping says when it is due for a
  rebuild. For Unraid, ZimaOS and TrueNAS you get the web-UI steps
  and a seed ISO; for XCP-ng, the user-data to paste into Xen
  Orchestra.
- **OS installation is a gated skill.** `hostwarden-os-install` covers
  replacing an OS, dual-boot, EFI boot entries, cloud images and
  partition staging. Its destructive steps need an explicit request, a
  verified backup and a session started with the guard off. Reading,
  diagnosing and boot-entry changes work with the guard on.

### Moving over from Heinzel

- **A Heinzel installation can be taken over.**
  `/hostwarden-heinzel-takeover <path>`, or "take my Heinzel in ~/heinzel
  over", copies the access lists, overrides, host keys and every
  server's memory into the workspace, merges `user.md` line by line and
  sorts the rest of the old `memory/` with one question. It can run
  host by host. The copies Heinzel kept of files it deployed are
  rebuilt as masters, and a file holding credentials stays behind. It
  names every link in the old `memory/`, reads through none below its
  top level, and copies a top-level one only after you agree. It then
  onboards each host read-only, unless you choose to only copy
  (`docs/operations.md` → Moving over from Heinzel).
- **What Heinzel left on a host is found and offered.** Where Heinzel
  was in use, the first connection looks for its backups, scratch
  directories, scripts, units and scheduled jobs. It offers to take
  them over under the new names, keep the old names, or leave them.
  Before moving backups it says which of them retention would then
  delete. Renaming finds and rewrites every reference first, on macOS
  too.
- **Both tools can work on the same hosts during the switch.**
  `contrib/heinzel-coexistence/` holds overrides for a Heinzel checkout
  so that it reads both journal tags, leaves Hostwarden's files alone
  and treats its memory as a lead. A `heinzel` journal entry minutes
  old counts as a live session on the host.

### Smaller changes

- **An MTA Hostwarden installs queues the mail.** It picks a spooling
  agent — nullmailer, dma or postfix as a null client — so a relay that
  is down for a minute does not lose a report. `msmtp` is installed
  only when asked for, or on a host that is recreated rather than
  repaired. `mail` or `mailx` alone no longer counts as a way to
  send: the message goes through `sendmail` or `msmtp`.
- **The email skill loads in stages.** Each step reads its own part
  when it gets there, and each part has its own override.

### For contributors

- **`sh scripts/check.sh` runs everything CI runs**, and CI runs
  nothing else. That covers the guard fixture matrices, the instruction
  layout test (pointers that must resolve, the 80-column wrap, example
  names), ShellCheck, actionlint and a secret scan of the history.
  Opt-in git hooks run the secret scan before each commit and the
  checks before each push. `mise.dev.toml` pins the tools, and Renovate
  keeps them and the pinned Actions current.
- **`main` is protected by `.github/rulesets/main.json`**: pull
  requests only, squash merges, and the green `check` job.
- **Every text file checks out with LF**, and `.editorconfig` carries
  the settings into the editor.
- **Examples name nobody real.** Hostnames, addresses and people in
  the instructions come from the reserved documentation ranges and the
  Alice-and-Bob convention, and the layout test enforces what a pattern
  can decide.
- **Pull requests get two reviews:** the `hostwarden-reviewer`
  subagent in Claude Code (a fresh session elsewhere), then a second
  reviewer of another model family (`.claude/rules/pull-requests.md`).
