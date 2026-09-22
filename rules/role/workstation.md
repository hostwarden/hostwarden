# Workstation

For a machine whose memory says `Role: workstation`
(`rules/os-detection.md` → Roles): a machine a person works
at. It sleeps, changes networks and reboots when its owner
decides, and the person in front of it owns what is in their
home directory.

What a role file may change is in `rules/os-detection.md` →
Layers. `AGENTS.md` → Critical Safety Rules applies in full: a
workstation still gets asked before a reboot, a service
restart or a firewall change.

## Standing Expectations

On this machine, replaces the standing expectations under
`AGENTS.md` → Where the Rest Lives.

- **Automatic security updates** are expected, through the
  OS's own updater: the Software Update settings on macOS
  (`rules/os/macos.md`), and on a Linux desktop whatever the
  family file names or the desktop's own updater set to
  install on its own. Read its setting before calling it
  off. Missing → **WARN**, as on a server.
- **Automatic reboots after updates** are expected to be off.
  A reboot the owner did not start loses their open work.
  On → **WARN**.
- **A firewall**: the OS's own counts — the Application
  Firewall on macOS, ufw or firewalld on a Linux desktop, and
  whatever the platform file names. Off → **INFO** while
  nothing listens beyond loopback, **WARN** when something
  does: the machine changes networks, and the next one is
  not the network it was set up behind. Where the platform
  file rates the firewall itself, its rating stands.

## Reachability

A workstation that does not answer is usually asleep, switched
off or somewhere else. That changes two rules:

- `rules/ssh-unreachable.md`: the single retry stands. After
  it, say in one line that the workstation is not reachable
  and stop; the diagnosis under Target or path? does not
  apply. Never wake it without being asked.
- `rules/dns-aliases.md` → IP Verification: an address that
  no longer overlaps memory is expected, not a reason to
  stop. Connect as usual. When the host key verifies,
  update `- IP:` and say so in one line; a host-key
  mismatch still stops the session.

## The Owner's Things

Adds to `rules/best-practices.md`.

- **The home directory is the owner's.** Their files,
  `~/Library`, browser profiles and dotfiles are read to
  diagnose, never tidied, moved or deleted without being
  asked.
- **Tools the owner installs as themselves are theirs**:
  Homebrew, mise, pipx and the like. Upgrade them only when
  asked.
- **In local mode, the session runs on this machine.** A
  reboot ends it, and restarting the network, the SSH agent
  or the display manager can end it or the owner's desktop.
  Say which before asking.

## Housekeeping and Audits

- **Housekeeping:** outdated packages of a tool the owner
  installs as themselves (see The Owner's Things) are
  **INFO**, not WARN. Uptime is not a finding. Two reads
  back the ratings under Standing Expectations:
  - the listening services, with the commands of
    `.agents/skills/hostwarden-security/references/listening-services.md`,
    for the firewall rating;
  - the automatic reboot: `Unattended-Upgrade::Automatic-Reboot`
    from `apt-config dump` on the Debian family, `reboot` under
    `[commands]` in `/etc/dnf/automatic.conf` on the RHEL family,
    and on macOS `AutomaticallyInstallMacOSUpdates`, since
    installing a macOS update restarts the Mac. Elsewhere, say
    it was not checked.
- **Security audit:** `references/intrusion-prevention.md`
  does not apply. Every service listening beyond loopback
  is a finding to report with its process, for the reason
  under Standing Expectations.
- **Fleet audit:** a workstation is compared only with other
  workstations; where it differs from a server, that is not
  drift. One that does not answer goes on a
  "skipped: offline (workstation)" list, not "unreachable".
  The uptime criterion does not apply.
