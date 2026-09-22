# SSH Servers in VPN Agents

Read when `references/ssh.md` → SSH servers past sshd finds an
agent. These logins never touch `sshd_config`, `authorized_keys`,
sshd's CA trust, fail2ban, the sshd log or `last`.

| Agent | Its SSH | Closing port 22 stops it |
|---|---|---|
| Tailscale | own server, port 22 of the tailnet address | no |
| NetBird | own server; nftables redirects 22 to 22022 | no, own rule |
| Pangolin's Newt | own server | no |
| Nebula | admin console on `sshd.listen`, no shell | its own port |
| Cloudflare Tunnel | publishes the host's sshd | no, outbound |

## Probe (no root)

Only the lines for the agents found:

```bash
# tailscaled
tailscale debug prefs 2>&1 | grep -e '"RunSSH"' -e '"OperatorUser"'
# netbird
netbird status 2>&1 | grep -e '^SSH Server' -e '^Profile'
# newt
ps ax -o args= | grep -cE -- '^[^ ]*newt( .*)? --?disable-ssh( |=|$)'
# cloudflared
ps ax -o args= | grep -cE -- '^[^ ]*cloudflared( .*)? --?token( |=|$)'
grep -Hn 'ssh://' /etc/cloudflared/*.y*ml \
  /usr/local/etc/cloudflared/*.y*ml ~/.cloudflared/*.y*ml 2>/dev/null
```

The `grep -c` lines count, never print (`rules/secrets.md`); the
anchor on the program name keeps the probe's own command line out
of the count. Both programs take a flag with one dash or two, and
`--token-file`, the safe form, is not a match.

An agent inside a container with its own network namespace shows
its process but not its CLI; name the container and mark its SSH
server unchecked.

## Probe (root)

Tailscale with `"RunSSH": true`, NetBird unless its `SSH Server`
line says `Disabled`, Nebula whenever it runs, and Newt when the
`--disable-ssh` count was 0:

```bash
# Tailscale, "RunSSH": true — the rules compiled for this node
T=$(printf '\t')
tailscale debug netmap 2>&1 \
  | sed -n "/^$T\"SSHPolicy\": null/p; /^$T\"SSHPolicy\": {/,/^$T}/p"
# NetBird, SSH Server not "Disabled" — flags of every profile
grep -rHoE --include='*.json' \
  '"(ServerSSHAllowed|EnableSSH[A-Za-z]*|DisableSSHAuth)": *(true|false)' \
  /var/lib/netbird /var/db/netbird /etc/netbird 2>/dev/null
# Nebula — its admin console
grep -A4 '^sshd:' /etc/nebula/config.yml 2>/dev/null
# Newt on Linux, no --disable-ssh — DISABLE_SSH in its environment
for p in $(pgrep -x newt); do
  tr '\0' '\n' < "/proc/$p/environ" | grep -ciE '^DISABLE_SSH=(true|1)$'
done
```

Print only these fields: the same files hold private keys, and
NetBird's JSON can sit on one line with them, which is why its
grep prints the matches alone (`-o`). The environment holds
Newt's secret, which is why that grep only counts
(`rules/secrets.md`).

**Tailscale.** The netmap format is internal and may change; read
it, do not build on it. Each rule has `principals` (`userLogin` a
person, `nodeIP` a device, `any: true` everyone on the tailnet),
`sshUsers` (requested account → local account) and an `action`
(`accept: true` admits at once; `holdAndDelegate` is check mode,
where the person confirms with the identity provider first;
`recorders` records the session). Root is admitted by
`"root": "root"`, or by `"*": "="` unless the same map has
`"root": ""`. `SSHPolicy: null` with `RunSSH` on admits nobody.
Only the open-source `tailscaled` serves SSH on macOS; the App
Store and standalone apps cannot.

**NetBird.** The active profile is the file named by the
`Profile:` line (`default.json` for `default`). `EnableSSHRoot`
admits root; `DisableSSHAuth` drops the OIDC login, so any peer
the network policy lets through gets in with no person behind the
login.

**Newt** runs SSH unless started with `--disable-ssh` or with
`DISABLE_SSH` in its environment, which only the root probe sees.
It creates the local accounts it admits, with sudo rules in
`/etc/sudoers.d/90-pangolin-<user>`: list both.

## Findings

One report line per agent found, as `VPN SSH`:

- Tailscale: root admitted by `accept` → **WARN**; for
  `any: true` principals → **CRITICAL**. Another account for
  `any: true` → **WARN**
- NetBird: `EnableSSHRoot` and `DisableSSHAuth` both `true` →
  **CRITICAL**; either one alone → **WARN**
- Cloudflare Tunnel token in `ps` arguments → **WARN**, readable
  by every account (`rules/secrets.md`)
- Newt SSH on → **INFO**, with the accounts and sudo files it
  made. Without root, or with Newt in a container, it is
  **INFO** "Newt SSH unchecked": the environment may turn it off
- Nebula `sshd.enabled: true` → **INFO**, name `listen` and
  `authorized_users`
- Cloudflare ingress to `ssh://` → **INFO**: sshd is reachable
  through Cloudflare, and Cloudflare Access decides who
- Tailscale `OperatorUser` set → **INFO**, name the account: it
  can turn SSH on without root
- Policy not readable from the host (Tailscale without root,
  NetBird always) → **INFO** "policy not checked"; ask the user
  for it
- An agent found without an SSH server of its own → OK

The policy that admits people lives in the Tailscale admin
console, Headscale, the NetBird dashboard or the Pangolin server.
Never change it from here: it applies to every host at once.
