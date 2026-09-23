# Server Baseline

What every server Hostwarden manages is expected to have. One list,
read wherever a server is judged or built:

- the security audit and housekeeping report what a server lacks;
  the checks named below own the commands and the severities,
  except for Admin Keys, Mail Relay and Monitoring, rated at the
  end;
- a new guest gets all of it at creation (`hostwarden-new-guest`);
- an existing server is brought up to it on request
  (`hostwarden-baseline`).

The user's additions and changes are an override
(`rules/overrides.md`): `memory/custom-rules/baseline.md`, and a
`# baseline` block in `memory/servers/<hostname>/rules.md` for one
host. Read both before acting on this file. An override of *what*
is expected goes there; one of *how* a check runs goes to that
check's own file. The sections Admin Keys to Monitoring below are
empty until an override fills them:

    ## Add: Admin Keys
    - alice: ssh-ed25519 AAAAC3Nza… alice@example.com

    ## Add: Timezone
    Europe/Berlin

    ## Replace: Time Sync
    chrony with ntp1.example.com and ntp2.example.com.

The host's family file says how each section is set up there, and
its appliance, platform and role files say what counts instead
(`rules/os-detection.md` → Layers): Proxmox VE's own firewall,
for instance, or what `rules/role/workstation.md` holds a
workstation to.

## Firewall

Enabled, with incoming traffic denied or dropped by default, and
every port sshd listens on kept open (`AGENTS.md` → Critical
Safety Rules). The family file names the tool; native nftables
counts, and so does iptables on the legacy backend that a
service or hook restores. One firewall manager, never a second on
top (`rules/service-class-check.md`). In a container, the firewall
inside it counts; the host's does not. Checked by housekeeping's
Firewall Status and the security audit's `references/firewall.md`.

### Filtering in front of the host

A firewall the host cannot see — the provider's, a cloud
security group, a router — is recorded in the host's `memory.md`
as the user describes it, per family:

```markdown
- Upstream firewall: provider, in front of 203.0.113.10 and
  2001:db8:5::10; v4 and v6 inbound: all allowed except tcp/22,
  tcp/8006 (admin addresses only) (user, 2026-09-23)
```

The line names what it stands in front of: the addresses, or the
interface. Without that, ask; a line that does not say covers
nothing.

`none (user, <date>)` records that nothing filters in front.
Hostwarden cannot read that firewall and never calls the line
verified: it is what the user said, on that date.

Every finding that the host does not filter a family — no
firewall, a firewall off, the IPv6 gap — is weighed here, on
every platform, whichever check reports it:

- **No line.** An interactive session asks the user once what
  filters in front of the host and what it lets in per family,
  and records the answer, `none` included. A scheduled run does
  not ask and adds "no upstream firewall recorded" to the
  finding.
- **`none`.** The finding stands.
- **A line.** Work out which ports still reach the host in that
  family: every port it listens on at an address other than
  loopback, private and VPN addresses included (the security
  skill's `references/listening-services.md` lists them), minus
  those a DNAT hands
  to a guest first (the `Inbound` lines of a current Traffic
  flow profile, `rules/network.md`), minus what the line blocks.
  The line blocks a port only where it stands in front of every
  way to it: a port bound to an address it does not cover, or
  bound to all addresses on a host with another interface
  carrying an address — a second NIC, the LAN, a VPN or
  overlay — is still reachable that way, and stays.
  Under "all denied except P" everything but P is blocked, under
  "all allowed except P" only P, and a port limited to named
  sources counts as blocked. No port left → **INFO** "Host does
  not filter <family>; filtered in front: <the line>", in place
  of the finding. Ports left → the finding keeps its severity
  and names them: **CRITICAL** "No active firewall: tcp/111,
  tcp/3128 reachable over IPv6". The line never lowers it.

## Automatic Security Updates

The family file's mechanism installed, enabled, and covering the
security archive, with its reports mailed to root. Checked by
housekeeping's Automatic Security Updates.

## Time Sync

One time service, running and synchronized, and the timezone the
Timezone section names. A container keeps the host's clock and
runs none. Checked by housekeeping's time sync check.

## SSH Login

sshd accepts keys only: no password and no keyboard-interactive
login, and root by key or not at all. An account has a password
only where the user asked for one at creation. Checked by the
security audit (`references/ssh.md`).

Set only in the first-boot configuration of a guest that has never
run (`AGENTS.md` → Critical Safety Rules). On a running server,
Hostwarden reports what differs and gives the user the change to
make.

## Journal

On a host with systemd, the journal is persistent, so the activity
check (`rules/activity-check.md`) still sees Hostwarden's lines
after a reboot. Hosts without systemd log to files and need
nothing here. Checked by housekeeping's Journal.

## Guest Agent

A VM runs its hypervisor's guest agent, and the hypervisor has it
enabled: `qemu-guest-agent` under KVM, QEMU and Proxmox VE.
Checked from the host, in housekeeping's `references/guests.md`.

## Backup

A backup exists (housekeeping's `references/backup-presence.md`).
For a guest, the hypervisor's backup job counts when it includes
the guest.

## Admin Keys

The SSH public keys that may log in as the SSH user
(`rules/ssh-user.md`). Public keys only: a private key never goes
into memory (`rules/secrets.md`). Empty: asked at creation.

## Timezone

The system timezone, as a tz database name. Empty: the image's
default, which is UTC in the official cloud images.

## Mail Relay

The host that root's mail is sent through, and the MTA that sends
it (`rules/service-class-check.md` for an MTA already there). A
password for it is set up after the first boot
(`rules/secrets.md`). Empty: no relay.

## Monitoring

The agent every server runs, how it is installed, and what it
needs configured. Empty: none.

## The Sections an Override Fills

Housekeeping checks them as the override describes them: an admin
key missing from the SSH user's `authorized_keys`, compared by
fingerprint (`rules/secrets.md`), is **INFO**; a relay or
monitoring agent that is missing or not running is **WARN**. A key
that is not listed is no finding: a deploy key has its place
(`hostwarden-deploy-user`).

## Rendered Versions

A new guest gets this file as cloud-init user-data, rendered from
it, its global override and the family file, and kept in the
workspace as `memory/baseline/<family>-<n>.yaml`, or
`<family>-ct-<n>.yaml` for a container; `<n>` counts up whenever
the rendered content changes.

Fedora CoreOS and Flatcar read no cloud-init, so they get a
rendering of their own beside it, `<family>-ign-<n>.bu`, with
`<family>` as `fcos` or `flatcar`. It is numbered by the same
rule: the baseline's content decides `<n>`.

Everything else that cannot be handed the file at boot carries one
instead of restating it — an installer's answer file, a seed in a
container's root filesystem or in a disk image. A carrier is not a
rendering: it is numbered by its own content, which changes with
the disk layout or the network as much as with the baseline, and
it records which rendering it carries. The answer files are
`<family>-ks-<n>.cfg` for kickstart, `<family>-preseed-<n>.cfg`
for preseed, `<family>-autoinstall-<n>.yaml` for Ubuntu's
autoinstall and `<family>-ay-<n>.xml` for AutoYaST.

Where a manager holds a rendering as a named object of its own, an
Incus profile for instance, the name is
`hostwarden-baseline-<family>-<n>` and the object is never edited
afterwards: a new version is a new object.

A host's `# baseline` block is not part of any of it: the guest
has no memory yet, and the hypervisor's is about the hypervisor.

What one guest adds at creation — its names, a password the user
asked for — is never part of a numbered file. The guest's memory
records the version it was created with and names such an
addition, `- Baseline: debian-3 (created 2026-09-22, password)`,
and a server brought up to the baseline later
`- Baseline: retrofitted 2026-09-22`. A deviation the user chose
at creation goes into the guest's `rules.md` as an `## Add:` under
`# baseline`, so the audits take it as intended.
