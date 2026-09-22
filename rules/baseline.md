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
counts. One firewall manager, never a second on top
(`rules/service-class-check.md`). In a container, the firewall
inside it counts; the host's does not. Checked by housekeeping's
Firewall Status and the security audit's `references/firewall.md`.

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

A guest that reads no cloud-init gets the same sections in the
form its OS or its installer reads, kept beside them and numbered
the same way, named for the format:
`<family>-ign-<n>.bu` for Butane, with `<family>` as `fcos` or
`flatcar`; `<family>-ks-<n>.cfg` for kickstart;
`<family>-preseed-<n>.cfg` for preseed;
`<family>-autoinstall-<n>.yaml` for Ubuntu's autoinstall; and
`<family>-ay-<n>.xml` for AutoYaST. An answer file that hands the
baseline to cloud-init rather than restating it records which
cloud-init version it carries, so one line of memory still says
what a guest was built with. A host's `# baseline` block is not
part of it: the guest has no memory yet, and the hypervisor's is
about the hypervisor.

What one guest adds at creation — its names, a password the user
asked for — is never part of a numbered file. The guest's memory
records the version it was created with and names such an
addition, `- Baseline: debian-3 (created 2026-09-22, password)`,
and a server brought up to the baseline later
`- Baseline: retrofitted 2026-09-22`. A deviation the user chose
at creation goes into the guest's `rules.md` as an `## Add:` under
`# baseline`, so the audits take it as intended.
