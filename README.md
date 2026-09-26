<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/hostwarden/brand/main/svg/hostwarden-lockup-invers.svg">
  <img alt="Hostwarden" src="https://raw.githubusercontent.com/hostwarden/brand/main/svg/hostwarden-lockup.svg" width="360">
</picture>

# Hostwarden — System Administration with Safety Guardrails

Hostwarden is a set of rules that turns an AI coding
assistant into a cautious, methodical sysadmin. It
works with
[Claude Code](https://docs.anthropic.com/en/docs/claude-code),
[OpenCode](https://opencode.ai), or any other
terminal-based AI tool that can read project files
and run shell commands — and with the Code tab of the
Claude desktop app, which runs the same Claude Code
([what differs there](https://hostwarden.github.io/docs/getting-started/ai-tools#claude-code-desktop)).
It manages Linux, FreeBSD and macOS targets — remote
servers over SSH and the local machine alike —
reports on Windows Server over SSH, and runs on
Linux, macOS and FreeBSD workstations, and on Windows
inside WSL 2.

Describe what you need in plain English. Hostwarden
works out the commands for the OS it detected,
explains each one, and waits for your approval before
running it. It backs up configs, dry-runs where a tool
can, and remembers every server it has worked on. Not
sure yet? Ask it to
[plan](https://hostwarden.github.io/docs/features/changes/plan-mode) first: nothing
changes until you say go.

Hostwarden continues
[Heinzel](https://github.com/wintermeyer/heinzel) by
Stefan Wintermeyer as an independent project. It keeps
Heinzel's history and still takes over Heinzel's
improvements where they fit. It lives in the GitHub
organization `hostwarden`, because GitHub offers the
merge queue to a public repository only when an
organization owns it.
Coming from Heinzel? See
[Moving over from Heinzel](https://hostwarden.github.io/docs/running-it/heinzel).

## Screencast: Debug and fix some webserver problems

![Screencast: Debug and fix some webserver problems](assets/webshop-bugfix-example.gif)

Recorded with Heinzel, before the rename — a
Hostwarden session looks the same.

## How to Install

### Prerequisites

- An AI coding assistant: Claude Code, OpenCode, or
  the Claude desktop app's Code tab
- jq
- Key-based SSH access to the target, without a
  password or passphrase prompt
- Linux, FreeBSD or macOS on the target, or Windows
  Server, where Hostwarden reports and, when asked,
  installs PowerShell 7 and sets it as the SSH shell
- A checkout with working symbolic links
- On Windows: WSL 2

What each one is for, and the Windows setup:
[the installation guide](https://hostwarden.github.io/docs/getting-started/install).
`bin/hostwarden-doctor` lists what your workstation
is missing and the command to install it.

### Steps

1. **Clone the repo, set up the workspace, start Hostwarden**
   ```
   git clone https://github.com/hostwarden/hostwarden.git
   cd hostwarden
   bin/hostwarden-init
   claude
   ```
   Or use `opencode` to launch OpenCode. In the
   Claude desktop app, open the cloned folder in the
   Code tab instead, with the worktree option off —
   [Claude Code Desktop](https://hostwarden.github.io/docs/getting-started/ai-tools#claude-code-desktop)
   says why that matters.
   `bin/hostwarden-init` turns `memory/` into the
   workspace — a git repository of its own that holds
   everything Hostwarden learns about your servers —
   and so makes this an **operations checkout**.
   Without it, the checkout is for developing
   Hostwarden and reaches no server (see
   [Working on Hostwarden](https://hostwarden.github.io/docs/development)).
   Once a release exists, the operations checkout
   follows its major line and moves to each new
   release on it; `bin/hostwarden-update --unpin`
   follows `main` instead (see
   [Updates and versioning](https://hostwarden.github.io/docs/running-it/setup/updates)).
2. **Describe what you need in plain English**
   ```
   ❯ Install postgresql on server1.example.com
   ```
3. **Answer a few questions on the first connection**
   The first time Hostwarden connects to a new server,
   it may ask for details it can't detect on its own
   — most commonly which SSH user to log in as. Your
   answers are stored in `memory/user.md` and the
   per-machine memory file, so Hostwarden won't ask again
   on future sessions. You can also pre-fill
   `memory/user.md` by copying
   `templates/memory/user.md.example` and editing
   it — this is also where you set a
   preferred language (e.g. `Language: German`).
4. **Review and approve each command before it runs**
   Hostwarden proposes every SSH command, explains what
   it does and why, and waits for your approval.
   Nothing runs without your say-so.


## What It Does

Every remote connection runs the same pipeline before
the first command: the blacklist and read-only lists,
the host key, OS detection, the machine's memory and
what happened on it since the last session. Local mode
skips the remote-only steps. Example prompts for
everything below: [the Features page](https://hostwarden.github.io/docs/features).

- **Asks, backs up, and can undo a lockout.**
  Destructive commands, firewall and network changes,
  reboots and service restarts need your approval; a
  firewall or network change reverts itself if it locks
  remote access out. The absolute taboos — partition
  tables, disk erases, storage repair, sshd's
  configuration and keys, power-off — are hard-blocked
  in Claude Code, and are instructions elsewhere.
  [Safety and guardrails](https://hostwarden.github.io/docs/safety)
- **Remembers, and shares with your team.** Each
  server's OS, services, quirks and open work live in
  `memory/`, a git repository of its own. Every change
  leaves a line in the server's system log
  (`journalctl -t hostwarden`) and in your local
  changelog. A team shares the workspace through a
  private remote — host memory, host keys, decisions,
  the masters of deployed files — and sessions that
  change the same host see each other.
  [A shared workspace](https://hostwarden.github.io/docs/running-it/team/shared-workspace)
- **Holds every server to a written baseline.** A
  default-deny firewall, security updates, time sync,
  key-only remote access, storage maintenance, a backup
  and more. Onboarding reports what a host lacks,
  read-only; bringing it up to the baseline goes one
  asked step at a time.
  [Server baseline](https://hostwarden.github.io/docs/features/checks/baseline)
- **Works on many hosts at once.** One question,
  check or change on several servers prints identical
  answers once, so the outlier stands out. A change is
  asked once, runs on a canary first and stops at the
  first surprise. The fleet audit compares policies
  across your servers and shows where they drift.
  [Several servers](https://hostwarden.github.io/docs/features/fleet/multi-host)
- **Knows your hypervisors and their guests.** On
  Proxmox VE, XCP-ng, libvirt, Incus, LXD, LXC,
  vm-bhyve, Hyper-V, VirtualBox and FreeBSD jails it
  lists every guest and gives each one it can enter
  memory of its own. On Proxmox VE, libvirt, Incus,
  LXD and classic LXC, new VMs and containers start
  from an official image with the baseline at first
  boot.
  [Guests and hypervisors](https://hostwarden.github.io/docs/features/guests/hypervisors)
- **Respects appliances.** Fifteen of them —
  Proxmox VE, TrueNAS, OPNsense, Synology DSM, UniFi
  OS, Home Assistant OS, OpenWrt and more — get rules
  of their own for the updater, the firewall and the
  settings their web UI owns.
  [Appliances](https://hostwarden.github.io/docs/features/systems/appliances)
- **Checks host keys without a manual login,** and
  uses an SSH CA you already run wherever it sets up
  trust. [SSH access](https://hostwarden.github.io/docs/features/ssh/host-keys)
- **Works alongside Ansible, Puppet or Chef.**
  Hostwarden needs none of them and never pushes for
  one; where a tool manages a host, a change goes into
  that tool's code instead.
  [Configuration management](https://hostwarden.github.io/docs/features/changes/config-management)
- **Runs the nightly check unattended.** An operations
  host reads your servers through a bundle of
  read-only checks you signed, and mails the report.
  Its key can run that bundle and write one journal
  line, nothing else.
  [An operations host](https://hostwarden.github.io/docs/running-it/team/operations-host)

## Supported AI Tools

Hostwarden targets Claude Code; OpenCode, Codex and
Cursor read the same `AGENTS.md` instructions, and
OpenCode also runs it on local models through Ollama.
What differs per tool: [Supported AI tools](https://hostwarden.github.io/docs/getting-started/ai-tools).
One-shot commands, auto mode and scheduled runs:
[Automation and scripting](https://hostwarden.github.io/docs/running-it/unattended/automation).

## Supported Distributions

| Family  | Distributions                     | Reference file        |
| ------- | --------------------------------- | --------------------- |
| Debian  | Debian, Ubuntu                    | `rules/os/debian.md`  |
| RHEL    | RHEL, CentOS, Fedora, Rocky, Alma | `rules/os/rhel.md`    |
| SUSE    | openSUSE, SLES                    | `rules/os/suse.md`    |
| Alpine  | Alpine Linux                      | `rules/os/alpine.md`  |
| macOS   | macOS (Apple Silicon & Intel)     | `rules/os/macos.md`   |
| FreeBSD | FreeBSD (all versions)            | `rules/os/freebsd.md` |
| Windows | Windows Server, mostly read-only  | `rules/os/windows.md` |

Fifteen appliances get a file of their own on top of
that family, a platform file covers WSL, and a Mac, a
WSL instance or the machine Hostwarden runs on is held
to a workstation's expectations rather than a
server's: [Systems it knows](https://hostwarden.github.io/docs/features/systems/overview).
Other distributions work too — Hostwarden applies
general best practices and tells you which OS it
detected.

## Risks & Responsibilities

> [!CAUTION]
> Hostwarden operates on live servers and local machines
> — as root, with sudo, or in unprivileged mode.
> Always review every command before approving it.

Hostwarden follows its safety checklist every time,
but an LLM can still hallucinate, misread intent or
produce a command with side effects nobody intended.
Who it is for, and why a disciplined AI with a human
reviewing it is still worth it:
[Risks and responsibilities](https://hostwarden.github.io/docs/safety).

## Documentation

Every page, grouped by task:
[docs/README.md](docs/README.md).

## Why the Name Hostwarden?

A warden is the person responsible for a place: they
look after it, keep it in order and answer for its
state. Hostwarden does that for your hosts, and you
approve every step.

The project began as
[Heinzel](https://github.com/wintermeyer/heinzel),
named after the
[Heinzelmännchen](https://en.wikipedia.org/wiki/Heinzelm%C3%A4nnchen),
the helpful house spirits of Cologne who did the work
at night. Hostwarden keeps that idea: an invisible
helper that does the tedious work while you review.

## Contributing

Bug reports, feature requests, and pull requests are
very welcome! If you have ideas for better guardrails,
new distro support, or improvements to the safety
rules — please open an issue or submit a PR. See
[CONTRIBUTING.md](CONTRIBUTING.md) and
[SECURITY.md](SECURITY.md).

## License

MIT, © Julian Pawlowski. Hostwarden contains
substantial portions of
[Heinzel](https://github.com/wintermeyer/heinzel) by
Stefan Wintermeyer, whose copyright notice the MIT
terms require this project to keep — both notices are
in `LICENSE`.
