---
sidebar_position: 3
description: Changes the file that recreates a container, not the
  running one.
---

# Services in containers

For a service that runs in Docker, Podman, or containerd,
Hostwarden finds the compose file, Quadlet, unit or tool that
recreates the container and changes that, after a backup, not the
running container. A restart, pull, removal or prune is asked
first. `exec` into a container only reads. A container an
appliance's web UI owns is left to that UI, and Kubernetes
workloads are reported, never changed.
