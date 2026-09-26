---
sidebar_position: 2
description: Validating a branch on a test clone, trying a command in
  a lab container, and lab VMs for what a container cannot answer.
---

# Testing a change

## Validating a branch

Validating a branch needs the branch's own instructions on a server,
and those never go near production. Keep a second operations clone
for test servers only:

```
git clone <hostwarden-url> hostwarden-test
cd hostwarden-test
git switch <branch>
bin/hostwarden-init
```

Give it a workspace of its own — never `--clone` of the production
one — and list your production hosts in its `memory/blacklist.md`.
Off `main` it does not auto-update; `git pull` brings the branch's
next push, and `bin/hostwarden-update --unpin` makes it follow
`main`.

## Trying a command

Trying a command needs no server at all when a container answers it:
whether a flag exists in this release, what a package is called,
what a config test prints. `bin/hostwarden-lab` runs one per family —
debian, ubuntu, rhel (AlmaLinux), fedora, suse (openSUSE Leap),
alpine — from the official image of the current stable release, with
docker or podman (OrbStack brings docker on macOS;
`HOSTWARDEN_LAB_ENGINE` picks one where both are installed):

```
bin/hostwarden-lab exec debian -- apt-get -s install nginx
bin/hostwarden-lab list
bin/hostwarden-lab down
```

A lab container is neither a server nor local mode, so a development
session uses it directly. Each worktree gets its own, labelled with
the worktree's name and a checksum of its path, and `down` removes by
that label alone. It also self-expires: `up` gives it a fixed
lifetime, `HOSTWARDEN_LAB_TTL` seconds (default 6h), and the engine
removes it on its own once that ends, whether or not `down` was ever
run — a command still running at that moment is killed with it. They
run without a published port, a host path, the engine's socket or any
extra privilege. The lab never starts the engine; start OrbStack,
Docker Desktop or `podman machine` yourself.

The mode guard decides what a development session may do to the
local container engine:

- **Allowed:** reading, pulling, building, running and creating on
  the local engine; `bin/hostwarden-lab exec` and
  `bin/hostwarden-lab down`, which touch the lab's own containers only.
- **Denied:** a run that asks for host access or publishes a port; a
  build that writes its result to this machine; another engine by
  `--context`, `--host` or `DOCKER_HOST`; `exec`, and every command
  that changes containers, images or volumes.

On Linux the engine runs as root; on macOS a bind mount reaches your
home — which is why a run that asks for host access is denied.

## Lab VMs

A container cannot answer for systemd services, the firewall, kernel
parameters, a reboot or the SSH pipeline, and there is no container
for FreeBSD or macOS. For the Linux cases, a **lab VM** is a test
server of the test clone above:

```
bin/hostwarden-lab vm up debian --ops ~/hostwarden-test
```

It uses OrbStack or Lima, whichever is installed, and refuses a
`--ops` that is not an operations clone, is the checkout the worktree
came from, or has no host on its blacklist. OrbStack machines mount
your Mac's home by default; the lab creates them `--isolated`,
without that mount, and installs sshd with your public key for root,
so the host is `<name>.orb.local`. Lima's templates mount your home
too; the lab creates them `--mount-none`, and the host is
`lima-<name>` once `~/.ssh/config` has `Include ~/.lima/*/ssh.config`.

The development session never uses the VM — the mode guard denies
`orb`, `limactl shell` and `lima` commands inside one — and hands its
question to a session in the test clone instead (see
[Asking an operations session](index.md#asking-an-operations-session)).
The guard also denies creating, starting, stopping, deleting or
changing a VM directly: `bin/hostwarden-lab vm up` creates and starts
one without your home mounted, and `bin/hostwarden-lab vm down`
deletes the VMs that worktree created, and no other.
