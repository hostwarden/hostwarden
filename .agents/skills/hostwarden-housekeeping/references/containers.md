# Containers

Triggered by a `Container runtime:` line in `memory.md`, by a
mention of Docker or Podman there, or when `command -v docker podman
nerdctl` finds an engine; record a new one as
`rules/service-class-check.md` shows. How to reach the containers —
privileges, rootless owners, containerd namespaces, what owns a
container — is `rules/containers.md`; this file holds the checks and
their findings. Everything here reads; nothing prunes, pulls,
restarts or updates.

**The appliance file wins.** Where the host's appliance file names
the engine's binary (`/usr/local/bin/docker` on Synology DSM, the
Container Station path on QNAP), says a UI owns the containers, or
says a check does not apply, use its binary, keep to its limits and
leave out what it excludes. On Home Assistant OS this file does not
run: `ha` is the check (`rules/appliance/haos.md`). A remedy for a
container a UI owns is a step in that UI, for the user.

## Probe

One read-only call per engine and per rootless owner. `d` is the
engine's command: `docker`, `podman`, `nerdctl --namespace <ns>`,
the appliance's path, or for a rootless owner the `sudo -u … env
XDG_RUNTIME_DIR=…` form from `rules/containers.md` → Detect the
Runtime. As root, or as that owner.

Docker, first:

```bash
d=docker
$d info --format '{{.ServerVersion}} root={{.DockerRootDir}} log={{.LoggingDriver}} {{json .SecurityOptions}}'
$d info --format '{{range .Warnings}}{{println .}}{{end}}'
grep -E '"log-(driver|opts)"|"max-(size|file)"' \
  /etc/docker/daemon.json 2>/dev/null
$d ps -aq | xargs -r $d inspect --format '{{.LogPath}}' \
  | grep . | xargs -r du -m 2>/dev/null | sort -rn | head -5
$d compose ls -a 2>/dev/null
```

Podman, first; for a rootless owner, `systemctl --user` as that
owner, with the same `XDG_RUNTIME_DIR`:

```bash
d=podman
$d info --format '{{.Version.Version}} rootless={{.Host.Security.Rootless}} root={{.Store.GraphRoot}} log={{.Host.LogDriver}}'
systemctl is-enabled podman-restart.service 2>/dev/null
```

Then, for every engine:

```bash
$d ps -a --format '{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}'
$d ps -aq | xargs -r $d inspect --format '{{.Name}} policy={{.HostConfig.RestartPolicy.Name}} restarts={{.RestartCount}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} health={{if .State.Health}}{{.State.Health.Status}}{{end}} log={{.HostConfig.LogConfig.Type}} max-size={{index .HostConfig.LogConfig.Config "max-size"}} unit={{index .Config.Labels "PODMAN_SYSTEMD_UNIT"}} project={{index .Config.Labels "com.docker.compose.project"}} service={{index .Config.Labels "com.docker.compose.service"}} dir={{index .Config.Labels "com.docker.compose.project.working_dir"}}'
$d ps -aq | xargs -r $d inspect --format '{{.Config.Image}} {{.Image}}' \
  | sort -u | while read -r ref id; do
      [ "$($d image inspect --format '{{.Id}}' "$ref" 2>/dev/null)" = "$id" ] \
        || echo "not the image $ref names now: $id"
    done
$d images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}}'
$d system df
$d images -qf dangling=true | wc -l
$d volume ls -qf dangling=true | wc -l
```

The format strings name every field: never a bare `inspect`, which
prints the environment (`rules/secrets.md`). `nerdctl` has no
`compose ls` and no dangling-volume filter
(<https://github.com/containerd/nerdctl/blob/main/docs/command-reference.md>):
name those two as not checked. Its `inspect` answers in Docker's
format; where a template stops on a field it lacks, drop that field
and name it as not checked.

Name each container in a finding as `<project>/<service>` when the
compose labels are set, and by its name otherwise. A container that
another check reports — Home Assistant, Pi-hole, AdGuard Home, an
appliance's app — is reported there, not again here.

## Engine

- **CRITICAL** if the daemon does not answer — that says nothing
  about the containers, never that there are none. Permission denied
  on its socket is not this: the check needs the access from
  `rules/privilege-escalation.md`, or is reported as skipped.
  Rootful Podman has no daemon; a `podman` that fails is reported
  with its error.
- Report the engine and version, rootful or rootless (`name=rootless`
  among Docker's `SecurityOptions`, `rootless=true` for Podman), and
  the owners queried. The engine is a package: its updates are the
  pending-updates check's, and a version is graded only through
  `rules/version-check.md`.
- **INFO** for each line `docker info` prints under warnings. One
  about the API on TCP without encryption is **WARN** here and the
  security skill's to rate
  (`.agents/skills/hostwarden-security/references/containers.md`).

## Containers That Should Run

A restart policy other than `no`, a Quadlet or own unit
(`unit=` set, `rules/containers.md` → Find What Defines the
Container), or a compose project marks a container as meant to run.
Docker ignores the policy of a container stopped by hand until the
daemon restarts or the container is started again, and the policy
acts only once a container has run for ten seconds
(<https://docs.docker.com/engine/containers/start-containers-automatically/>).

- **CRITICAL** for a container in state `restarting`: a restart
  loop, the service is down. Read its logs (`rules/containers.md` →
  Logs) and quote the last error.
- **WARN** for a container meant to run that exited with a code
  other than those of a stop: 0, 143 (SIGTERM, which a stop sends
  first) and 137 without `oom=true` (SIGKILL after the stop's
  timeout).
- **WARN** for `oom=true`: the kernel killed it for memory, whatever
  the state is now.
- **WARN** for `health=unhealthy`.
- **WARN** for a running container with `restarts` above 0: its
  policy restarted it that many times. Name the count and the last
  error from the logs.
- **INFO** for a container meant to run that exited as from a stop:
  stopped by hand or finished. Ask once; when the user says it is
  stopped on purpose, record it in `memory.md` so the next run stays
  quiet.
- **INFO** for a running container of a compose project with policy
  `no` and no unit: it does not come back after a reboot or a daemon
  restart. On Podman, a restart policy acts after a reboot only where
  `podman-restart.service` is enabled, for a rootless owner as that
  owner's user unit
  (<https://docs.podman.io/en/latest/markdown/podman-run.1.html>); a
  Quadlet container restarts by its unit's `Restart=` instead, and
  its own policy is no finding.

## Disk

The fill level itself is the baseline's Disk Usage. What this adds is
the cause, when the engine's data root (`root=`) sits on a file
system past its WARN threshold.

- **INFO** with what `system df` calls reclaimable, the number of
  dangling images and of volumes no container uses. An unused volume
  is not an unneeded one: a stopped stack keeps its data there.
  Never prune: it deletes data, and `rules/containers.md` → Changes
  says how to ask.
- **WARN** for a container log file above 1 GB (the `du` line, in
  MB). **INFO** for each container on `json-file` with no
  `max-size`, from the container or from `log-opts` in
  `daemon.json`: the `json-file` driver does not rotate by default,
  and a change in `daemon.json` reaches only containers created
  after it
  (<https://docs.docker.com/engine/logging/drivers/json-file/>).
  The remedy is `max-size` and `max-file` in `log-opts`, then a
  recreate of each container: a restart, so ask. A container on
  `journald`, Podman's usual default, is no finding: the journal
  rotates itself.

## Images

- **WARN** for an image of a running container that was built more
  than a year ago (`CreatedAt`), **INFO** past six months: whatever
  its base image fixed since is not in it. The build date is the
  image's, not the pull's.
- **INFO** for a container whose image is `:latest` or names no tag:
  what runs changes at the next pull, and which version runs is not
  written anywhere. A digest (`@sha256:`) is a pin. On an appliance
  whose UI tracks updates by tag, as Unraid's Docker tab and
  Synology's Container Manager do for `latest`, it is how the UI
  works: no finding.
- **INFO** for each `not the image … names now` line: a newer image
  was pulled and the container still runs the old one. The next
  recreate brings it in, planned or not.
- **Pending image updates** are reported only from what the host
  already knows, and the report says which source it used:
  - the appliance's own record: Unraid's update status, TrueNAS's
    `image_updates_available`, what the user reads in Synology's
    Container Manager;
  - Watchtower or Diun, where one runs: what its log last reported
    (`rules/containers.md` → Logs). A Watchtower that is not in
    monitor-only mode updates containers by itself: **INFO**, once;
  - Podman's `podman auto-update --dry-run`, for containers with the
    `io.containers.autoupdate` label, and a registry digest lookup —
    `docker buildx imagetools inspect <ref> --format
    '{{.Manifest.Digest}}'` against `docker image inspect --format
    '{{join .RepoDigests " "}}' <ref>`, or `skopeo inspect --format
    '{{.Digest}}' docker://<ref>` — only after the user agreed:
    each is a request to the registry, which rate-limits anonymous
    clients.

  With none of them, say image updates were not checked. Never
  `pull` in housekeeping: it downloads, and the next recreate
  applies what it fetched.

## Report

In the Services section, one line per engine and owner:

```
Containers    OK — docker <version> rootful, 14 running, 1 stopped on purpose
Containers    alice: podman <version> rootless, 3 running
```

Findings go to Issues, one line each, in the skill's format:

```
CRITICAL  Container media/jellyfin restarting (restart loop)
WARN      Container db/postgres exited 1, policy unless-stopped
INFO      Docker: 12.4 GB reclaimable, 7 dangling images, 3 unused volumes
```
