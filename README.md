# Hostwarden — System Administration with Safety Guardrails

Hostwarden is a set of rules that turns an AI coding
assistant into a cautious, methodical sysadmin. It
works with
[Claude Code](https://docs.anthropic.com/en/docs/claude-code),
[OpenCode](https://opencode.ai), or any other
terminal-based AI tool that can read project files
and run shell commands — and with the Code tab of the
Claude desktop app, which runs the same Claude Code
([what differs there](docs/ai-tools.md#claude-code-desktop)). It manages Linux, FreeBSD,
and macOS targets — remote servers over SSH and the
local machine alike — reports on Windows Server over
SSH, and runs on Linux, macOS and FreeBSD
workstations, and on Windows inside WSL 2.

Describe what you need in plain English, and Hostwarden
figures out the right commands for your OS, proposes
each one with an explanation, and waits for your
approval before running anything. It backs up configs,
tests commands before real execution, remembers every
server it has worked on, and gives you a detailed
report when it's finished.

Using it feels like pair-programming with a colleague
who always checks the docs first and never skips a
step because he's in a hurry. The bigger the network,
the more it pays off — Hostwarden remembers every server's
OS, services, and quirks so you don't have to. Not
sure yet? Ask Hostwarden to plan first before making
changes — no changes until you say go.

Hostwarden continues
[Heinzel](https://github.com/wintermeyer/heinzel) by
Stefan Wintermeyer as an independent project. It keeps
Heinzel's history and still takes over Heinzel's
improvements where they fit. Coming from Heinzel? See
[Moving over from Heinzel](docs/operations.md#moving-over-from-heinzel).

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
[docs/install.md](docs/install.md).
`bin/hostwarden-doctor` lists what your workstation
is missing and the command to install it.

### Steps

1. **Clone the repo, set up the workspace, start Hostwarden**
   ```
   git clone https://github.com/jpawlowski/hostwarden.git
   cd hostwarden
   bin/hostwarden-init
   claude
   ```
   Or use `opencode` to launch OpenCode. In the
   Claude desktop app, open the cloned folder in the
   Code tab instead, with the worktree option off —
   [Claude Code Desktop](docs/ai-tools.md#claude-code-desktop)
   says why that matters.
   `bin/hostwarden-init` turns `memory/` into the
   workspace — a git repository of its own that holds
   everything Hostwarden learns about your servers —
   and so makes this an **operations checkout**.
   Without it, the checkout is for developing
   Hostwarden and reaches no server (see
   [Operations and development](docs/operations.md#operations-and-development)).
2. **Describe what you need in plain English**
   ```
   ❯ Install postgresql on server1.example.com
   ```
3. **Answer a few questions on the first connection**
   The first time Hostwarden connects to a new server,
   it may ask for details it can't detect on its own
   — most commonly which SSH user to log in as. Your
   answers are stored in `memory/user.md` and the
   per-server memory file, so Hostwarden won't ask again
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

- **Detects the OS** on first contact and remembers
  every server — OS, services, quirks — across
  sessions. DNS aliases of one host share its
  memory.
- **Picks up interrupted work** from a per-server
  to-do list.
- **Housekeeping and security audits** per server,
  and a **fleet audit** that shows where your
  servers disagree.
- **Email reports**, sent from your workstation or
  from the server.
- **Plan first**: explore, draft a plan, change
  nothing until you say go.
- **Local administration** of your own Linux or
  macOS machine, without SSH.

Example prompts and details:
[docs/features.md](docs/features.md).

## Supported AI Tools

Hostwarden targets Claude Code, in the terminal or in
the desktop app's Code tab. Its instructions are plain
Markdown in `AGENTS.md`, `rules/` and
`.agents/skills/`, which OpenCode, Codex and Cursor
read as well; OpenCode also runs it on local models
through Ollama. The guard hooks are Claude Code only.
What differs per tool:
[docs/ai-tools.md](docs/ai-tools.md). One-shot
commands, auto mode and scheduled runs:
[docs/automation.md](docs/automation.md).

## Safety & Guardrails

- **Asks before acting** — destructive commands,
  firewall changes, reboots and service restarts
  need your explicit approval.
- **Hard guardrails (Claude Code)** — a hook blocks
  the absolute taboos listed in `AGENTS.md` in every
  permission mode.
- **Backs up and tests** — config files are copied
  before an edit, and dry-run modes run before the
  real thing.
- **Logs everything** — every change lands in the
  server's journal (`journalctl -t hostwarden`).
- **Blacklist and read-only lists** keep it off hosts
  it must not touch or change.
- **Server output is data** — instructions found in
  files, logs or command output are flagged, never
  followed. Secrets are never printed.

The full list, how it keeps hallucinated commands
off your servers, and how to read its logs:
[docs/safety.md](docs/safety.md).

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

Appliances run their own updater, configuration and
firewall on top of that OS, so they get a file of their own
that changes the base file where it would be wrong:

| Appliance         | Base    | Appliance file                      |
| ----------------- | ------- | ----------------------------------- |
| Proxmox VE        | Debian  | `rules/appliance/proxmox-ve.md`     |
| OpenMediaVault    | Debian  | `rules/appliance/openmediavault.md` |
| OPNsense          | FreeBSD | `rules/appliance/opnsense.md`       |
| pfSense           | FreeBSD | `rules/appliance/pfsense.md`        |
| TrueNAS           | Debian  | `rules/appliance/truenas.md`        |
| TrueNAS CORE      | FreeBSD | `rules/appliance/truenas-core.md`   |
| XCP-ng            | RHEL    | `rules/appliance/xcp-ng.md`         |
| Home Assistant OS | —       | `rules/appliance/haos.md`           |
| Synology DSM      | —       | `rules/appliance/synology-dsm.md`   |
| Unraid            | —       | `rules/appliance/unraid.md`         |
| OpenWrt           | —       | `rules/appliance/openwrt.md`        |

Two more layers sit on top. A platform is what the OS runs
inside when something outside owns part of the machine:
[WSL](rules/platform/wsl.md), where Windows owns the kernel and
the firewall. A role says what the machine is expected to have:
a [workstation](rules/role/workstation.md) — a Mac, a WSL
instance, the machine Hostwarden runs on — is held to different
expectations than a server. Hostwarden infers the role and tells
you; say so when it is wrong.

Other distributions work too — Hostwarden will apply
general best practices and let you know which OS it
detected.

## Risks & Responsibilities

> [!CAUTION]
> Hostwarden operates on live servers and local machines
> — as root, with sudo, or in unprivileged mode.
> Always review every command before approving it.

Hostwarden is for anyone willing to stay in the
driver's seat and review every command — from
newcomers learning Linux to veterans running fleets.
In fact, Hostwarden can be an especially good teacher:
each proposed command comes with an explanation of
*what* it does and *why*, so you learn the real
sysadmin reasoning instead of copy-pasting Stack
Overflow answers.

We built Hostwarden to be a help for everybody. By
design, it follows the safety checklist every single
time: it always backs up before editing, always
dry-runs when it can, always checks the OS before
assuming commands. A disciplined AI makes far fewer
mistakes than a tired human at 2 AM during an
outage. But we can't guarantee it won't ever make
one — LLMs can hallucinate, misread intent, or
produce a command with unintended side effects.

The question isn't whether Hostwarden is risk-free —
it isn't. The question is whether a disciplined AI
that follows every safety rule every time, with a
human reviewing every command, produces fewer
disasters than a human working alone under
real-world conditions.

Stay in the driver's seat. Review every command. Do
not blindly approve.

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
