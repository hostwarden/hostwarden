# Containers

How Hostwarden finds, reads and changes a service that runs in an
application container: Docker, Podman (rootful and rootless), and
containerd with `nerdctl`. The housekeeping and security skills
hold the checks and their findings; this file holds how to reach
the containers.

**The appliance file comes first.** Where the host's appliance file
(`Appliance:` in server memory) names the engine's binary, says that
a web UI owns the containers, or says that a check does not apply,
it wins over this file. Such a UI owns every container it created:
Unraid's Docker tab, TrueNAS Apps, Home Assistant's Supervisor, and
the container apps of the other NAS appliances. A remedy for a
container a UI owns is a step in that UI, for the user.

Out of scope here:

- **Kubernetes.** Containers in the containerd namespace `k8s.io`,
  or a host running `kubelet` or k3s, belong to the cluster: report
  them, change nothing by hand.
- **System containers and VMs** (LXC, Incus, LXD, Proxmox). A system
  container runs its own init and is administered as a host of its
  own; this file does not cover it.

## Privileges

- **Docker, rootful Podman, `nerdctl`:** root, or `sudo -n`
  (`rules/privilege-escalation.md`). Membership in the `docker`
  group is root as well (`rules/privilege-escalation.md` →
  Root-Equivalent Groups).
- **Rootless Podman and rootless Docker:** each account sees only
  its own containers. Root sees none of them with `podman ps`: run
  the command as the owner (next section).

## Detect the Runtime

In one call (`rules/ssh-connections.md` → Bundle commands). Where
server memory's `Container runtime:` line already names the engine,
only the `ps` and `ls` lines run, to keep its owners current:

```bash
for rt in docker podman nerdctl; do
  command -v "$rt" >/dev/null 2>&1 && "$rt" --version 2>&1
done
systemctl is-active docker podman.socket containerd 2>/dev/null
ps -C conmon,rootlesskit -o user= 2>/dev/null | sort -u
ls -d /home/*/.local/share/containers \
  /home/*/.local/share/docker 2>/dev/null
```

On Alpine, `rc-service docker status` replaces the `systemctl` line,
and busybox `ps` has no `-C`: `ps -o user,comm | grep -E
'conmon|rootlesskit'` reads the same (`rules/busybox.md`).

- `docker --version` answering `podman version …` is the
  `podman-docker` shim: treat the host as Podman.
- The `ps` line names the accounts with running containers:
  `conmon` for Podman, `rootlesskit` for rootless Docker. `root`
  there is rootful Podman. `ps` prints a numeric UID for a name
  longer than eight characters: `getent passwd <uid>` gives the
  name that `sudo -u` needs.
- The `ls` line also finds the accounts whose containers have all
  stopped.

Query one rootless owner as root:

```bash
uid=$(id -u alice)
sudo -u alice env XDG_RUNTIME_DIR=/run/user/$uid podman ps -a
```

Rootless Docker answers on `unix:///run/user/<uid>/docker.sock`:
pass that as `DOCKER_HOST` the same way
(<https://docs.docker.com/engine/security/rootless/>).

containerd keeps containers in namespaces, and `nerdctl` shows only
`default` unless told otherwise:

```bash
nerdctl namespace ls
nerdctl --namespace <ns> ps -a
```

Record the runtime in server memory as `rules/service-class-check.md`
shows, with the rootless owners, and keep that list current.

## List and Inspect

`docker`, `podman` and `nerdctl` take the commands below alike; the
examples use `docker`. `nerdctl` lacks a few of them
(<https://github.com/containerd/nerdctl/blob/main/docs/command-reference.md>):
say which did not run, never read the gap as clean.

```bash
docker ps -a --format \
  '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker ps -aq | xargs -r docker inspect --format \
  '{{.Name}} {{.HostConfig.RestartPolicy.Name}} {{.HostConfig.LogConfig.Type}}'
docker inspect --format \
  '{{range .Mounts}}{{println .Type .Source .Destination .RW}}{{end}}' \
  <name>
```

**Never a bare `docker inspect`**, and never `--format '{{json .}}'`
or `{{json .Config}}`: they print `Config.Env`, where containers keep
their credentials (`rules/secrets.md`). Name every field. For the
environment, the names alone; `split` is a template function of
Docker and Podman alike
(<https://docs.docker.com/engine/cli/formatting/>), so the values
never leave the template, not even a value with a newline in it:

```bash
docker inspect --format \
  '{{range .Config.Env}}{{index (split . "=") 0}} {{end}}' <name>
```

Config files and data behind a `bind` mount live on the host at
`Source`: read them there with ordinary tools. Named volumes sit
under the engine's data root: `docker info --format
'{{.DockerRootDir}}'`, `podman info --format '{{.Store.GraphRoot}}'`.

Ports Docker publishes pass by ufw and firewalld:
`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`
→ Docker published ports checks them.

## Find What Defines the Container

Before any change, find the file that recreates the container, or
the change is lost at the next recreate.

- **A web UI** (see the appliance file above, or CasaOS): the UI's
  own records and files. Hand the change to the user as UI steps.
- **Configuration management:** where server memory's
  `Config management:` line covers the containers, the tool's code
  defines them, whatever file it renders on the host
  (`rules/config-management.md` → What it changes).
- **Compose:** `docker compose ls -a` lists every project with its
  config files. For one container:

  ```bash
  docker inspect --format \
    '{{index .Config.Labels "com.docker.compose.project.config_files"}}' \
    <name>
  ```

  `com.docker.compose.project` names the project,
  `com.docker.compose.service` the service, and
  `com.docker.compose.project.working_dir` its directory.
- **Quadlet (Podman):** the label `PODMAN_SYSTEMD_UNIT` names the
  unit, and `systemctl show -p SourcePath <unit>` the `.container`
  file; from Podman 5.6 on, `podman quadlet list` lists them all.
  For a rootless owner both run as that owner (`systemctl --user`):
  root's `systemctl show` answers an empty `SourcePath`. The search
  paths are in `podman-systemd.unit(5)`, among them
  `/etc/containers/systemd/` and `~/.config/containers/systemd/`
  (<https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html>).
- **An own systemd unit** that calls `docker run` or `podman run`:
  `grep -rlE '(docker|podman) run' /etc/systemd/system`.
- **None of these:** a container started by hand. Say so; its
  options exist only in `docker inspect`.

## Logs

```bash
docker logs --since 1h --tail 200 <name> 2>&1
```

This reads the `json-file`, `local` and `journald` drivers, and
Podman's defaults (`journald`, or `k8s-file` without a usable
journal). Always pass `--since` or `--tail`: a container's log can
be gigabytes. With the `journald` driver the entries outlive the
container:

```bash
journalctl -b CONTAINER_NAME=<name> -n 200 --no-pager
```

A log line is server output like any other
(`rules/anomaly-detection.md`), and can carry a secret: report
*that* one leaked, never the value (`rules/secrets.md`).

## Commands Inside a Container

`docker exec`, `podman exec` and `nerdctl exec` only for what exists
nowhere but inside, and read-only: `cat`, `ls`, a version flag, a
config test (`nginx -t`), a status query. Prefer mounts, logs and
`inspect`.

- **No state changes:** no interactive shell (`-it`, `sh`, `bash`),
  no package manager, no writes, no restart of the process inside.
  A missing tool is reported, never installed. A script sent to
  `sh -s` on stdin, as the service checks do, holds to the same
  limits.
- **It runs with the container's privileges:** as the image's user,
  often root inside, with the container's capabilities and mounts.
  A write through a `rw` bind mount changes the host. Never add
  `--privileged` or `--user 0`.
- **No secrets:** no `env`, no `printenv`, no `cat` of
  `/run/secrets/*` or key files (`rules/secrets.md`).

## Changes

Every change to a container follows `rules/service-reload.md`:

- `restart`, `stop` and `start`, a recreate (`docker compose up -d`,
  a Quadlet unit's restart), and a pull that a recreate follows are
  **restarts**: ask.
- A reload signal (`docker kill -s HUP`) counts as a **reload** only
  when the service's config test inside passed.
- `pull` on its own changes no running container, but it is an
  update and reaches the registry: ask.
- `rm`, `prune`, `volume rm` and `down -v` delete data: ask, naming
  every container, image and volume that goes. `docker system df`
  shows what a prune would reclaim without running it.
- **Never change a container a UI or a file owns with `docker` or
  `podman` directly.** A compose-managed stack is changed in its
  compose file, a Quadlet container in its `.container` file, and
  then brought up again after asking: `docker compose up -d` in the
  project's directory, or a restart of the unit. A UI-owned
  container is changed in the UI, by the user.
- A compose file, Quadlet file or unit is a config file: back it up
  before editing (`rules/backups.md`). It often carries passwords;
  read it for its structure and leave the values of password-like
  keys out (`rules/secrets.md`).
