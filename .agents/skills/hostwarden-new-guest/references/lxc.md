# Classic LXC

`lxc-create` and the download template, on a host whose
`Hypervisor:` line says `LXC` rather than Incus or LXD. Sources:
the `lxc-create` manual, the template itself
(<https://github.com/lxc/lxc/blob/main/templates/lxc-download.in>),
and <https://linuxcontainers.org/lxc/documentation/>.

LXC hands a container no configuration of its own: there is no
`cloud-init.user-data` key and no cloud-init drive. The baseline
reaches the container through a seed written into its root
filesystem before it is started for the first time. Once
`lxc-start` has run, that door is closed: the container is a
server, and nothing in this file applies to it any more.

## Before the creation

In one call: the defaults, the capacity check, and what the
download server has.

```bash
lxc-ls -f
df -h /var/lib/lxc
free -m
nproc
ip -br link show type bridge
grep -hs 'lxc.idmap' /etc/lxc/default.conf
lxc-create -n probe -t download -- --list
```

The `--list` output names the distribution, release and variant to
choose from; `lxc.idmap` in the host's defaults says whether
containers here are unprivileged.

## The image

The download template fetches from `images.linuxcontainers.org`
and checks the index's signature; `--no-validate` would turn that
off and is never passed.

```bash
lxc-create -n web4 -t download -- \
  -d debian -r trixie -a amd64 --variant cloud
```

- `--variant cloud` is what makes this path work: the default
  variant carries no cloud-init, the cloud variant installs it.
  `lxc-create -n x -t download -- --list` shows which
  distribution, release and variant the server has; a release is
  named as that list names it, by codename where the list does.
- Where no cloud variant exists for the distribution the user
  asked for, this path ends. Say so, offer a distribution that has
  one, and stop — a container reachable only by a password typed
  on the host's console is not a server Hostwarden can manage.
- `-a` is the host's architecture unless the user says otherwise.

## Waking cloud-init in it

The images built for LXC ship cloud-init switched off:
distrobuilder's LXC target "disables cloud-init", writing
`/etc/cloud/cloud-init.disabled` into the root filesystem
(<https://github.com/lxc/distrobuilder/blob/main/generators/cloud-init.go>).
Nothing starts it while that file is there.

Two writes into `/var/lib/lxc/<name>/rootfs` before the first
start: take `/etc/cloud/cloud-init.disabled` out of it, and put
the seed in (`references/user-data.md` → The seed) in its
manager-owned form, since LXC owns the container's network,
hostname and `/etc/hosts`.

Those two, the configuration below, the start and the wait go in
one call: nothing between them needs a decision.

```bash
lxc-start -n web4
timeout 570 lxc-attach -n web4 -- cloud-init status --wait --long
lxc-attach -n web4 -- cat /etc/ssh/ssh_host_ed25519_key.pub
lxc-info -n web4 -c lxc.cgroup2.memory.max
```

A container whose `cloud-init status` never leaves `not run` has
the units disabled rather than only the marker file: read
`lxc-attach -n <name> -- systemctl is-enabled cloud-init.service`
and report what it says. Do not enable services by hand in a
container that was meant to configure itself; `SKILL.md` → After
creation says what becomes of a guest that failed, and removing
one is the user's explicit request
(`rules/system-containers.md` → Changes).

## The container's configuration

`/var/lib/lxc/<name>/config` holds what LXC itself owns. The
defaults the template writes are kept; these are set before the
first start:

- `lxc.uts.name = web4.example.com` — the guest's FQDN.
- `lxc.start.auto = 1` where the guest starts with the host, which
  is the default answer in the request.
- The network: `lxc.net.0.type = veth`,
  `lxc.net.0.link = <bridge>`, `lxc.net.0.flags = up`, and
  `lxc.net.0.ipv4.address` with `lxc.net.0.ipv4.gateway` for a
  static address. Read the file first and change only the lines
  that are wrong: the template's other settings, the
  `lxc.include` of the distribution's common configuration above
  all, are what make the container boot.
- An unprivileged container also needs `lxc.idmap` lines, which
  the host's own setup decides. Where the host runs containers
  privileged, say so in the plan in one line rather than changing
  it, and record it on the guest as
  `rules/system-containers.md` → Privileges says.

## Limits worth saying out loud

LXC has no resource limits of its own in the sense Incus does:
`lxc.cgroup2.memory.max` and `lxc.cgroup2.cpu.max` are cgroup
settings written into the configuration, and what they accept
depends on the host's cgroup version. The `lxc-info` line in the
call above reads back what the host enforces; report that, never
what was asked for.

The memory, CPU and disk figures from the request are still shown
in the plan, with one line where the host cannot enforce one of
them.

## After creation

`SKILL.md` → After creation from step 2, with `lxc-attach` in
place of `pct exec`. The guest's memory records
`- Origin: LXC download image (<distribution> <release> cloud)`
beside the baseline line, and `rules/system-containers.md` covers
the container as a target from then on.
