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

The loop repeats the discovery of `references/ssh.md` and reads
each agent from the process it belongs to, so two Newt
connectors are judged apart and a tunnel is read from the
configuration its own process names.

```bash
A='tailscaled|netbird|newt|nebula|dnclient|cloudflared'
args() { { tr '\0' ' ' < "/proc/$1/cmdline"; } 2>/dev/null \
  || ps -o args= -p "$1" 2>/dev/null; }
cfg() { args "$1" | sed -nE "s|.* --?$2[= ]([^ ]+).*|\\1|p"; }
ps -Ao pid=,comm= 2>/dev/null \
  | sed -E 's|^[[:space:]]+||; s|^([0-9]+)[[:space:]]+.*/|\1 |' \
  | grep -E "^[0-9]+ ($A)$" \
  | while read -r p prog; do
    case $prog in
      tailscaled)
        tailscale debug prefs 2>&1 \
          | grep -e '"RunSSH"' -e '"OperatorUser"' ;;
      netbird)
        netbird status 2>&1 | grep -e '^SSH Server' -e '^Profile' ;;
      newt)
        printf 'newt %s disable-ssh=%s\n' "$p" \
          "$(args "$p" | grep -cE -- ' --?disable-ssh( |=|$)')" ;;
      cloudflared)
        printf 'cloudflared %s token-arg=%s\n' "$p" \
          "$(args "$p" | grep -cE -- ' --?token( |=)')"
        c=$(cfg "$p" config)
        if [ -n "$c" ]; then set -- "$c"
        else set -- /etc/cloudflared/*.y*ml \
          /usr/local/etc/cloudflared/*.y*ml ~/.cloudflared/*.y*ml; fi
        grep -Hn 'ssh://' "$@" 2>/dev/null ;;
      nebula|dnclient)
        c=$(cfg "$p" config)
        [ -n "$c" ] || c=/etc/nebula/config.yml
        for f in "$c" "$c"/*.yml "$c"/*.yaml; do
          [ -f "$f" ] || continue
          [ -r "$f" ] || { echo "== $f unreadable"; continue; }
          echo "== $f"
          sed -n '/^sshd:/,/^[^[:space:]#]/p' "$f"
        done ;;
    esac
  done
```

The `grep -c` lines count, never print (`rules/secrets.md`);
only a path is named, never an argument that could be a token,
and a flag takes one dash or two, so `--token-file`, the safe
form, is not a match. A Nebula file marked `unreadable` is read
again by the root probe below;
`dnclient` keeps its state in `/var/lib/defined` and may name
that instead.

An agent inside a container with its own network namespace shows
its process but not its CLI; name the container and mark its SSH
server unchecked.

## Probe (root)

Tailscale with `"RunSSH": true`, NetBird unless its `SSH Server`
line says `Disabled`, Nebula where the loop above printed
`unreadable` or no file at all,
and Newt for each PID whose `disable-ssh` count was 0:

```bash
# args() as in the probe above.
# Tailscale, "RunSSH": true — the rules compiled for this node
T=$(printf '\t')
tailscale debug netmap 2>&1 \
  | sed -n "/^$T\"SSHPolicy\": null/p; /^$T\"SSHPolicy\": {/,/^$T}/p"
# NetBird, SSH Server not "Disabled" — flags of every profile
for f in /var/lib/netbird/*.json /var/db/netbird/*.json \
         /etc/netbird/*.json; do
  [ -f "$f" ] || continue
  echo "== $f"
  grep -oE '"(ServerSSHAllowed|EnableSSH[A-Za-z]*|DisableSSHAuth)": *(true|false)' \
    "$f"
done
# Newt on Linux, per PID — DISABLE_SSH in its own environment
for p in $(pgrep -x newt 2>/dev/null); do
  printf 'newt %s env-disable-ssh=%s\n' "$p" \
    "$({ tr '\0' '\n' < "/proc/$p/environ"; } 2>/dev/null \
      | grep -ciE '^DISABLE_SSH=(true|1)$')"
done
# Nebula, where the unprivileged loop could not read the file
for p in $(pgrep -x nebula 2>/dev/null; pgrep -x dnclient 2>/dev/null); do
  c=$(args "$p" | sed -nE 's|.* --?config[= ]([^ ]+).*|\1|p')
  [ -n "$c" ] || c=/etc/nebula/config.yml
  for f in "$c" "$c"/*.yml "$c"/*.yaml; do
    [ -f "$f" ] || continue
    echo "== $f"
    sed -n '/^sshd:/,/^[^[:space:]#]/p' "$f"
  done
done
```

Print only these fields: the same files hold private keys, and
NetBird's JSON can sit on one line with them, which is why its
grep prints the matches alone (`-o`), with the file name from the
loop rather than a GNU-only `--include` (`rules/busybox.md`). The
environment holds Newt's secret, which is why that grep only
counts (`rules/secrets.md`).

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
- Cloudflare Tunnel `token-arg=1` on a PID → **WARN**, that
  process's token is readable by every account
  (`rules/secrets.md`)
- Newt SSH on, judged per PID: `disable-ssh=0` and
  `env-disable-ssh=0` → **INFO**, with the accounts and sudo
  files that process made. `disable-ssh=0` without root, or a
  Newt in a container, is **INFO** "Newt SSH unchecked" for that
  PID: its environment may turn it off. Several connectors are
  reported one by one, never as one verdict
- Nebula `sshd.enabled: true` → **INFO**, name `listen` and
  `authorized_users`. Where the file its own process names is
  unreadable even with root, **INFO** "Nebula admin console
  unchecked" rather than OK
- Cloudflare ingress to `ssh://` → **INFO**: sshd is reachable
  through Cloudflare, and Cloudflare Access decides who. Where
  the running process named a `--config` path, that file is the
  only one the probe reads. A token-managed tunnel keeps its ingress
  in the dashboard, not on the host: no hit in the file it uses
  then means **INFO** "Cloudflare ingress unchecked" — ask the
  user what the tunnel publishes
- Tailscale `OperatorUser` set → **INFO**, name the account: it
  can turn SSH on without root
- Policy not readable from the host (Tailscale without root,
  NetBird always) → **INFO** "policy not checked"; ask the user
  for it
- An agent found without an SSH server of its own → OK

Where each agent's policy lives, and who may change it:
`rules/mesh-vpn.md` → Per agent.
