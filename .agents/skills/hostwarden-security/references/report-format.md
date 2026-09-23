# Security Audit Report Format

Use this exact structure for every security audit report.

```
## Security Audit: hostname

Date: YYYY-MM-DD HH:MM
OS: Debian 12 (Bookworm)

### Issues

WARN      SSH allows password authentication
WARN      Tailscale SSH admits root by accept
WARN      deploy (runs myapp) has NOPASSWD ALL
WARN      deploy is a local account with sudo on a directory host
INFO      macOS Application Firewall disabled

### Checks

SSH password auth   WARN — PasswordAuthentication yes
SSH weak algos      OK — no weak algorithms found
SSH root login      INFO — PermitRootLogin yes
SSH client          OK — none in ssh_config, 2 ~/.ssh/config, cron
SSH host cert       OK — presented, CA SHA256:Cxr4…, 23 days left, renewed
                    by ssh-cert-renew.timer
SSH user CA         INFO — no RevokedKeys; root via principal ops
Firewall            OK — ufw active, default deny
VPN SSH             WARN — Tailscale SSH admits root by accept
VPN recorded        OK — Tailscale in network.md, SSH on
Empty passwords     OK — no accounts with empty password
UID 0 accounts      OK — only root
Account source      OK — SSSD, AD example.com, online
Sudo rules          WARN — deploy NOPASSWD ALL; INFO —
                    %sudo NOPASSWD ALL: alice, bob
Local accounts      WARN — deploy (sudo, keys); rescue (sudo,
                    keys) DECIDED — Break-glass account rescue
                    (user, 2026-09-18)
Listening services  OK — no databases on 0.0.0.0
ASLR                OK — randomize_va_space = 2
IP forwarding       OK — disabled
File permissions    OK — no world-writable system files
SUID/SGID binaries  INFO — 14 found (all expected)
fail2ban            INFO — not running
```

## Rules

- **Issues section** only appears if problems exist. Sort by
  severity: CRITICAL first, then WARN, then INFO.
- **One line per item.** Keep it scannable.
- **A finding a decision settles** (`rules/decisions.md` →
  Rating findings) reads `DECIDED — <heading> (<who>, <date>)`
  on its line, never under Issues:
  `Firewall   DECIDED — No local firewall (user, 2026-09-18)`.
- Severity levels:
  - `CRITICAL` — needs immediate attention
  - `WARN` — should be addressed soon
  - `INFO` — informational, not urgent
