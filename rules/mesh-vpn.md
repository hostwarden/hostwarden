# Mesh VPNs and Tunnels

Servers spread over sites, clouds and home offices are often
joined by a mesh VPN rather than a company network: people reach
them through it, and they reach each other. This file says how to
tell which VPN or tunnel a host is in, whether it is connected,
when its login expires, and what cuts a host off it.

## When

- The network probe (`rules/network-probe.md`) shows a VPN
  interface or agent.
- A change is about to cut or restart a VPN this session came in
  on (`rules/ssh-safety-net.md` → Which way in).
- Before stopping, restarting, upgrading or reconfiguring an
  agent, or changing the firewall on its interface.
- The activity check, on every connection, for the logins past
  sshd (SSH servers in agents below).
- A login refused on a path that goes through an agent's SSH
  server.
- The user asks about the VPN.

## Probe (no root)

The agents first, one `<pid> <program>` line each. The security
audit runs this block again inside its own loop, to read each
agent from its process
(`.agents/skills/hostwarden-security/references/vpn-ssh.md` →
Probe (no root)):

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
if [ "$(id -u)" != 0 ]; then
  grep -o 'hidepid=[a-z0-9]*' /proc/mounts 2>/dev/null
  [ "$(sysctl -n security.bsd.see_other_uids 2>/dev/null)" = 0 ] \
    && echo "see_other_uids=0"
fi
PATH=$PATH:/opt/homebrew/bin:/usr/local/bin
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
command -v scutil >/dev/null 2>&1 \
  && scutil --nc list 2>/dev/null | grep -i -e wireguard -e tailscale
ts=$(command -v tailscale)
[ -n "$ts" ] || [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ] \
  || ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
if [ -n "$ts" ]; then
  export TAILSCALE_BE_CLI=1
  "$ts" ip 2>&1
  "$ts" status --json --peers=false 2>&1 \
    | grep -e '"BackendState"' -e '"Online"' -e '"KeyExpiry"' \
      -e '"Expired"'
  "$ts" debug prefs 2>&1 | sed -n '/"ControlURL"/p; /"RunSSH"/p;
    /"AdvertiseRoutes": null/p; /"AdvertiseRoutes": \[\]/p;
    /"AdvertiseRoutes": \[$/,/]/p'
fi
if command -v netbird >/dev/null 2>&1; then
  netbird status 2>&1 | grep -e '^Daemon' -e '^Management' \
    -e '^Signal' -e '^NetBird IP' -e '^Session expires' \
    -e '^Peers count' -e '^SSH Server'
fi
```

A `hidepid=` line other than `hidepid=0` or `hidepid=off`, or
FreeBSD's `see_other_uids=0`, means `ps` showed this user only
its own processes: the agent list is `unchecked`, never empty.
BusyBox `ip` has no `-br`, hence the fallbacks. Kernel WireGuard
has no process, so the loop finds the overlay interfaces by name
(wg-quick's `wg0`, Netmaker's `netmaker`, NetBird's `wt0`,
Tailscale's `tailscale0`) and prints each one's addresses, which
is what ties this session's `SSH_CONNECTION` address to a VPN.
On macOS the names say little (`utun*`), and the apps run network
extensions rather than a process the first block knows. The `ls`
shows an app installed; `scutil --nc list` says whether its
tunnel runs. `(Connected)`, `(Connecting)` and `(Disconnecting)`
are active, `(Disconnected)` is off, and `(Invalid)` or
`(Unknown)` is `unchecked`. Tailscale's own CLI settles it where
`scutil` shows no entry: `BackendState` `Running` is active,
another state off. The WireGuard app keeps one entry per tunnel
and has no CLI: with no entry it has no tunnel set up, which is
off too. The App Store app has no CLI on the `PATH`, so the block
calls the one inside the app, with `TAILSCALE_BE_CLI=1`, which
keeps it from opening the app's window. That CLI answers only the
user whose desktop session runs the app, or an admin for the
standalone app; where it errors and `scutil` gave no state
either, the app is `unchecked`, never off.

A non-interactive SSH session on macOS has neither Homebrew
prefix on its `PATH`, where the open-source `tailscaled`'s and
NetBird's CLIs sit, so this block and every other that calls them
start by appending `/opt/homebrew/bin` and `/usr/local/bin`.

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
  Its SSH server is on with `"RunSSH": true`.
- **NetBird:** connected with `Management: Connected` and
  `Signal: Connected`; `Daemon status` `NeedsLogin`,
  `LoginFailed` or `SessionExpired` is not. Expiry:
  `Session expires`. Its SSH server is on unless the `SSH Server`
  line says `Disabled`; a client too old to print the line counts
  as on.
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
  `notAfter` of the certificate the configuration's `pki` block
  names, root: `grep -E '^[[:space:]]+cert:' <config>` for the
  path, then `nebula-cert print -path <that file>`. The
  configuration is the one the process's `-config` names
  (`ps -o args= -p <pid>`), `/etc/nebula/config.yml` by default;
  where it names a directory, its `*.yml` and `*.yaml` files are
  read. `dnclient` keeps its own in `/var/lib/defined`. A
  certificate inline in the configuration (`cert: |`), or no
  `nebula-cert`, leaves the expiry `unchecked`.
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
(`rules/ssh-safety-net.md`). A host whose `- Access:` line
records no working path but the VPN drops out of Hostwarden's
reach with it.

## SSH servers in agents

Tailscale, NetBird and Pangolin's Newt serve SSH themselves,
past sshd. The security audit judges them
(`.agents/skills/hostwarden-security/references/vpn-ssh.md`);
two moments are this file's.

### This session came in through one

`SSH_CONNECTION` names the address and port this session reached
(`rules/ssh-safety-net.md` → Which way in). The session went to
the agent's own server, not to sshd, when that is the host's
Tailscale address with port `22` while `"RunSSH": true`, since
Tailscale then answers port 22 there itself, or the NetBird
address with port `22022`, where NetBird redirects port 22.
Record the path as `via Tailscale SSH` or `via NetBird SSH` in the
`- Access:` line. A path through Newt's server is not told apart
from sshd this way.

On that path, keys, certificates and `sshd_config` play no part
in the login:

- `Permission denied` means the VPN's policy admits no login to
  this account for this identity, not a wrong key. Try no other
  key, user or root (`rules/ssh-unreachable.md` → Login
  rejected); tell the user where the policy lives (Per agent
  above). The `- Access:` line can be stale, since the agent's
  SSH server may have been turned off since, and the refusal is
  then sshd's. Tailscale sends its refusal as a banner before
  it, `tailscale: access denied` or the policy's own message,
  which settles it where it shows; a `LogLevel` below `INFO` in
  the user's own configuration hides it. Without it, name both
  causes to the user.
- Tailscale's check mode prints a URL and waits until the person
  confirms in a browser, and NetBird's OIDC login needs a browser
  login too. An unattended run can do neither and fails there.
- sshd still answers on that address on any other port, and on
  the host's other addresses.

### Logins past sshd

A login through an agent's SSH server is missing from `last` and
from sshd's log. The activity check reads them in its call
(`rules/activity-check.md` → What rides in this call), with the
privilege prefix of `rules/privilege-escalation.md` → Stand-ins
for sudo at its top. Where memory's `Sudo:` line records sudo as
unavailable or unusable, that prefix leaves out its `sudo` line,
as the read-back does. Without root the journal would show only
the user's own entries and read as silence, so `$SUDO` `-`
prints one `not read` line instead:

```bash
keep() { awk -v m="$1" '{ l[NR % m] = $0 } END {
  if (NR > m) print "earlier: " NR - m
  for (i = NR - m + 1; i <= NR; i++) if (i > 0) print l[i % m] }'; }
PATH=$PATH:/opt/homebrew/bin:/usr/local/bin
tsd=; pgrep -x tailscaled >/dev/null 2>&1 && tsd=1
if [ -n "$tsd" ] || command -v netbird >/dev/null 2>&1; then
  echo "SSH_CONNECTION=$SSH_CONNECTION"
  if [ -n "$tsd" ]; then
    tailscale ip 2>&1; tailscale debug prefs 2>&1 | grep '"RunSSH"'
  fi
fi
if [ "$SUDO" = - ]; then
  { [ -n "$tsd" ] || command -v netbird || pgrep -x newt; } \
    >/dev/null 2>&1 && echo "agent SSH logins not read: no root"
else
  if [ -n "$tsd" ]; then
    if [ -d /run/systemd/system ]; then
      { $SUDO journalctl _COMM=tailscaled --since "7 days ago" \
          --no-pager -q -o short-iso \
          || echo "tailscaled journal not read"; } 2>&1 \
        | awk '/not read$/ { print; next }
          /access granted to/ { k = $0; sub(/.*access granted to /, "", k)
            n[k]++; w[k] = $1 }
          END { for (k in n) print w[k], n[k] "x", k }'
    else
      tsp=$(pgrep -x tailscaled 2>/dev/null | head -n 1)
      tsl=$($SUDO readlink "/proc/$tsp/fd/2" 2>/dev/null)
      [ -n "$tsl" ] || for tsc in /opt/homebrew/var/log/tailscaled.log \
                               /usr/local/var/log/tailscaled.log; do
        [ -e "$tsc" ] && { tsl=$tsc; break; }
      done
      case $tsl in
        ''|/dev/null)
          echo "tailscale logins not read: no journal, no log file" ;;
        *' (deleted)'|/*' '*|[!/]*)
          echo "tailscale logins not read: output goes to $tsl" ;;
        *)
          { $SUDO awk -v f="$tsl" 'NR == 1 { a = $1 }
              /access granted to/ { print }
              END { if (NR) print "log " f " spans " a " to " $1
                    else print "tailscale logins not read: empty " f }' \
              "$tsl" || echo "tailscale logins not read: $tsl"; } \
            2>/dev/null | keep 20 ;;
      esac
    fi
  fi
  if command -v netbird >/dev/null 2>&1; then
    netbird status -d 2>&1 | awk '/^SSH Server:/ { p = 1; print; next }
      p && /^  \[/ { sub(/\] .*/, "]"); print; next }
      p && /^    / { next } { p = 0 }'
    nbl=/var/log/netbird/client.log
    { $SUDO awk 'NR == 1 { a = $1 }
        /S(SH|FTP) session started|SSH auth denied/ { print }
        END { if (NR) print "client.log spans " a " to " $1
              else print "netbird client.log not read: empty" }' "$nbl" \
        || echo "netbird client.log not read"; } 2>/dev/null | keep 20
  fi
  pgrep -x newt >/dev/null 2>&1 && echo "newt SSH logins not read"
fi
```

- Where `SSH_CONNECTION` and the `- Access:` line disagree on
  whether this session came in through an agent's SSH server
  (This session came in through one), correct the line, in
  either direction.
- The Tailscale part keys on a running `tailscaled`: the macOS
  apps run none, serve no SSH and leave no login to read.
- Tailscale writes one line per SSH session, and every call
  over a shared connection is one, Hostwarden's own included, so
  the block prints one line per tailnet login and local account:
  the last time, how many sessions, and
  `alice@example.com as ssh-user "root"`. `_COMM` finds
  tailscaled's lines whatever unit runs it. A volatile journal
  reaches back only to the boot; the read-back's own first-entry
  line says how far.
- Without systemd, the block reads the file tailscaled writes
  its output to: on Linux the one its standard error is open on
  (Alpine's service, Unraid's plugin), on macOS Homebrew's
  service log (the App Store and standalone apps serve no SSH).
  It prints its lines as NetBird's below, with a `spans` line
  that names the file: a rotated file keeps older logins in
  backups that are not read, and one never rotated holds months.
  Report only the lines of the last 7 days, and a start inside
  the week as logins not checked before it. An end long before
  today, while tailscaled runs, means it writes elsewhere: `not
  read`. A file that is empty or deleted is `not read` too: on
  Alpine, logrotate replaces the file while tailscaled keeps
  writing to the old one until it restarts. Output that goes
  nowhere, to a pipe or to syslog — FreeBSD and the appliances
  built on it, OpenWrt — is `not read` as well.
- `netbird status -d` lists the sessions open now under
  `SSH Server:`, one line each: `[<login>@<address> -> <account>]`,
  or `[<account>@<address>]` without an OIDC login. The `awk`
  cuts each line after the `] ` that closes it: the rest is the
  session's command line, which can carry a secret
  (`rules/secrets.md`), and its port forwards are left out with
  it.
- In `client.log`, `SSH session started` and `SFTP session
  started` are logins, with `jwt_user` naming the OIDC login
  where there was one, and `SSH auth denied` a refused one, one
  line per session as with Tailscale. `keep` prints the last 20
  and counts the rest on an `earlier:` line. Report only the
  lines whose timestamp falls in the last 7 days. The `spans`
  line says what the file covers: NetBird rotates it at 15 MB
  into compressed backups that are not read, so a start inside
  the week means older logins were not checked, and an end long
  before today means the service logs elsewhere, a `--log-file`
  on its command line.
- Newt leaves its logins in its own output, which no probe
  reads.
- A `not read` line is no result: say that these logins were not
  checked, never that there were none.

They are reported as `rules/activity-check.md` → What to show
says. This session's own login is among them when it came in
that way.

## Memory

Per host, a `## Mesh VPN` section in
`memory/servers/<hostname>/network.md`, created with this section
alone when the host has no profile yet. One line per agent, also
when it is down, and for Tailscale, NetBird and Newt whether its
SSH server is on or off, so a change shows. Newt's state comes
from the security audit's probe; before one ran, it is
`unchecked`:

```markdown
## Mesh VPN
- Tailscale 1.102.4, 100.101.102.103, connected, control
  Headscale hs.example.com, no key expiry, routes 10.0.0.0/24;
  SSH off
- WireGuard wg0 10.8.0.5, hub vpn.example.com
- NetBird 100.92.1.7, not connected (SessionExpired); SSH on
```

Mark what needed root and was not read as `unchecked`.

A way in nobody recorded is an agent that runs or an overlay
interface that is up, from either block of the probe, or an
agent's SSH server that is on, while this section has no line
for it or records it off or `unchecked`. A Headscale server is
none: it is a control server, recorded in `memory/network.md`.
On macOS the `utun` interfaces the system makes itself are none
either, and neither is an app that is installed but not active
(Probe above); only an active app counts there. Ask the user
whether it belongs, and record it once they say it does. The
`- Network:` line in `memory.md` names the agents
(`rules/network.md` → Where it goes).

The network itself — agent, control server, where the policy
lives, subnet routers and what they route — goes into
`memory/network.md`, one entry per network. Whether the
workstation is in it goes into `memory/user.md`, which is
personal.
