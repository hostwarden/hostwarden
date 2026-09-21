# Home Assistant OS

Base: none

Home Assistant OS (HAOS) is Linux, but no family file applies: no
package manager, a read-only root filesystem, and everything managed
through the Supervisor and its `ha` CLI. Where `AGENTS.md` or a
baseline expects something a Linux server has (firewall, automatic
updates, `sudo`), this file says what to check instead.

Sources unless noted: the developer docs,
<https://developers.home-assistant.io/docs/operating-system>, the
user docs, <https://www.home-assistant.io/>, and the
`home-assistant/cli`, `home-assistant/addons` and
`home-assistant/operating-system` repositories.

## Where You Land

`ssh root@<host>` almost never reaches the HAOS host. There are
three ways in:

- **Terminal & SSH app** (official, slug `ssh`): a container
  (Alpine) with the `ha` CLI, bash, and root inside the container
  only. Its docs: "Regardless of how you connect … you end up in
  this app's container." The SSH port is whatever the user set in
  the app's options.
- **Advanced SSH & Web Terminal** (community): also a container,
  zsh, with the host network and the host journal (read-only). The
  login is whatever user the app's options set, often a non-root
  one with `sudo`. `docker` works only when the user has turned
  protection mode off.
- **Host SSH on port 22222**: dropbear on the HAOS host itself,
  root, keys only. It exists for developers; the docs say it is
  "not for end users". Never set it up on your own.

Record which of the three it is in server memory
(`Appliance: Home Assistant OS <version>, via <app name | host port
22222>`).

## The `ha` CLI

A command sent over SSH has no `SUPERVISOR_TOKEN` in its
environment, and every `ha` call then answers "unauthorized". Send
each one through `/command/with-contenv`, which loads the app
container's environment, token included. It needs root, so a
non-root login prefixes `sudo -n`:

```
sudo -n /command/with-contenv ha os info
```

Every `ha` command in this file is written bare and runs this way.
Never read, print or pass the token itself: not with `--api-token`
(`rules/secrets.md`), not out of
`/run/s6/container_environment/`. Do not reach for a login shell
(`zsh -l -c …`) instead: the Advanced app's login profile starts its
welcome banner and waits for input.

## Version Detection

- Versions: `ha os info`, `ha core info`, `ha supervisor info`.
  `ha info` gives an overview.
- Health: `ha resolution info` lists issues, suggestions, and
  whether the system is unsupported or unhealthy. Read it on every
  connection, in the same call as the activity check.

## What Does Not Apply

- **Packages.** The host has no package manager and its system
  partitions are read-only. `apk add` in an app container is lost
  when the container is recreated. Do not install tools there. If
  one is needed for good, the user adds it to the app's package
  option. Language runtimes (the `hostwarden-runtimes` skill) do
  not belong here either.
- **Root SSH fallback.** The official app logs in as root of its
  container, the Advanced app as the user its options set, often
  with `sudo`; probe it as usual (`rules/privilege-escalation.md`).
  Either way the container reaches the host only as far as the
  Supervisor allows, and there is no root SSH to the host to fall
  back on.
- **Firewall.** HAOS has no user-managed firewall. A missing one is
  not a finding. Exposure is decided by the router and by which
  apps publish ports. Core listens on 8123 by default, the
  Supervisor's observer on 4357.
- **Automatic security updates.** There is no
  `unattended-upgrades`. The Supervisor updates itself; Core, OS
  and apps wait for the user. Pending updates are the finding, not
  a missing package.
- **sshd.** The SSH app generates its SSH config from its options.
  Changes go through the app configuration in the UI, not through
  files.
- **Containers.** Do not manage Home Assistant's containers with
  `docker`, even where the Advanced app allows it. Use `ha`.

## Configuration

- The configuration lives in `/homeassistant` (`/config` links to
  it in the official app). Also mounted: `/share`, `/ssl`,
  `/media`, `/backup`.
- `rules/backups.md` applies, but keep the copies in
  `/homeassistant/.hostwarden-backups/`: the app container's own
  filesystem is replaced when the app updates, and `/share` is
  shared with any app that maps it, so copies of `secrets.yaml` do
  not belong there.
- Never print `secrets.yaml` (`rules/secrets.md`).
- **Config test:** `ha core check` validates the configuration on
  disk. It must pass before any restart.
- `ha core restart` restarts Home Assistant and interrupts every
  automation for the duration. `rules/service-reload.md` decides
  when to ask. `ha core rebuild` recreates the container; ask
  first.

## Updates

- List pending updates: `ha available-updates`.
  `ha refresh-updates` reloads the list.
- Apply, one at a time and only after asking:
  - `ha core update --backup`
  - `ha apps update <slug> --backup`
  - `ha os update` **reboots the host.** HAOS writes the other A/B
    slot and falls back to the old one after failed boots; manual
    rollback is `ha os boot-slot other`.
  - `ha supervisor update` is rarely needed; the Supervisor updates
    itself unless the user turned that off.
- Add-ons are called "apps" since 2026.2. `ha apps` is the command;
  `ha addons` still works as an alias.

## Backups

- `ha backups list`; `ha backups new --name <name>` creates a full
  backup in `/backup`.
- Never pass `--password`: it puts the password on the command line
  (`rules/secrets.md`). If the backup must be encrypted, the user
  creates it in the UI.
- Take one before any update that is not already run with
  `--backup`, and before larger configuration changes.

## Network

- `ha network info`; changes go through
  `ha network update <interface> …`. A wrong address, gateway or a
  disabled interface cuts every way in, including yours. Ask first,
  and make sure the user has console access.

## Logs

- `ha core logs`, `ha supervisor logs`, `ha apps logs <slug>`,
  `ha host logs` (the host journal, persistent). There is no
  `ha os logs`. Never add a follow flag over non-interactive SSH.
- `logger` inside an app container does not reach the host journal.
  Log to the local changelog only (`rules/changelog.md`) and record
  `Journal: none` in server memory.
- The activity check still reads the host journal, because a session
  on host port 22222 can write there:
  `ha host logs -t hostwarden -n 20` and `ha host logs -t heinzel
  -n 20`. With `Journal: none`, an empty result says nothing about
  this installation's own sessions; the local changelog does.

## Housekeeping and Audits

- The Linux baseline does not apply (see What Does Not Apply).
  Check `ha available-updates`, `ha resolution info` and
  `ha backups list` instead. For a security audit, also report the
  SSH app's options and which apps publish ports.

## Never

- `ha host shutdown` — powers the device off (`AGENTS.md` taboo).
- `ha os datadisk move` or `wipe` — moves or erases the data
  partition.
- `ha backups restore` without an explicit request.
- Editing files under `/homeassistant/.storage/` by hand: the UI
  owns them.

## Supervised and Core Installs

Home Assistant Supervised and Core on a normal distribution have
been unsupported since 2025.12
(<https://www.home-assistant.io/blog/2025/05/22/deprecating-core-and-supervised-installation-methods-and-32-bit-systems/>).
On such a host the distribution's family file applies to the host,
and this file to the `ha` CLI. Report the unsupported install once
as INFO; migrating to HAOS or the Container install is the user's
decision.
