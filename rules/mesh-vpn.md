# Mesh VPNs and Tunnels

Servers spread over sites, clouds and home offices are often
joined by a mesh VPN rather than a company network: people reach
them through it, and they reach each other. This file says how to
tell which VPN or tunnel a host is in, whether it is connected,
when its login expires, and what cuts a host off it. The SSH
servers some agents bring are the security audit's
(`.agents/skills/hostwarden-security/references/vpn-ssh.md`).

## When

- The network probe (`rules/network-probe.md`) shows a VPN
  interface or agent.
- A change is about to cut or restart a VPN this session came in
  on (`rules/ssh-safety-net.md` → Which way in).
- Before stopping, restarting, upgrading or reconfiguring an
  agent, or changing the firewall on its interface.
- The user asks about the VPN.

## Probe (no root)

The agents first, one `<pid> <program>` line each. The security
audit runs this block alone for the agents that serve SSH
themselves (`.agents/skills/hostwarden-security/references/ssh.md`
→ SSH servers past sshd):

```bash
a='tailscaled|headscale|netbird|zerotier-one|nebula|dnclient'
a="$a|newt|cloudflared|wireguard-go|netclient|openvpn"
a="$a|charon(-systemd)?"
ps -Ao pid=,comm= 2>/dev/null \
  | sed -E 's|^[[:space:]]+||; s|^([0-9]+)[[:space:]]+.*/|\1 |' \
  | grep -E "^[0-9]+ ($a)$"
```

`comm` is the program each PID runs, never a command line, so a
`vim /etc/nebula` is not a hit, and no argument is printed, since
one can hold a token (`rules/secrets.md`). `ps -Ao pid=,comm=`
runs on Linux, Alpine's BusyBox, FreeBSD and macOS, where `comm`
is a full path that the `sed` reduces to the program. Where `ps`
takes neither `-A` nor `-o` — OpenWrt's BusyBox
(`rules/busybox.md`) — run plain `ps w` instead and read the PID
and the program out of its columns; what reads these lines needs
both.

Then, in the same call, the overlay interfaces and what the
agents' own CLIs report:

```bash
o='(wg|tailscale|ts|zt|nebula|netmaker|wt|utun|tun)[0-9a-z.-]*'
for i in $({ ip -br link 2>/dev/null || ip link show 2>/dev/null \
             || ifconfig -l 2>/dev/null; } \
           | grep -oE "$o" | sort -u); do
  echo "== $i"
  { ip -br addr show dev "$i" 2>/dev/null \
    || ip addr show dev "$i" 2>/dev/null \
    || ifconfig "$i" 2>/dev/null; } | grep -E 'inet|flags|UP'
done
ls -d /Applications/Tailscale.app /Applications/WireGuard.app \
  2>/dev/null
if command -v tailscale >/dev/null 2>&1; then
  tailscale ip 2>&1
  tailscale status --json --peers=false 2>&1 \
    | grep -e '"BackendState"' -e '"Online"' -e '"KeyExpiry"' \
      -e '"Expired"'
  tailscale debug prefs 2>&1 | sed -n '/"ControlURL"/p;
    /"AdvertiseRoutes": null/p; /"AdvertiseRoutes": \[\]/p;
    /"AdvertiseRoutes": \[$/,/]/p'
fi
if command -v netbird >/dev/null 2>&1; then
  netbird status 2>&1 | grep -e '^Daemon' -e '^Management' \
    -e '^Signal' -e '^NetBird IP' -e '^Session expires' \
    -e '^Peers count'
fi
```

BusyBox `ip` has no `-br`, hence the fallbacks. Kernel WireGuard
has no process, so the loop finds the overlay interfaces by name
(wg-quick's `wg0`, Netmaker's `netmaker`, NetBird's `wt0`,
Tailscale's `tailscale0`) and prints each one's addresses, which
is what ties this session's `SSH_CONNECTION` address to a VPN.
On macOS the names say little (`utun*`) and the `ls` finds the
apps instead.

An agent inside a container with its own network namespace shows
its process but not its interface or CLI. Name the container
(`docker ps` or `podman ps`, root) and leave its state
unchecked. Agents this probe does not know — Firezone, Twingate
and others — are recorded when the user names them.

## Per agent

**Connected** means the agent reaches its control plane, not that
it runs. An expiry on a server is usually a forgotten setting:
name it, and tell the user when it falls within 7 days.

- **Tailscale:** connected with `BackendState` `Running` and
  `"Online": true`; `NeedsLogin`, `NeedsMachineAuth`, `Stopped`
  or `"Expired": true` are not. Expiry: `KeyExpiry`. A
  `ControlURL` other than `controlplane.tailscale.com` or
  `login.tailscale.com` is self-hosted, usually Headscale; ask
  the user rather than guess. An `AdvertiseRoutes` list makes the
  host a subnet router, with `0.0.0.0/0` and `::/0` an exit node.
- **NetBird:** connected with `Management: Connected` and
  `Signal: Connected`; `Daemon status` `NeedsLogin`,
  `LoginFailed` or `SessionExpired` is not. Expiry:
  `Session expires`.
- **WireGuard** (wg-quick, systemd-networkd, NetworkManager,
  wg-easy, Netmaker): no connected state and no expiry. With
  root, plain `wg show` prints peers, endpoints, allowed IPs and
  the last handshake, and hides the keys; other `wg` subcommands
  may print them. Without `persistent keepalive`, an old
  handshake only means no recent traffic. A hub is a peer every
  host has, with a fixed endpoint.
- **ZeroTier**, root: `zerotier-cli info` says `ONLINE`
  (`TUNNELED` is online over the slow TCP relay), and
  `zerotier-cli listnetworks` shows `OK` per network;
  `ACCESS_DENIED`, `NOT_FOUND`, `REQUESTING_CONFIGURATION` or
  `AUTHENTICATION_REQUIRED` are not connected.
- **Nebula** and Defined Networking's `dnclient`: no status
  command; the logs show whether handshakes succeed. Expiry: the
  host certificate's `notAfter`, root:
  `nebula-cert print -path /etc/nebula/host.crt`.
- **Newt** (Pangolin) and **Cloudflare Tunnel** (`cloudflared`):
  no status command; their logs say.
- **OpenVPN, strongSwan:** usually site-to-site or
  hub-and-spoke; record them like WireGuard.

Where the policy that admits peers lives decides who may change
it:

- **With the control plane** for Tailscale and Headscale, the
  NetBird dashboard, the ZeroTier controller, the Pangolin
  server and Cloudflare. Hostwarden reads what the host shows of
  it and never changes it there: one change reaches every host
  at once, and it is the user's to make.
- **On the host** for Nebula, whose `firewall` rules and `sshd`
  block sit in this node's configuration file, and for
  WireGuard, whose peers and their `AllowedIPs` sit in its own:
  an ordinary configuration change on one machine. Nebula's
  lighthouses and the CA it trusts are not, so admitting a host
  to the network stays with the network.

## What cuts a host off

Stopping, restarting or upgrading the agent, taking it down, a
policy or ACL change on the control plane, a change to a
host-local `firewall` block, a firewall change on its interface,
an expiry. Where this session or other hosts
depend on the VPN — a subnet router, a WireGuard hub, a Nebula
lighthouse, a Headscale server — say so before the change, and
handle it as a change that can cut SSH
(`rules/ssh-safety-net.md`).

## Memory

Per host, a `## Mesh VPN` section in
`memory/servers/<hostname>/network.md`, created with this section
alone when the host has no profile yet. One line per agent, also
when it is down, so a change shows:

```markdown
## Mesh VPN
- Tailscale 1.102.4, 100.101.102.103, connected, control
  Headscale hs.example.com, no key expiry, routes 10.0.0.0/24
- WireGuard wg0 10.8.0.5, hub vpn.example.com
- NetBird 100.92.1.7, not connected (SessionExpired)
```

Mark what needed root and was not read as `unchecked`. The
`- Network:` line in `memory.md` names the agents
(`rules/network.md` → Where it goes).

The network itself — agent, control server, where the policy
lives, subnet routers and what they route — goes into
`memory/network.md`, one entry per network. Whether the
workstation is in it goes into `memory/user.md`, which is
personal.
