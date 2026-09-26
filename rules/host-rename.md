# Renaming a Host

A rename changes the name a host gives itself, and with it every
place that names the host: its own files, its hypervisor, memory,
and much that lies outside the host, where Hostwarden cannot see.
So it runs only when the user asks for it, one host at a time. It
never runs from a schedule, as a batch, or in a run with nobody to
ask. A request that names several hosts gets an inventory and a
question for each (`rules/multi-host.md`).

A rename is a change like any other: the pipeline runs first, the
host's session register applies (`rules/parallel-sessions.md`),
every edited file is backed up first (`rules/backups.md`), and the
journal gets a line and the changelog an entry
(`rules/changelog.md`). On a host whose memory has a
`Config management:` or `Provisioned by:` line,
`rules/config-management-changes.md` comes first: the tool may
hold the name.

## The New Name

The user gives it, as the full name with its domain. The memory
directory takes the form the old one had: the full name where it
was named by one, the first label where it was named by a short
name, with the suffix a second guest of the same name carries,
and for a WSL instance `<new windows hostname>-wsl-<distribution>`
(`rules/machine-memory.md`). Where a `rules/naming-scheme.md` block
applies to the host, check the new name against it
(`rules/naming-scheme.md` → Checking a name) and say in the
question where it departs; a yes to a name that fails it adds an
`Exempt:` line with the reason and who and when to
`memory/naming.md` and the rename goes on with that name; a no asks
for another new name instead of going on with one the user just
declined to keep off-scheme. Where no block applies, the user's
word decides.

Before anything else, on the workstation:

- **Syntax.** Lower case letters, digits and hyphens, in at least
  two labels joined by dots; each label starts and ends with a
  letter or digit and has at most 63 characters (RFC 1123, section
  2.1):

  ```
  l='[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?'
  printf '%s\n' 'web2.example.com' | grep -E "^$l(\.$l)+\$"
  ```

  No output: say what is wrong and ask for another name.
- **Unused.** The directory name the new name gives, in the old
  one's form, is free: no `memory/machines/<it>` exists, as a
  directory or a link, and no `guests.md` entry links `→ <it>`.
  Nor is the full new name a directory, a link or a `→` target,
  where the form is a short one. Any of them means the name
  belongs to another host: stop and tell the user.
- **The access lists.** The blacklist and read-only checks run
  for the new name as for any target (`rules/access-control.md`).
  A listed new name stops the rename.
- **Where it points.** Resolve it as `rules/dns-aliases.md` →
  Detection step 1 does. Nothing yet is normal: it is added in The
  Order, step 1, by Hostwarden or the user as Outside decides. An
  address the host has is normal too. Any other address means the
  name belongs to another machine: stop and tell the user.

## Where Hostwarden Hands Over

Memory answers most of these before the host is reached; the
inventory below finds the rest. Say which case applies and what
the user's step is, and stop.

**The user renames the host.** Once they say it is done, read the
running name back, `hostname` in an SSH call of its own, which
Windows answers too, and on a WSL instance `hostname.exe` through
interop (`rules/platform/wsl.md` → Windows programs); then carry
out Memory and Verify's last two bullets.

- **Windows,** which Hostwarden only reports on
  (`rules/os/windows.md`), and a **WSL instance**, whose memory
  is named after its Windows machine (`rules/machine-memory.md`),
  so that its rename is that machine's.
- **A Proxmox VE node in a cluster:**
  `rules/appliance/proxmox-ve.md` → Replace: Networking.
- **Every other appliance** (an `Appliance:` line). Its name
  lives in its own configuration, which its web interface or
  API writes. Give the user the menu path from the vendor's
  documentation, cited, or, where its appliance file names a
  command, that command for the user to run, as
  `rules/appliance/xcp-ng.md` → Replace: Networking does.
- **A host joined to a directory:** Active Directory, FreeIPA or
  another Kerberos realm, as its `Accounts:` line names it
  (`rules/accounts.md`), or a Kerberos keytab the inventory
  finds. Where memory has no `Accounts:` line, the probe of
  `rules/accounts-probe.md` runs first. The machine account and
  keytab are named after the host, and the directory side is
  renamed first.

**The user settles what the name is tied to.** Once they say it
is handled, the rename goes on as below.

- **cloud-init user-data that carries the name:** the user-data
  the inventory reads sets `hostname:`, `fqdn:`,
  `manage_etc_hosts: true` or `preserve_hostname: false`. It wins
  over any file in the guest, so cloud-init puts the old name
  back at every boot. It lives with the cloud provider or on the
  hypervisor.
- **A member of anything keyed by the node name:** Kubernetes,
  Docker Swarm, RabbitMQ (`rabbit@<host>`), Galera, Patroni,
  Consul, Nomad, Pacemaker and Corosync, Ceph. List each
  membership the inventory found.

A standalone Proxmox VE node is renamed as
`rules/appliance/proxmox-ve.md` → Replace: Networking says. Its
steps take the place of Apply below; the rest of this file
applies.

## Inventory

Read-only, and shown to the user as a list: paths and counts,
never the lines of a file (`rules/secrets.md`).

**On the host,** as root or through `sudo -n`, in one call
(`rules/ssh-connections.md` → Bundle commands), with the old full
name and the old short name:

```
o='web1.example.com' s='web1'
echo @names; hostname; cat /etc/hostname 2>/dev/null
command -v sysrc >/dev/null && sysrc -n hostname
command -v scutil >/dev/null &&
  for n in HostName LocalHostName ComputerName; do
    scutil --get "$n"
  done
d=/etc/
for r in /usr/local/etc /opt/homebrew/etc; do [ -d "$r" ] && d="$d $r/"; done
echo @files
grep -rIcwF -e "$o" -e "$s" $d 2>/dev/null | grep -v ':0$'
echo @certs
find $d \( -name '*.pem' -o -name '*.crt' -o -name '*.cer' \) \
    ! -name '*key*' ! -path '*/archive/*' \
    ! \( -type l -path '*/ssl/certs/*' \) \
    ! -path '*/ca-trust/*' ! -path '*/ca-certificates/*' 2>/dev/null |
  while read -r f; do
    openssl x509 -noout -text -in "$f" 2>/dev/null |
      grep -qwF -e "$o" -e "$s" && echo "$f"
  done
echo @cloud-init
command -v cloud-init
test -f /etc/cloud/cloud-init.disabled && echo disabled
k='preserve_hostname|manage_etc_hosts|hostname|fqdn'
grep -sHE "^[[:space:]]*($k):" \
  /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/*.cfg \
  /var/lib/cloud/instance/user-data.txt
echo @members
for p in /etc/krb5.keytab /var/lib/kubelet \
    /var/lib/rabbitmq /var/db/rabbitmq; do
  [ -e "$p" ] && echo "$p"
done
for r in $d; do
  for p in kubernetes rancher rabbitmq patroni patroni.yml consul.d nomad.d \
      corosync/corosync.conf ceph/ceph.conf; do
    [ -e "$r$p" ] && echo "$r$p"
  done
done
docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null
grep -rlsE '^[[:space:]]*wsrep_cluster_address' $d
```

`/etc/` with its slash reaches the files on macOS too, where
`/etc` is a link. `/usr/local/etc` holds the configuration of
FreeBSD's ports and of Homebrew on an Intel Mac, `/opt/homebrew/etc`
that of Homebrew on Apple silicon. What the sections show:

- **@names** — the running name and the one kept for the next
  boot, where the family file's `Hostname:` entry puts it:
  `/etc/hostname`, FreeBSD's `rc.conf`, or on macOS the three
  names of `rules/os/macos.md` → Networking. Whether the kept one
  is the full or the short name decides the form the new one
  takes.
- **@files** — every file under `/etc` that names it, with a
  count. The usual ones are `/etc/hostname`, `/etc/hosts`,
  `/etc/mailname`, the mail server's settings (Postfix's
  `main.cf`), Samba's `netbios name`, a monitoring agent's
  `Hostname=`, a web server's `server_name`, and a DHCP client
  configured to send a fixed name. A hit in sshd's configuration
  or its keys, where a public host key's comment carries the name
  it was made on, is listed and never changed (`AGENTS.md` →
  Critical Safety Rules).
- **@certs** — TLS certificates that carry the name in their
  subject or a SAN. Hostwarden changes none of them: whoever
  issues them, an ACME client or the user, issues one for the new
  name.
- **@cloud-init** — whether cloud-init is installed and active,
  and each setting that decides the hostname, per file. A setting
  in `user-data.txt` is a hand-over (above). In the other files,
  `preserve_hostname: true` is missing unless a line says so,
  and cloud-init then sets the name its data source gives at
  every boot.
- **@members** — the hand-overs above, the keytab among them. A
  path that exists is a lead, not proof: name it, and the user
  says whether it is a membership.

**On its hypervisor,** for a guest whose `Runs on:` names a host
Hostwarden reaches: the lines of its configuration that Guests on
a Hypervisor below needs, never the whole of it, which can hold
cloud-init user-data and credentials (`rules/secrets.md`). In one
call:

```
pct config 105 | grep -E '^hostname:'
qm config 101 | grep -E '^name:|cloudinit|^cicustom:'
```

An Incus or LXD instance, a libvirt VM and a jail need nothing
read: the name on the hypervisor is the one in `guests.md`, and a
jail's hostname is read inside it.

**In memory,** on the workstation, where `<checkout>` is this
checkout's absolute path:

```
grep -rlwF --exclude=changelog.log --exclude-dir=.git \
  -e 'web1.example.com' -e 'web1' "<checkout>/memory"
```

Memory names a host in these places, which Memory below
rewrites: other hosts' `Runs on:` lines, the `→` links in every
`guests.md` and in a cluster's `Members:`, a jail's
`Guest identity:`, `Applies to: hosts` in a decision, a plan's
`Hosts:` and each host's `Plan:` line, `memory/network.md`,
`memory/ssh_hosts`, `memory/user.md`, `Reached as:` and
`memory/known_hosts`. Every other hit is listed for the user. The
`notes/` of a host and every changelog are evidence of the past
and keep the old name.

**Outside.** List these too, but the DNS records among them are not
always the user's: the A, AAAA and PTR records, and the CNAMEs that
target the old name (`rules/dns.md` → The record convention), are
written by Hostwarden, as `rules/dns.md` → Writing says, wherever
the name space's `memory/dns.md` line reads `Hostwarden: write`, and
are the user's own to change everywhere else. Only the user ever
changes the rest:

- the DHCP reservation;
- the guest's name on its hypervisor, where Guests on a Hypervisor
  below leaves it;
- backup jobs and monitoring that name the host;
- the user's own `~/.ssh/config`, and other machines' `/etc/hosts`.

## The Order

Agree it with the user in the question:

1. The new DNS name is added, so that both names resolve to the
   host: the record set `rules/dns.md` → The proposal gives for it,
   written or handed to the user as Outside decides. Hostwarden
   checks the result as The New Name does either way. Where no DNS
   carries the host's names and `memory/ssh_hosts` reaches it by
   address, this step is the new name on its `Host` line instead,
   which Memory writes. That block's address was already accepted
   once, under whatever name first carried it
   (`rules/ssh-config.md` → A Self-Resolved Address); renaming
   only extends the `Host` line and does not revisit it.
2. Hostwarden renames the host and changes the references the user
   agreed to, then memory.
3. Last, the old DNS name is removed and the PTR record moved, from
   the second record set `rules/dns.md` → The proposal gives for a
   rename, again as Outside decides, and the user changes the DHCP
   reservation, which stays theirs in every case. Then Hostwarden
   removes the old name (When the Old Name Is Gone).

## The Question

One question (`rules/service-reload.md` → Prompt Shape When
Asking), after the inventory: the old and the new name; the order;
either record set Hostwarden would write, named as a name space
with `Hostwarden: write`, so the user agrees to it here rather than
at a second prompt; what Hostwarden changes on the host and on its
hypervisor, with each command; the references it would change, one
per line; what stays and why, sshd and the certificates among it;
the user's steps outside, the DNS record sets it does not write and
the DHCP reservation among them. The options: rename as listed,
rename but leave references the user names, or stop.

## Apply

Only what the user agreed to, in this order. Steps 1 to 3 cut no
connection, so they run in one call as root or through `sudo -n`,
their backups first and Verify's reads on the host last.

1. **cloud-init,** where it is installed and not disabled, and
   the files other than `user-data.txt` do not set
   `preserve_hostname: true`: write
   `/etc/cloud/cloud.cfg.d/99-hostwarden-hostname.cfg`, a file of
   Hostwarden's own (`rules/deployed-files.md`), holding
   `preserve_hostname: true`, and `manage_etc_hosts: false` too
   where one of those files sets it to `true`. It comes before the
   name, so that no boot in between puts the old one back.
2. **The name,** with the `Hostname:` entry of the host's family
   file (`rules/os/<family>.md` → Networking), in the form the
   kept name had (@names).
3. **`/etc/hosts`:** every name field that is the old full or
   short name takes the new one, a line's comment and every other
   line left as they are. A host whose `/etc/hosts` names it
   nowhere gets no line.

   ```
   f=/etc/hosts
   awk -v o=web1.example.com -v s=web1 -v n=web2.example.com -v m=web2 '
     /^[[:space:]]*#/ { print; next }
     { for (i = 2; i <= NF && $i !~ /^#/; i++)
         if ($i == o) $i = n; else if ($i == s) $i = m
       print }' "$f" > "$f.new" && cat "$f.new" > "$f" && rm -f "$f.new"
   ```

   `cat` into the file keeps its owner and mode.
4. **The hypervisor,** for a guest (Guests on a Hypervisor below),
   in one call on its host.
5. **Each reference the user agreed to,** in one call: the old
   names replaced as whole strings. A name other machines use to
   reach this one — a mail server's `mydestination`, a web
   server's `server_name` — takes the new name beside the old,
   until The Order, step 3. A service that reads its file only at
   start is reloaded or restarted as `rules/service-reload.md`
   says, in a call of its own.

Never changed: sshd's configuration and keys, a TLS certificate,
and a file a configuration management tool owns
(`rules/config-management.md`).

## Guests on a Hypervisor

The name a guest carries on its hypervisor is separate from its
hostname, and only the first case below changes it with the
rename. The copy or snapshot `rules/system-containers.md` →
Changes asks for comes first.

- **Proxmox VE container:** `pct set <vmid> --hostname <new name>`,
  since Proxmox writes the guest's `/etc/hostname` and part of its
  `/etc/hosts` from it at every start
  (`rules/appliance/proxmox-ve.md` → Guests).
- **Never renamed by Hostwarden, not even on the user's word:** an
  Incus or LXD instance, and a Proxmox VE VM whose cloud-init
  user-data Proxmox generates from its name. The new name gives
  the guest a new instance ID (`rules/system-containers.md` →
  Changes), so at its next boot cloud-init regenerates its SSH
  host keys and the next connection meets a changed host key
  (`rules/host-keys.md` → A Changed Key); an Incus or LXD
  instance is renamed only stopped as well. Where the user wants
  the name changed there anyway, say this, and it is theirs. The
  hostname inside is renamed as usual.
- **Any other VM:** its name there is a label. Change it only on
  the user's word, with the manager's own command checked against
  its `--help` (`qm set <vmid> --name <new name>` on Proxmox VE).
  A manager that renames only a stopped guest, as libvirt's
  `virsh domrename` does, makes it a stop, asked as a reboot.
- **FreeBSD jail:** its host sets its hostname
  (`rules/os/freebsd.md` → Networking); inside, only `/etc/hosts`
  and the references change.

Where the name on the hypervisor stays, its `guests.md` entry
keeps it and links `→` the new memory directory.

## Memory

In one commit, once the host is renamed:

- **The directory moves:**
  `git -C memory mv machines/<old> machines/<new>`, and the title
  line of each file in it that names the host (`memory.md`,
  `deployed.md`, `guests.md`, `storage.md`) takes the new name.
  In `deployed.md`, every entry whose master line names
  `machines/<old>` names `machines/<new>`
  (`rules/deployed-files.md`). A master's marker still names the
  old path; it is left as it is, since changing it would make the
  master differ from what was deployed, and the file's next change
  corrects it. The local machine's
  directory, which the workspace does not commit, moves with `mv`.
  Every alias its `- DNS alias:` lines name is a link to the old
  directory: point each at the new one,
  `ln -sfn <new> memory/machines/<alias>`, so that none depends on
  the old name's link.
- **The old name stays an alias** as `rules/dns-aliases.md`
  says for a renamed host. Leave an item in the host's `todo.md`
  (`rules/machine-memory.md` → Session to-do list) that names the
  references Apply step 5 kept the old name in:

  ```markdown
  - [ ] When web1.example.com is gone from DNS: host-rename.md →
    When the Old Name Is Gone (/etc/postfix/main.cf)
  ```
- **References:** in each place the inventory's memory list
  names, the new name takes the old one's place, and nothing else
  in the line changes. A `Host` line in `memory/ssh_hosts` keeps
  the old name beside the new one while the alias lives, and the
  changed file is checked with `bin/hostwarden-ssh-config`. In
  `memory/user.md`, the new name gets the old name's SSH user.
- **`memory/known_hosts`:** the host key does not change, and the
  new name gets its lines as `rules/host-keys.md` → DNS Aliases
  says for a renamed host.

Commit the moved directory, the old name's link and every other
changed file together, both paths named (`rules/changelog.md` →
The Workspace):

```
bin/hostwarden-sync commit "renamed web1.example.com to web2.example.com" \
  memory/machines/web1.example.com memory/machines/web2.example.com \
  memory/known_hosts
```

## When the Old Name Is Gone

Once the user says the old name is gone from DNS, or a connection
by it finds no address:

- the alias goes, as `rules/dns-aliases.md` → Removing an Alias
  says, with its `known_hosts` lines, once no other link in
  `memory/machines/` points at it (Memory repointed them);
- a `Host` line in `memory/ssh_hosts` drops the old name, and the
  file is checked with `bin/hostwarden-ssh-config`;
- each reference on the host that Apply step 5 gave the new name
  beside the old, as the `todo.md` item lists them, loses the old
  one. That is a change on the host like Apply's: asked, backed up,
  and reloaded as `rules/service-reload.md` says.

Then the item is ticked, and the changelog gets an entry.

## Verify

- **On the host:** the probe's @names section and `/etc/hosts`
  by the new name, read at the end of Apply's call. On a Proxmox
  VE container, also `pct config <vmid> | grep -E '^hostname:'` at
  the end of the call on its host.
- **A new connection by the new name,** with the fresh-login
  options (`rules/ssh-connections.md`), runs the pipeline: memory
  and the key are found under it.
- **`- FQDN:`** is read again by its probe, as
  `rules/dns-aliases.md` → The FQDN says for a renamed host. It
  must give the new full name; where it gives anything else,
  report it and what `/etc/hosts` and the resolver say.

Report the result in one line. Where a check fails, say which and
offer the way back from the backups.

**The next boot is the proof** for cloud-init and the hypervisor,
and Apply reboots nothing. Leave an item in `todo.md`:

```markdown
- [ ] After the next boot of web2.example.com: hostname and /etc/hosts name web2
```

The connection that finds a boot newer than the rename reads both,
ticks the item where they hold, and reports it where they do not.
