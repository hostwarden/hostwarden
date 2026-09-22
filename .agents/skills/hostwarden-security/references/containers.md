# Containers

Run whenever `command -v docker podman nerdctl` finds an engine, or
`memory.md` has a `Container runtime:` line. **Not on macOS**, where
the engine is Docker Desktop or Podman Desktop in a virtual machine
of its own: `systemctl`, `getent` and `ss` say nothing there, the
engine belongs to the logged-in person rather than to root, and what
a container may do is the VM's business. Report the engine and its
version from `docker info`, name the desktop app as the place its
settings live, and leave the rest out. How to reach the
containers — privileges, rootless owners, containerd namespaces,
what owns a container — is `rules/containers.md`; this file holds
the audit. Published ports are
`references/firewall-nftables-docker.md` → Docker published ports:
run them there, not here.

**The appliance file wins** (`rules/containers.md`): run its
container checks, then add the ones below that it does not exclude.
On Home Assistant OS this file does not run
(`rules/appliance/haos.md`).

## Probe

One call per host, `d` and the owners as in the housekeeping skill's
`references/containers.md` → Probe. The environment comes out as
names only: `split` keeps each value inside the template
(`rules/containers.md` → List and Inspect).

```bash
d=docker
$d ps -aq | xargs -r $d inspect --format '{{.Name}} priv={{.HostConfig.Privileged}} user={{.Config.User}} capadd={{join .HostConfig.CapAdd ","}} net={{.HostConfig.NetworkMode}} pid={{.HostConfig.PidMode}} ipc={{.HostConfig.IpcMode}} secopt={{join .HostConfig.SecurityOpt ","}} apparmor={{.AppArmorProfile}} image={{.Config.Image}}{{"\n"}}  mounts:{{range .Mounts}} {{.Type}}:{{.Source}}:{{.RW}}{{end}}{{"\n"}}  env:{{range .Config.Env}} {{index (split . "=") 0}}{{end}}'
```

Docker's daemon, in the same call:

```bash
docker info --format '{{json .SecurityOptions}}{{range .Warnings}}{{printf "\n%s" .}}{{end}}'
grep -oE '"(hosts|tls|tlsverify|userns-remap|no-new-privileges)" *: *[^,}]*' \
  /etc/docker/daemon.json 2>/dev/null
grep -hoE -- '-H +[^ "'"'"']+' /etc/conf.d/docker /etc/default/docker \
  2>/dev/null
pat='(^|/)(dockerd|podman)|system service|-H +[^ ]+'
pat="$pat"'|--host[= ][^ ]+|--tls[a-z]*([= ][^ ]+)?|tcp://[^ ]+'
ps -eo args | grep -E '[d]ockerd|[s]ystem service' \
  | while IFS= read -r line; do
      printf '== '
      printf '%s\n' "$line" | grep -oE "$pat" | tr '\n' ' '
      echo
    done
systemctl cat podman.socket 2>/dev/null | grep -E '^(ListenStream|ListenDatagram)='
loginctl list-users --no-legend 2>/dev/null | awk '{print $2}' \
  | while read -r u; do
      systemctl --user -M "$u@" cat podman.socket 2>/dev/null \
        | grep -E '^ListenStream='
    done
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || netstat -tln
getent group docker
g=$(getent group docker | cut -d: -f3)
[ -n "$g" ] && getent passwd | awk -F: -v g="$g" '$4 == g {print $1}'
```

`ps -eo args` works with busybox too. The loop keeps one line per
process, and the inner `grep -o` keeps only the engine's name and
its listen and TLS options from it, so a credential in a
neighbouring argument — a proxy or registry URL — never reaches the
output, and two processes never blend into one. It finds `dockerd`
and a `podman system service`, whose API listens on TCP wherever its
arguments name `tcp://`, on any port. A
`podman.socket` unit with a TCP `ListenStream` exposes the same API
with no process until it is activated, which is why the unit is read
too, for root and for each logged-in owner. The listeners are read for
those ports, not only 2375 and 2376. A listener counts as the
engine's only where the process column names it, or where the
engine's own arguments, a `ListenStream` or its configuration name
that address; another service on 2375 is that service's finding, not
the engine's. A listener `ss` attributes to systemd that a
`podman.socket` unit names is the engine's. Where
neither `ss` nor
`netstat` exists, name the listener check as not run.

## Engine

- **CRITICAL** for the Docker API on TCP without TLS on an address
  beyond loopback: a `tcp://` in the `dockerd` arguments or in
  `hosts` or an init file's `-H`, with no `tlsverify`, a listener on
  2375, or `docker info` warning that the API is reachable without
  encryption. Whoever
  reaches it controls the daemon, and through it the host; Docker
  calls remote access without TLS "not recommended"
  (<https://docs.docker.com/engine/daemon/remote-access/>). A
  Podman service on TCP is the same finding. **WARN** on loopback:
  every local account gets root.
- **INFO** each member of the `docker` group, the `getent group`
  list and the accounts whose primary group it is alike:
  root-equivalent
  (`rules/privilege-escalation.md` → Root-Equivalent Groups).
  **WARN** for a deploy or CI account among them: a pipeline never
  gets root (`hostwarden-deploy-user` skill).
- **OK**, and name it: a rootless engine (`name=rootless`, or
  Podman's `rootless=true`), user-namespace remapping
  (`name=userns`, `userns-remap`), and `no-new-privileges` set for
  the whole daemon. With a rootless engine or remapping, root inside
  a container is not root on the host: the Running as Root finding
  below does not apply.

## Per Container

- **WARN** for `priv=true`: the container has every capability and
  every device of the host (`rules/best-practices.md`).
- **WARN** for the engine's socket among the mounts —
  `docker.sock`, `podman.sock`, `containerd.sock`, or all of
  `/run` or `/var/run` — read-only or not: a read-only mount still
  lets the container talk to the daemon, and the daemon is root.
  Reverse proxies, dashboards and updaters ask for it; OK with
  context where `memory.md` records the container as allowed it,
  and still named.
- **WARN** for `capadd` holding `ALL`, `SYS_ADMIN`, `SYS_MODULE`,
  `SYS_PTRACE`, `SYS_RAWIO` or `DAC_READ_SEARCH`. **INFO** for
  `NET_ADMIN` or `NET_RAW`, which VPN and DHCP containers need.
- **WARN** for `pid=host`: the container sees and can signal every
  process of the host. **INFO** for `ipc=host`, and for `net=host`:
  its listeners bind the host's addresses directly, and
  `references/listening-services.md` judges them.
- **WARN** for a bind mount of `/`, `/etc`, `/root`, `/boot`, `/dev`,
  `/proc`, `/sys`, `/run` or `/var/run` with `RW` true, and for `/`
  read-only, which still shows the shadow file and every key. The
  others read-only are **INFO**. Name the container and the path,
  and let memory's record of an intended mount make it OK with
  context.
- **WARN** for `secopt` holding `apparmor=unconfined`,
  `seccomp=unconfined` or `label=disable` (SELinux; Podman may spell
  them with `:`), on a container that is not already reported as
  privileged.
- **INFO**, one line with the names: containers running as root
  (`user` empty, `0`, `root` or `0:0`) on a rootful engine without
  remapping.
- **INFO**, one line with the names: containers without
  `no-new-privileges` in `secopt`, unless the daemon sets it.
- **INFO** for environment names that look like credentials —
  containing `PASS`, `SECRET`, `TOKEN`, `API_KEY`, `APIKEY`,
  `PRIVATE_KEY` or `CREDENTIAL`, case-insensitive, and not ending
  in `_FILE` — by name only, never the value. Anyone who may run
  `inspect` reads them. The remedy is a secret mounted as a file:
  the image's `*_FILE` variables, or the engine's secrets.

## Registries

A reference without a `/` — `postgres:16`, `alpine:3.19` — is a
Docker Hub image, `docker.io`, and its `:` is the tag. Only where
the reference holds a `/` is the part before the first one a
registry, and then only when it holds a `.` or a `:` or is
`localhost`: `ghcr.io/owner/app` names one, `owner/app` is Docker
Hub too. The registries the user trusts are recorded in
`memory.md` as `- Container registries: docker.io, ghcr.io`.

- None recorded: **INFO** with the registries in use; ask the user
  which are theirs to trust, and record the answer.
- **WARN** for an image from a registry outside that list: code
  from a source the user did not name runs on the host
  (`AGENTS.md`: official repos only).

## Report

In the Checks section, one line per engine:

```
Containers          WARN — 2 findings, 14 containers, docker rootful
Docker API          OK — Unix socket only
```

Findings go to Issues, one line each:

```
WARN      Container proxy/traefik mounts docker.sock
WARN      Container tools/debug runs privileged
INFO      Containers as root: 9 (web/app, db/postgres, …)
```
