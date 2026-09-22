# Containers

Run whenever `command -v docker podman nerdctl` finds an engine, or
`memory.md` has a `Container runtime:` line. How to reach the
containers — privileges, rootless owners, containerd namespaces,
what owns a container — is `rules/containers.md`; this file holds
the audit. Published ports are
`references/firewall-nftables-docker.md` → Docker published ports:
run them there, not here.

**The appliance file wins.** Where the host's appliance file names
the engine's binary, lists container checks under
`## Housekeeping and Audits`, or says a check does not apply, use
its binary, run its checks, and add the ones below that it does not
exclude. A remedy for a container a UI owns is a step in that UI,
for the user. On Home Assistant OS this file does not run
(`rules/appliance/haos.md`).

## Probe

One call per engine and per rootless owner; `d` as in the
housekeeping skill's `references/containers.md` → Probe. The format
strings name every field. The environment comes out as names only:
`split` keeps each value inside the template (`rules/secrets.md`,
`rules/containers.md` → List and Inspect).

```bash
d=docker
$d ps -aq | xargs -r $d inspect --format '{{.Name}} priv={{.HostConfig.Privileged}} user={{.Config.User}} capadd={{join .HostConfig.CapAdd ","}} net={{.HostConfig.NetworkMode}} pid={{.HostConfig.PidMode}} ipc={{.HostConfig.IpcMode}} secopt={{join .HostConfig.SecurityOpt ","}} apparmor={{.AppArmorProfile}} image={{.Config.Image}}'
$d ps -aq | xargs -r $d inspect --format '{{.Name}}{{range .Mounts}} {{.Type}}:{{.Source}}:{{.RW}}{{end}}'
$d ps -aq | xargs -r $d inspect --format '{{.Name}}{{range .Config.Env}} {{index (split . "=") 0}}{{end}}'
```

Docker's daemon, in the same call:

```bash
docker info --format '{{json .SecurityOptions}}'
grep -E '"(hosts|tls|tlsverify|userns-remap|no-new-privileges)"' \
  /etc/docker/daemon.json 2>/dev/null
ps -o args= -C dockerd 2>/dev/null
ss -tln 2>/dev/null | grep -E ':(2375|2376) '
getent group docker
```

For Podman, `systemctl is-active podman.socket` and the `ss` line:
its API listens on a Unix socket unless someone ran
`podman system service tcp://…`.

## Engine

- **CRITICAL** for the Docker API on TCP without TLS on an address
  beyond loopback: a `tcp://` in the `dockerd` arguments or in
  `hosts`, with no `tlsverify`, or a listener on 2375. Whoever
  reaches it controls the daemon, and through it the host; Docker
  calls remote access without TLS "not recommended"
  (<https://docs.docker.com/engine/daemon/remote-access/>). A
  Podman service on TCP is the same finding. **WARN** on loopback:
  every local account gets root.
- **INFO** each member of the `docker` group: root-equivalent
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

The registry is the part of `image=` before the first `/` when it
holds a `.` or a `:` or is `localhost`; otherwise it is Docker Hub,
`docker.io`. The registries the user trusts are recorded in
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
