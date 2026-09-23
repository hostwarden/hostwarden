---
name: hostwarden-security
argument-hint: "[hostname]"
description: Run a Hostwarden security audit on a server — SSH
  hardening (password auth, weak algos, root login), firewall,
  user account hygiene, listening services, kernel hardening
  (ASLR, IP forwarding), file permissions, SUID/SGID audit,
  fail2ban. Use when the user asks for a "security audit",
  "security review", "hardening check", "Sicherheitsaudit",
  "prüf die Härtung", or to "audit security on <host>". Do NOT
  auto-invoke on generic phrases like "check server <host>".
  Covers Linux (Debian, Ubuntu, RHEL, CentOS, Fedora, SUSE,
  Alpine), FreeBSD, macOS (SIP, FileVault, Gatekeeper) and
  Windows Server (read-only; SSH, firewall, accounts, SMBv1,
  Remote Desktop, Defender, BitLocker).
---

# hostwarden-security

Security configuration audit for a server or the local machine.
**Never run automatically** — only on explicit user request. The
whole of the Hostwarden first-connection onboarding pipeline still
applies before any of this runs.

## Workflow

1. **Load overrides**, key `hostwarden-security`, per
   `rules/overrides.md`. Read
   `memory/servers/<hostname>/memory.md` for context: services,
   legitimate external bindings, VPN role. A binding this host is
   known to need is not a finding. An override of
   `rules/baseline.md` → Firewall or SSH Login changes what the
   firewall and SSH checks below expect.
2. **Run checks in 2–3 parallel batches** for speed — not one
   massive batch. If a single parallel tool call errors, Claude
   Code cancels sibling calls, so grouping limits blast radius.
   Put commands with complex quoting (awk, sed) in their own batch
   so a quoting mistake does not cancel simple commands.
3. **Probe shape:** no taboo word as data (the guard denies the
   whole batch), no `!` (zsh mangles it over SSH), and report
   what you do not recognize instead of printing only what you
   expect. The System Accounts check in
   `references/user-accounts.md` shows all three.
4. **Select checks** per the references below. Use the preferred
   method when privileges allow; fall back to the unprivileged
   method otherwise.
5. **Emit the report** using the format in
   `references/report-format.md`.
6. **Do NOT update `memory.md`**, with one exception. These are
   config observations, not state changes: memory tracks what is
   installed and running, not security posture details. The
   exception is the `Management:` line and its address, which are
   inventory rather than posture — where this audit is what first
   settled them, record them as
   `rules/management-controller.md` → What to record says.
7. **Log the summary** to the system journal and mirror to the
   local changelog per `rules/changelog.md`, which names the
   writer; on a host with `logger`:

       logger -t hostwarden "[<operator> as <unix-user>] \
       Security audit: 1 WARN, 1 INFO"

## Scope and limits

- Several hosts in one request run as `rules/multi-host.md` says,
  which follows this skill for each host.
- Linux (Debian, Ubuntu, RHEL, CentOS, Fedora, SUSE, Alpine),
  FreeBSD and macOS are covered by the references below; each
  one has a section per family where the commands differ.
- A reference written for `sh` runs only where the loaded OS
  file uses the `sh -s` bundle (`rules/ssh-connections.md` →
  Bundle commands); elsewhere, as on Windows Server, the OS
  file's `## Housekeeping and Audits` section is the whole
  audit.

## Cross-references

**Automatic security updates** are checked during housekeeping
(see `hostwarden-housekeeping` skill), and so are known-vulnerable
packages (`pkg audit` on FreeBSD). This audit does not duplicate
those checks.

## References

Read on demand, only when the relevant section applies:

- `references/report-format.md` — required output format and
  severity rules (CRITICAL / WARN / INFO).
- `references/ssh.md` — SSH password auth, root login, weak
  algorithms, MaxAuthTries, X11Forwarding.
- `references/firewall.md` — Linux (ufw / firewalld), FreeBSD
  (pf / ipfw) and macOS (Application Firewall).
- `references/firewall-nftables-docker.md` — native nftables without
  ufw or firewalld, iptables-legacy rules next to nf_tables,
  Docker ports published past the firewall.
- `references/vpn-ssh.md` — only when `references/ssh.md` → SSH
  servers past sshd finds an agent: Tailscale, NetBird, Newt,
  Nebula or Cloudflare Tunnel.
- `references/containers.md` — Docker, Podman and containerd:
  the API on TCP, root-equivalent groups, privileged containers,
  capabilities, host namespaces, the engine socket and host paths
  mounted in, confinement, root users, credential-like environment
  names, registries. Whenever an engine is present.
- `references/user-accounts.md` — empty passwords, multiple UID
  0, system accounts with login shells.
- `references/listening-services.md` — audit `ss` / `lsof`
  output, flag databases on 0.0.0.0, open DNS resolvers and
  exposed Pi-hole or AdGuard Home web interfaces.
- `references/kernel-os.md` — sysctl checks: ASLR, IP forwarding,
  ICMP redirects, SUID core dumps.
- `references/file-permissions.md` — world-writable system files,
  SUID/SGID audit, /tmp mount options, cron perms, unowned files.
- `references/intrusion-prevention.md` — fail2ban, and
  blocklistd or sshguard on FreeBSD.
- `references/macos-security.md` — SIP, FileVault, Gatekeeper.
- `references/management-controller.md` — the `Management:` line
  on every host, and on a bare-metal one the controller's own
  network, IPMI over LAN, cipher suite 0, factory and anonymous
  accounts, Intel AMT.
- The `## Housekeeping and Audits` sections of the host's
  family, appliance, platform and role files, already loaded
  by the pipeline (`rules/os-detection.md` → Layers).
- `references/unprivileged.md` — which checks work without root,
  which need it, and how to report skipped ones.
