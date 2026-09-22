# Home Assistant OS

Base: none
Hardware: any

Home Assistant OS (HAOS) is Linux, but no family file applies: no
package manager, a read-only root filesystem, and everything managed
through the Supervisor. **Hostwarden never works on the HAOS host
itself.** It works from inside an SSH app's container and changes the
system only through what Home Assistant offers there: the `ha` CLI,
which talks to the Supervisor, and the configuration directory
mounted into the container. Where `AGENTS.md` or a baseline expects
something a Linux server has (firewall, automatic updates, `sudo`),
this file says what to check instead.

Sources unless noted: the developer docs,
<https://developers.home-assistant.io/docs/operating-system>, the
user docs, <https://www.home-assistant.io/>, and the
`home-assistant/cli`, `home-assistant/addons` and
`home-assistant/operating-system` repositories.

## Where You Land

Hostwarden connects through one of two SSH apps:

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

Record which one in server memory
(`Appliance: Home Assistant OS <version>, via <app name>`).

The HAOS host has its own SSH on port 22222, dropbear as root. It is
off unless someone imports a key from a USB stick, and the docs call
it "not for end users". If the detection probe lands there
(`ID=haos`), stop: tell the user that Hostwarden works through an
SSH app only, and do nothing on the host. Never set up host SSH.

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
Never read, print or pass the token itself (see Credentials), and do
not reach for a login shell
(`zsh -l -c …`) instead: the Advanced app's login profile starts its
welcome banner and waits for input.

## Version Detection

- Versions: `ha os info`, `ha core info`, `ha supervisor info`.
  `ha info` gives an overview.
- Health: `ha resolution info` lists issues, suggestions, and
  whether the system is unsupported or unhealthy. Read it on every
  connection, in the call that checks the versions.

## What Does Not Apply

- **Packages.** The host has no package manager and its system
  partitions are read-only. `apk add` in an app container is lost
  when the container is recreated. Do not install tools there. If
  one is needed for good, the user adds it to the app's package
  option. Language runtimes (the `hostwarden-runtimes` skill) do
  not belong here either.
- **Root SSH fallback.** Probe `sudo` as usual
  (`rules/privilege-escalation.md`); there is no root SSH to the
  host to fall back on.
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
- The backup directory is `/homeassistant/.hostwarden-backups/`.
  Never `/share`: every app that maps it can read it, and copies of
  `secrets.yaml` do not belong there.
- Never print `secrets.yaml` (`rules/secrets.md`).
- **Config test:** `ha core check` validates the configuration on
  disk. It must pass before any restart.
- `ha core restart` restarts Home Assistant and interrupts every
  automation for the duration. `rules/service-reload.md` decides
  when to ask. `ha core rebuild` recreates the container; ask
  first.
- Entities, automations and dashboards are Home Assistant's own
  domain, changed through its UI or API. Hostwarden edits YAML only
  where the user keeps that configuration in files.

## Apps and Stores

- `ha apps` lists, starts, stops, updates and installs apps; ask
  before installing, removing or stopping one.
- `ha store` manages the app repositories. A repository other than
  the official ones is a third-party source (`AGENTS.md`: official
  repos only): ask before adding one, and report the ones present.

## Configuring Home Assistant with an AI Client

A user who wants an AI client to work on Home Assistant itself —
entities, automations, dashboards — needs an MCP server there.
Hostwarden sets up what SSH reaches and hands the rest to the user;
the work over MCP then happens in that client, outside Hostwarden.

- **Model Context Protocol Server**, built into Home Assistant
  (<https://www.home-assistant.io/integrations/mcp_server/>): set up
  in the UI only, and it offers the Assist API — controlling and
  querying the entities the user exposed. It cannot change the
  configuration.
- **ha-mcp**, a community project
  (<https://github.com/homeassistant-ai/ha-mcp>): can also edit
  automations, scripts, dashboards and YAML. It comes as an app
  ("Home Assistant MCP Server") and as a custom component through
  HACS.

What Hostwarden does for ha-mcp as an app, each step after asking:
add its repository and install and start the app (Apps and Stores),
then check that it runs.

What stays with the user: the built-in integration, HACS and the
custom component (UI only), exposing entities, and registering the
server in their client — Hostwarden names the steps and the command
the client's documentation gives, and runs none of them.

**The app's MCP URL is a secret.** Its path is a random token and
the only thing guarding a server that can change the whole
configuration; the app prints it in its log. Never read it out of
`ha apps logs` into the conversation, memory or a report
(`rules/secrets.md`): the user copies it from the app's Logs tab.

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
- An encrypted backup needs a password (see Credentials): the user
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
  Log to the local changelog only (`rules/changelog.md`); the
  activity check reads that changelog instead of a journal.

## Housekeeping and Audits

- The Linux baseline does not apply (see What Does Not Apply).
  Housekeeping reads, in one call — a non-root login prefixes
  `sudo -n` (The `ha` CLI):
  ```
  /command/with-contenv sh -c 'ha available-updates;
    ha resolution info; ha backups list; ha host info;
    ha time info; ha mounts info'
  ```
  Findings: pending updates, reported issues, no recent backup,
  disk usage, time not synchronised, a backup or media mount down.
- A security audit reports instead:
  - the SSH app's options (password login, keys, user);
  - which apps publish ports — a running ha-mcp app is WARN: full
    configuration access over plain HTTP, guarded only by its
    secret URL (see Configuring Home Assistant with an AI Client);
  - `ha security info`;
  - app repositories beyond the official ones (`ha store`);
  - the `http:` settings in the configuration (trusted proxies,
    login attempt bans), and credentials written into the
    configuration instead of `secrets.yaml`.

## Credentials

- `ha authentication` resets a user's password: a credential
  rotation, so ask first.
- The Supervisor token, backup passwords, the password of
  `ha authentication` and the credentials of `ha mounts` and
  `ha docker` registries fall under `rules/secrets.md`: never read
  or print them, never pass them as arguments. The token stays in
  `/run/s6/container_environment/`.

## Never

- `ha host shutdown` — powers the device off (`AGENTS.md` taboo).
- `ha os datadisk move` or `wipe` — moves or erases the data
  partition.
- `ha backups restore` without an explicit request.
- Editing files under `/homeassistant/.storage/` by hand: the UI
  owns them.
