# SSH CA

An SSH CA the user already runs is audited and then used
everywhere Hostwarden itself writes SSH trust. Hostwarden never
builds or runs a CA, never signs a certificate, never reads or
moves a CA signing key, and never writes the configuration of an
sshd that runs (`AGENTS.md` → Critical Safety Rules). On a running
server, connecting it to the CA, installing a host certificate,
changing a principals file and revoking stay with the user;
Hostwarden reads, reports, and hands over the lines.

Certificates are an OpenSSH feature and look the same whichever
software issues them: `ssh-keygen -s` with a script around it,
step-ca, HashiCorp Vault or OpenBao, Teleport, BLESS, or another.
This file works from what sshd, ssh and the certificate show.
Which software it is, and where its renewal runs, comes from the
renewal job or from the user, never from a guess.

The probes are `sh`. On a host whose family file does not use the
`sh -s` bundle, Windows among them, they do not run: its SSH CA
lines read `not checked (<family>)`.

## Terms

The same words in every rule, skill and memory line:

- **Host certificate:** the host key, signed. The server presents
  it (`HostCertificate`), and a client that trusts the **host CA**
  through a `@cert-authority` line accepts the host without a line
  of its own. It is renewed on the server by a job.
- **User certificate:** a person's or a tool's key, signed. sshd
  admits it when it trusts the **user CA** (`TrustedUserCAKeys`,
  or a `cert-authority` line in `authorized_keys`). It is renewed
  by its holder, often daily.
- **Principals:** the names a certificate is issued for. A host
  certificate lists the host's names; a user certificate lists the
  accounts or roles it may log in as. A **principals file**
  (`AuthorizedPrincipalsFile`, `%u` for the account) lists the
  principals each account accepts; a **principals command**
  (`AuthorizedPrincipalsCommand`) prints them.
- **Revocation list:** the file `RevokedKeys` names, a key
  revocation list (**KRL**) from `ssh-keygen -k` or a plain list
  of public keys. Once it is named, a missing or unreadable file
  makes sshd refuse every public key login, `authorized_keys`
  included.
- **CA signing key:** the private half of a CA. A secret
  (`rules/secrets.md`): whoever holds it logs in everywhere the CA
  is trusted.
- **Issuing rules:** who gets a certificate from the CA, for which
  principals and for how long (`rules/ssh-ca-issuing.md`).
- **The user's CA:** a CA with a line in `memory/network.md` under
  `## SSH CAs`, which only the user's word puts there (Memory).
  Every expectation below is about the user's CAs; a CA a probe
  merely finds is a finding.

Host and user certificates fail differently, belong to different
people and are renewed differently. Probe, record and report them
separately; a host may have either, both or neither.

## Host Certificate

A certificate counts for what sshd serves, not for what lies on
disk. Two probes find out.

The public one needs no root and no sshd configuration —
certificates, known-hosts files and timers are world-readable. It
runs in the host's first bundled call:

```bash
for c in /etc/ssh/*-cert.pub /usr/local/etc/ssh/*-cert.pub; do
  [ -e "$c" ] || continue
  echo "hostcert: $c"
  ssh-keygen -L -f "$c"
done
for f in /etc/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts2 \
  /usr/local/etc/ssh/ssh_known_hosts /usr/local/etc/ssh/ssh_known_hosts2; do
  [ -e "$f" ] || continue
  grep '^@cert-authority' "$f" | while read -r m p k; do
    echo "clientca: $f $p $(printf '%s\n' "$k" | ssh-keygen -lf - \
      | cut -d' ' -f2)"
  done
done
grep -Hin -e '^[[:space:]]*globalknownhostsfile' \
  -e '^[[:space:]]*host[[:space:]]' -e '^[[:space:]]*match[[:space:]]' \
  /etc/ssh/ssh_config /etc/ssh/ssh_config.d/* \
  /usr/etc/ssh/ssh_config /usr/etc/ssh/ssh_config.d/* \
  /usr/local/etc/ssh/ssh_config 2>/dev/null
systemctl list-timers --all --no-pager 2>/dev/null \
  | grep -iE 'cert|ssh|renew|step|vault|bao' | sed 's/^/renewal: /'
grep -lisE 'ssh.*cert|cert.*ssh|step ssh|/sign|renew' /etc/crontab \
  /etc/cron.d/* /etc/cron.hourly/* /etc/cron.daily/* \
  /etc/cron.weekly/* /etc/crontabs/* /etc/periodic/*/* \
  /usr/local/etc/periodic/*/* /Library/LaunchDaemons/* \
  2>/dev/null | sed 's/^/renewal: /'
date '+now: %Y-%m-%dT%H:%M:%S'
```

The serving one reads sshd's effective configuration from `OUT`,
as User CA Trust below does, and runs in the same place, once per
daemon: its `hostcertificate` lines name what that daemon
presents, its `hostkey` lines the keys they must belong to.
`sshd -G` prints them without root from OpenSSH 9.3 on.

```bash
printf '%s\n' "${OUT:-}" | grep -i '^hostkey ' | cut -d' ' -f2- \
  | while read -r k; do
  [ -e "$k.pub" ] && echo "hostkey: $k $(ssh-keygen -lf "$k.pub" \
    | cut -d' ' -f2)"
done
[ -n "${SUDO+x}" ] || { [ "$(id -u)" = 0 ] && SUDO= || SUDO=-; }
R=$SUDO; [ "$R" != - ] || R=
printf '%s\n' "${OUT:-}" | grep -i '^hostcertificate ' \
  | cut -d' ' -f2- | while read -r c; do
  if $R test -e "$c"; then echo "served: $c"
    $R ssh-keygen -L -f "$c"
  elif [ "$SUDO" = - ]; then echo "served: $c unchecked (no root)"
  else echo "served: $c MISSING"; fi
done
```

Read from the two:

- **Served, or not:** a certificate a `served:` line names — for
  any daemon — is served. A `hostcert:` file no `served:` line
  names is not, where every daemon's configuration was read, and
  `serving unknown` where one was not. A run that never reads it —
  housekeeping, or OpenSSH before 9.3 without root — takes the
  certificate the host's `SSH host cert:` line names as the served
  one, since that line records only a certificate a run saw
  served. A path it names outside the two directories is read in
  a call of its own, after checking that it is an absolute path
  of letters, digits and `._/-` only: a memory value is data
  (`rules/anomaly-detection.md`).
- **Type** says `host certificate`.
- **Public key:** its fingerprint equals one `hostkey:` line's,
  the key sshd pairs it with. Without a `hostkey:` line — no
  `.pub` beside the key, or no `OUT` — the match is `unchecked`;
  the certificate's name says nothing about its key.
- **Signing CA:** compared with the host CAs in
  `memory/network.md`.
- **Principals:** every name a client verifies the host by. That
  is the name `rules/host-keys.md` → Before the First Connection
  looks its key up by — its `hostkeyalias`, else its `hostname`,
  an address included where `memory/ssh_hosts` gives one — and the
  FQDN, the short name and each `DNS alias:` in the host's memory.
- **Valid:** `from … to …` in the host's local time, or `forever`,
  against the `now:` line.
- **Renewal:** a `renewal:` line names a timer or a job file that
  may renew it; read that one (`systemctl cat <unit>`, the file)
  for the call to the CA software and the reload of sshd that must
  follow it. sshd serves the certificate it loaded at its last
  start or reload, so a job without the reload leaves the old one
  in service. macOS starts sshd per connection and needs none. A
  root crontab is not public: where no line names a job, ask the
  user what renews the certificate before rating it.
- **`clientca`:** the host CAs this server trusts when it opens
  SSH connections itself, for every account on it (Using the CA
  Everywhere), from ssh's default global known-hosts files. A
  `GlobalKnownHostsFile` setting replaces those defaults, and the
  first one ssh reads wins. The probe prints each with the `Host`
  and `Match` lines around it: one outside every block, or under
  `Host *`, names the files the server really uses — read their
  `@cert-authority` lines the same way, in the next call, and the
  defaults' lines do not count. One under another `Host` or
  `Match` applies to those targets only. `ssh -G` is not used for
  it: it runs the command of a `Match exec` line.

Findings for a served certificate:

- Expired, not yet valid, or matching none of sshd's host keys →
  **CRITICAL**: clients that know the host only through the CA
  stop connecting.
- `MISSING`, checked with root: sshd names a certificate that is
  not there → **CRITICAL**: it serves the plain key, with the same
  effect. Without root, a file the SSH user cannot see reads
  `unchecked (no root)`, never `MISSING`.
- Less than a third of its lifetime left → **WARN**: the renewal
  is overdue.
- `forever` → **WARN**: it can only be revoked on every client.
- No renewal job, as the user confirms, or one that does not
  reload sshd → **WARN**.
- A name from the list above missing from the principals →
  **INFO**; for the name clients verify by, **WARN**.

A certificate sshd does not serve is **INFO** and nothing more:
no client ever sees it. The certificate the host's
`SSH host cert:` line names being gone, or no longer served, is
**WARN**; the line is not rewritten to `none` until the user says
so.

## User CA Trust

With the privilege prefix (`rules/privilege-escalation.md`), in
the call that reads sshd's effective configuration: the probe of
`.agents/skills/hostwarden-security/references/ssh.md` → sshd's
Effective Configuration, or the fleet audit's, which hold it in
`OUT`, read with the daemon's own binary and `-f`. The security
audit's probe sets `OUT` inside its loop, which runs in a
pipeline, so this probe goes inside that loop, before its `done`;
the fleet audit's sets it once, and this probe follows it. The
key file, the list and the principals files may be readable by
root alone, and the globs run in a root shell, since homes and
`.ssh` directories are closed to the SSH user. The call opens with
the privilege prefix, which sets `$SUDO`; where nothing set it,
the probe's first line treats the run as one without root rather
than read root's files as the SSH user.

```bash
[ -n "${SUDO+x}" ] || { [ "$(id -u)" = 0 ] && SUDO= || SUDO=-; }
if [ -z "${OUT:-}" ]; then
  echo "sshd's configuration unread: user CA unchecked"
else
  printf '%s\n' "$OUT" | grep -i -e '^hostcertificate ' \
    -e '^trustedusercakeys ' -e '^authorizedprincipals' \
    -e '^revokedkeys ' -e '^casignaturealgorithms ' \
    -e '^authorizedkeysfile '
  v() { printf '%s\n' "$OUT" | grep -i "^$1 " | cut -d' ' -f2-; }
  CA=$(v trustedusercakeys); RK=$(v revokedkeys)
  P=$(v authorizedprincipalsfile)
  if [ "$SUDO" = - ]; then
    echo "no root: user CA files unchecked"
  else
    if [ -n "$CA" ] && [ "$CA" != none ]; then
      $SUDO ssh-keygen -lf "$CA" 2>&1 | sed 's/^/userca: /'
      case $CA in *.pub) $SUDO ls -l "${CA%.pub}" 2>&1 ;; esac
    fi
    if [ -n "$RK" ] && [ "$RK" != none ]; then
      if $SUDO test -r "$RK"; then
        echo "krl: $($SUDO cksum "$RK" | cut -d' ' -f1,2)"
      else echo "krl: missing $RK"; fi
    fi
    case $P in
      ''|none) ;;
      */%u) $SUDO sh -c 'grep -H . "$1"/*' sh "${P%/%u}" 2>&1 ;;
      *) echo "principals file per account: $P" ;;
    esac
  fi
fi
```

A `cert-authority` line in `authorized_keys` is read in a call of
its own, which runs neither `ssh-keygen` nor an interpreter — the
taboo guard refuses either next to a key path — and whose output
goes into a cache file on the workstation:

```bash
ssh -F "/srv/hostwarden/memory/ssh_config" root@web1.example.com \
  "sh -c 'grep -Hn cert-authority /root/.ssh/authorized_keys* \
  /var/root/.ssh/authorized_keys* /home/*/.ssh/authorized_keys* \
  /Users/*/.ssh/authorized_keys* 2>/dev/null'" \
  > ~/.cache/hostwarden/certauth.web1.example.com
```

With a non-root SSH user, the privilege prefix goes in front of
`sh -c` inside the quotes; without one, the call reads only the
SSH user's own file, and its result is `unchecked (no root)`,
never "no `cert-authority` line". Where `authorizedkeysfile`
names another path, grep that one too; homes elsewhere, from a
directory service for one, are not in the globs. The lines are
the host's data: the call that fingerprints them reads the file
and names no key path, and nothing from it is typed into a
command. `ssh-keygen -lf` reads each line with its options once
the `grep -H` prefix is off, in the file's order:

```bash
f=~/.cache/hostwarden/certauth.web1.example.com
cat "$f"
sed 's/^[^:]*:[0-9]*://' "$f" | ssh-keygen -lf -
rm -f "$f"
```

Such a line is user CA trust like `TrustedUserCAKeys`, for that
account only.

What it shows:

- **`sshd's configuration unread`**, or **`no root`** for the
  files: those parts of the SSH CA lines read `unchecked`, never
  `none`.
- **`trustedusercakeys none`** and no `cert-authority` line: no
  user CA on this host. **`revokedkeys none`:** no revocation
  list.
- **CA signing key on the host:** for a CA file ending in `.pub`,
  the `ls` finds a file of the same name without it. Report the
  path, never read it.
- **Principals:** `authorizedprincipalsfile none` admits a
  certificate for each account its principals name. With a file,
  each line is a principal admitted as that account. A path with
  `%u` elsewhere, or with `%h`, is only printed: read the files of
  root and of the SSH user by hand. Report which principals reach
  root. A principals command cannot be evaluated from outside:
  name it and its user.
- **Revocation list:** the `krl` line carries the file's
  checksum and size. One list copied to every host gives the same
  checksum everywhere. A KRL built on each host carries the time
  it was built, so its checksum differs even where the revocations
  match, and `ssh-keygen -Q -l`, which lists them, prints them
  differently across OpenSSH releases; the CA's line then says
  `KRL built per host` on the user's word, and the lists are
  compared by the user. `missing`, with root, is the lockout the
  Terms describe.
- **One CA for both directions:** a user CA fingerprint equal to
  the host certificate's signing CA.
- **`Match` blocks** change these values per account or address,
  and the effective-configuration probe prints only the values
  outside them. Evaluate each block as
  `.agents/skills/hostwarden-security/references/ssh.md` → Match
  blocks says, filtered for the keywords above.

Findings:

- `RevokedKeys` set, and the file missing or unreadable →
  **CRITICAL**: sshd refuses every public key login. Tell the user
  at once; the console is the way in
  (`rules/management-controller.md` → The rescue path).
- The CA signing key on the host → **WARN**.
- One CA signs host and user certificates → **WARN**.
- `casignaturealgorithms` contains `ssh-rsa` (SHA-1) → **WARN**.
- Principals that reach root → **INFO**, listed.
- A principals command → **INFO**, with its command and user.
- A user CA and no `RevokedKeys` → **INFO**: a leaked certificate
  stays valid until it expires.
- A `cert-authority` line in `authorized_keys` → **INFO**, with
  the account and the CA fingerprint.
- A CA that is not the user's, or a principal the user did not
  know of → the same as an unknown key in `authorized_keys`
  (`rules/anomaly-detection.md`).
- The issuing rules: `rules/ssh-ca-issuing.md`.

## Failures

- **`Host key verification failed.`** on a name a `@cert-authority`
  line covers: `rules/host-keys.md` → Host Certificates.
- **`Permission denied (publickey)`** with a user certificate, as
  Hostwarden's own login or anyone's. Check the certificates the
  client offers before calling it a server problem: an expired one
  is offered all the same. They sit in the agent, or beside a key
  file as `<identityfile>-cert.pub`, or where `CertificateFile`
  says:

  ```bash
  ssh-add -L | grep -e '-cert-v01@' | ssh-keygen -L -f /dev/stdin
  ssh -F "/srv/hostwarden/memory/ssh_config" -G root@web1.example.com \
    | grep -i -e '^certificatefile ' -e '^identityfile '
  ```

  and `ssh-keygen -L -f` on each certificate file those lines
  name. `/srv/hostwarden` stands for this checkout's absolute path.
  No retry (`rules/ssh-unreachable.md` → Login rejected).

  Where the server's log can be read — through another account,
  the console, or a later session — it names the reason, in the
  place `rules/os/<family>.md` gives:
  - `Certificate invalid: expired` — the holder renews it.
  - `Certificate invalid: name is not a listed principal`:
    `rules/ssh-ca-issuing.md` → When a Login Fails on the
    Principal.
  - `Error checking authentication key … in revoked keys file`:
    the revocation list is missing or unreadable, and plain keys
    fail too — the CRITICAL finding of User CA Trust.
  - A certificate from a CA the host does not trust is refused like
    an unknown key.

## Using the CA Everywhere

The user's CAs are carried into every place Hostwarden writes SSH
trust, each within the scope its line names, and every place it
cannot write reports the gap.

- **The workstation:** every host whose `SSH host cert:` line
  names a host CA of the user's is covered by that CA's
  `@cert-authority` line in `memory/known_hosts`
  (`rules/host-keys.md` → Host Certificates).
- **Servers that connect out:** a server whose memory names a job
  or role that opens SSH to other hosts — a backup or rsync to
  another host, a deploy, a jump host — or that the user names.
  No probe decides it: a root `known_hosts` file only shows that
  someone once connected. One
  `@cert-authority` line in the global known-hosts file serves
  every account on the server; lines in single users' files are
  forgotten for service accounts. The public Host Certificate
  probe prints the file and its lines as `clientca`. Missing: offer the
  line, for the host CA's patterns in the form Host Certificates
  in `rules/host-keys.md` gives, never `*`. It is a trust change:
  ask, back up (`rules/backups.md`), append, and check it on the
  server with no connection,
  `ssh-keygen -F <a host it reaches> -f <the file>`, which must
  print the line. The server never logs in anywhere to test it
  (`rules/borrowed-rights.md`). Record it as
  `SSH client host CA:`. A host in read-only mode gets the finding
  only (`rules/access-control.md` → Read-Only Servers).
- **A new guest** trusts the user CA from its first boot, except
  a container from the Proxmox VE baseline template, which has no
  first-boot file of its own
  (`.agents/skills/hostwarden-new-guest/references/user-data.md`
  → SSH CA); **every server** is measured against the CA:
  `rules/baseline.md` → SSH CA. An OS reinstall lists the CA trust
  and the host certificate among what the new system needs back
  (`hostwarden-os-install`).
- **A new guest's host certificate:** Hostwarden signs none. After
  the guest's first login, give the user the public keys of the
  host keys sshd loads — the `hostkey:` lines of the serving
  probe in Host Certificate, which on a guest this run created are
  the image's `/etc/ssh/ssh_host_*_key.pub` — and the principals
  to sign, as Host Certificate lists them, and record
  `SSH host cert: none, keys handed to sign <date>`. The user
  installs the certificate and its `HostCertificate` line; the next
  run that probes the host finds it.
- **A new guest's revocation list** is the fleet's at the moment
  of creation. Tell the user in the same breath that the guest now
  has to be among the hosts their revocations reach; the fleet
  audit's `krl` row shows where one has not.

## Memory

Per host, in `memory/servers/<hostname>/memory.md`, one line per
direction, only where present. `SSH host cert:` names a
certificate sshd serves, never one that only lies on disk:

```markdown
- SSH host cert: ed25519 /etc/ssh/ssh_host_ed25519_key-cert.pub,
  CA SHA256:Cxr4…, principals web1.example.com web1, valid to
  2026-10-19, renewed by ssh-cert-renew.timer
- SSH user CA: CA SHA256:9fQe… (/etc/ssh/user_ca.pub), principals
  /etc/ssh/auth_principals/%u, KRL /etc/ssh/revoked_keys
- SSH client host CA: /etc/ssh/ssh_known_hosts trusts CA
  SHA256:Cxr4… for *.example.com,[*.example.com]:*
```

What a probe could not see is marked `unchecked`:
`- SSH user CA: unchecked (no root)`.

Fleet-wide, in `memory/network.md`, one line per CA under
`## SSH CAs`. Only the user's word writes one: a CA a probe finds
that no line names is put to the user — is it theirs, and which
hosts should trust it — and gets a line only on a yes, with its
scope, the hosts or the name patterns it covers. A no, or no
answer, leaves it a finding.

```markdown
## SSH CAs
- User CA SHA256:9fQe… — <CA software> on ca.example.com, the
  user's (2026-09-23), scope all servers, certificates 16h,
  principals root ← ops, KRL /etc/ssh/revoked_keys, issuing:
  groups server-admins, root denied
- Host CA SHA256:Cxr4… — same CA, the user's (2026-09-23), scope
  *.example.com, host certificates 30d, known_hosts line: yes
  (user, 2026-09-23)
```

`known_hosts line:` records the user's answer to the offer of
`rules/host-keys.md` → Host Certificates, `no` included, so it is
made once. A CA rotation the user announces is part of the line
until it is done, `rotating to SHA256:… since 2026-09-23`: the
audits accept both CAs meanwhile. `KRL built per host`, also on
the user's word, says each host builds its own revocation list
(User CA Trust).

The onboarding, the security audit and housekeeping write or
refresh a host's lines when they probe it; the fleet audit only
reports. A short fingerprint is enough to recognize a CA.
