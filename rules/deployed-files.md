# Deployed Files

A file a session writes onto a host as a whole — a script, a
systemd unit or timer, a cron file, a config drop-in, a rendered
template, an asset a service serves — has its master copy in the
workspace, not only on the host. A host gets restored, reinstalled
or edited by a colleague; the master says what was meant to be
there, and the record of what was deployed says whether it still
is.

This file covers where the master lives, writing such a file,
changing or removing it, what to do when host and master disagree,
and running a workstation tool against a host.

## What gets a master

A file gets a master when a session creates it, or replaces it
whole with content of its own, whichever command writes it. These
do not:

- A file the host already had and a session edits in place —
  `nginx.conf`, a sysctl value, a line in `/etc/fstab`. The host
  is its master, and `rules/backups.md` is its safety net.
- What a package installs, and what a service rewrites at
  runtime: state, caches, a config the application saves from its
  own UI.
- Anything on a host or in an area a configuration management
  tool owns (`rules/config-management-changes.md`). Its repository
  is the master, and a second copy here would be a second truth;
  the host's memory names the file in that repository instead.
- The SSH server's configuration and keys, which no session writes
  (`AGENTS.md` → Critical Safety Rules). A guest's first-boot
  configuration belongs to its creation (`hostwarden-new-guest`).

## Where the master lives

**`memory/servers/<host>/files/`** mirrors the host's paths, so a
master's place follows from where it goes:
`/usr/local/bin/backup-usb-watch` has its master at
`files/usr/local/bin/backup-usb-watch`. It holds exactly the bytes
the host should have.

**`memory/servers/<host>/src/<name>/`** holds what is not such a
copy: a generator and its inputs, an upstream file and the patches
against it, a payload sent to an API. A `README.md` there says what
it produces, the command that renders it into `files/`, or where it
is sent.

**`memory/fleet/<name>/`** is one artifact deployed to several
hosts that form no cluster — a forced-command wrapper on every
host, a `needrestart` drop-in on every hypervisor — with `files/`,
`src/` if it needs one, and a `README.md` saying what it is and how
it is deployed. A host that needs a variant has it under its own
`files/` at the same path, which wins, and the `README.md` names
that host and why. Which hosts carry the artifact is in their
`deployed.md`, never in a list beside it:
`grep -l fleet/<name> memory/servers/*/deployed.md`.

**`memory/clusters/<name>/files/`** does the same for the members
of a cluster. A file in the cluster's shared file system —
`/etc/pve/` on Proxmox VE — exists once for all members, so it is
recorded in the cluster's own `deployed.md` and checked through any
one member.

**`deployed.md`**, beside the host's `memory.md`, has one entry per
deployed file:

```markdown
# Deployed files on web1.example.com

- /usr/local/bin/backup-usb-watch
  servers/web1.example.com, 755 root:root, 2026-09-14
  sha256 98ea6e4f216f2fb4b69fff9b3a44842c38686ca685f3f55dc48c5d3fb1107be4
- /etc/needrestart/conf.d/50-no-guest-restart.conf
  fleet/needrestart, 644 root:root, 2026-09-14
  sha256 2d7f3c0b8e4d5a61f9c1b0e7a3d6c85f4e2b1a09d8c7f6e5a4b3c2d1e0f9a8b7
- /etc/app/app.conf
  servers/web1.example.com, 600 root:root, 2026-09-20,
  secret-inline
  sha256 5e1f0a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7
```

The second line names the directory whose `files/` holds the
master, then mode and owner as the probe under Drift prints them,
and the date of the deploy. The hash is the master's as it was
deployed. It is what tells a file edited on the host from a master
that changed and was never deployed; a hash taken from the master
today could tell neither.

## Naming on the host

Name a new file for what it does — `backup-usb-watch`,
`reboot-check`, `50-no-guest-restart.conf` — never after the tool
that wrote it. A prefix of the site's own goes in front only when
the user asks for one; record it as an override of this section
(`rules/overrides.md`), so that every later file gets it too.

A script that logs uses its own name as its tag
(`logger -t backup-usb-watch`), never `hostwarden` or `heinzel`,
and never opens a message with a session's
`[<operator> as <unix-user>] ` prefix. Those two tags and that
prefix are the record of sessions, and a script that uses them
passes for a session wherever the activity check cannot tell it
apart (`rules/activity-check.md` → Sessions and watchers). A
deployed script that
still logs under either tag gets its own the next time its master
changes, or earlier as a change of its own when the user agrees;
the tag is part of the master like every other byte.

A file that already carries a Heinzel name keeps it: a timer, a
cron line or another host calls it by that name. It is renamed only
under `rules/file-naming-changes.md`, every caller found first.

## The marker

In a format that has comments, the file's first comment points at
its master, in that format's comment syntax and below any line the
format needs first (a shebang, `<?xml …?>`, `<?php`):

```
# Master copy: Hostwarden workspace,
# servers/web1.example.com/files/usr/local/bin/backup-usb-watch.
# Edits here are kept and reported, not overwritten.
```

The path is relative to the workspace and names the master itself:
`servers/<host>/files/…`, `fleet/<name>/files/…` or
`clusters/<name>/files/…`.

The wording is deliberate. It tells a colleague on the host where
the master is and that an edit is theirs to make — the opposite of
a configuration management header, which says the next run will
overwrite it. It never says "managed by" or "generated by": the
marker search in `rules/config-management-leads.md` looks for
those, and a file of Hostwarden's must not read as a tool's. It
carries no date and no hash, which would have to change with every
edit.

JSON, images and most other formats without comments carry no
marker; the record in `deployed.md` alone knows them.

## Secrets

A master never holds a secret, so a deployed file does not either.
The file reads the secret at runtime from a root-only file of its
own on the host, the way `rules/secrets.md` → Never Pass Secrets on
the Command Line prefers — `EnvironmentFile=`, `LoadCredential=`, a
`*_FILE` variable, a `--password-file` option — and the host's
memory names that file, never its content.

Where the format leaves no way to read a secret from elsewhere, the
master holds a placeholder, `@@SECRET:<name>@@`, and the value is
filled in on the host, from the root-only file there. It never
travels from the workstation, and never through `argv`: the master
arrives on stdin, as in Deploying step 3, and the secret file is
read by the program that fills it in.

```sh
t=$(mktemp) && [ -s /etc/app/db.secret ] &&
awk -v p='@@SECRET:db@@' 'NR == FNR { if (FNR == 1) s = $0; next }
  { o = ""
    while ((i = index($0, p)) > 0) {
      o = o substr($0, 1, i - 1) s; $0 = substr($0, i + length(p))
    }
    print o $0 }' /etc/app/db.secret - > "$t" &&
install -m 600 -o root -g root "$t" /etc/app/app.conf
rc=$?; rm -f "$t"; [ "$rc" -eq 0 ]
```

`index` and `substr` rather than `gsub`, which reads `&` and `\` in
the secret as part of the replacement. The secret is the first line
of its file; a multi-line one needs a file of its own. Such a
deployed file is marked `secret-inline` in `deployed.md`: its hash
on the host differs from the master's by design.

## Deploying

A deploy is a change like any other: asked for, registered
(`rules/parallel-sessions.md`), logged.

1. **Write the master first**, under `files/` at the path it will
   have on the host. A file rendered from `src/` is rendered
   there, and the output is the master.
2. **Check what the host has at that path.** With a `deployed.md`
   line for it, run the Drift probe below for that path. Any
   finding but "as deployed" or "master changed, not deployed"
   stops the deploy and goes to Drift: the difference is
   somebody's edit, and a deploy would destroy it. A file there
   that `deployed.md` does not know is the host's own, and
   replacing it is an edit of an existing file
   (`rules/backups.md`) that the user approves as such.
3. **Write it**, as root or through `sudo -n sh -c` where the
   path needs it. This is the one call that is no `sh -s` bundle:
   a bundle's stdin carries its script, so a master read from
   there would take the rest of the script instead. The script
   below is the SSH call's remote command, and the master alone
   is redirected into its stdin:

   ```sh
   t=$(mktemp) && cat > "$t" &&
   install -m 755 -o root -g root "$t" /usr/local/bin/backup-usb-watch
   rc=$?; rm -f "$t"; [ "$rc" -eq 0 ]
   ```

   `install` replaces the file instead of writing into it, so a
   script that runs at that moment keeps reading the old one; BSD
   `install` takes no `/dev/stdin`, hence the temporary file. The
   group of root is `wheel` on FreeBSD and macOS.
4. **Verify** with the probe (Drift, below), against the master
   just written and not against `deployed.md`, which still holds
   the previous hash or none: the host's hash must equal the
   master's, and mode and owner the ones step 3 set. A
   `secret-inline` file is checked for existence, mode and owner
   only. Anything else stops here, before the record changes.
5. **Record it.** The entry in `deployed.md` with the new master's
   hash, mode, owner and date, a `Source:` in the
   changelog entry (`rules/changelog.md`), and in `memory.md` what
   the file does and when it runs, as for anything else on the
   host; the hashes stay out of `memory.md`.
6. **Activate it** — `systemctl daemon-reload`, enabling a timer —
   under `rules/service-reload.md`.

Several files for one host ride together: one probe for step 2
covers every path. For the writes, one `scp` copies the masters into
a directory `mktemp -d` made on the host, and one bundle
(`rules/ssh-connections.md` → Bundle commands) installs each from
there with the `install` line above, runs the check of step 4, and
removes the directory. A fleet
artifact is deployed host by host, each run through the pipeline as
its own change; the user may approve the list of hosts at once after
seeing it.

## Removing

Deactivate first (stopping a unit is a service change: ask), then
remove the file from the host, its line from `deployed.md`, and its
master — unless it is a fleet or cluster master other hosts still
list. The changelog entry names the master's last hash, which finds
it in the workspace history for a way back.

## Drift

The probe runs on the host as one `sh -s` bundle
(`rules/ssh-connections.md` → Bundle commands), under `sudo -n`
or its stand-in (`rules/privilege-escalation.md`) where a path is
root-only, with one path per line between `<<'PATHS'` and
`PATHS`, so that a space or a `*` in a path stays part of it:

```sh
while IFS= read -r p; do
  if [ ! -e "$p" ]; then
    d=${p%/*}; [ -x "${d:-/}" ] && echo "missing $p" || echo "unread $p"
    continue
  fi
  if [ ! -r "$p" ]; then echo "unread $p"; continue; fi
  h=$( { sha256sum "$p" || sha256 -r "$p" || shasum -a 256 "$p"; } \
    2>/dev/null | cut -d' ' -f1)
  m=$(stat -c '%a %U:%G' "$p" 2>/dev/null \
    || stat -f '%Lp %Su:%Sg' "$p")
  echo "${h:-nohash} $m $p"
done <<'PATHS'
/usr/local/bin/backup-usb-watch
/etc/systemd/system/backup-usb-watch.service
PATHS
```

The masters are hashed on the workstation with the same tools. Each
file is then one of these, comparing the host, the recorded hash
and the master:

| Host     | Master   | Finding                              |
|----------|----------|--------------------------------------|
| recorded | recorded | as deployed                          |
| differs  | recorded | edited on the host                   |
| recorded | differs  | master changed, not deployed         |
| differs  | differs  | both changed                         |
| missing  | —        | removed on the host                  |
| unread   | —        | not checked — never drift            |

A master missing from the workspace counts as a changed master. A
mode or owner other than the recorded one is drift of its own. A
`secret-inline` file compares only its master's hash against the
record; on the host it is checked for existence, mode and owner.
An entry whose hash reads `unverified` is a master rebuilt from
Heinzel's copy that its host has not confirmed yet: it is no
drift, only not checked, and `rules/heinzel-adoption.md` →
Heinzel's copies settles it.

Nothing is overwritten in either direction without the user's
answer. For each finding, show what differs and ask:

- **Edited on the host.** Show the diff, and who and when if the
  activity check has it. Reading the host's copy follows
  `rules/secrets.md`: an edit may have put a credential in, so a
  line that looks like one is reported as changed, never printed.
  Recommend taking the host's version into the master — it is
  usually a fix somebody needed — except for such a line, which
  moves into a secret file on the host first (Secrets, above).
  Deploying the master over it
  instead first backs up the host's copy (`rules/backups.md`),
  which exists nowhere else.
- **Master changed, not deployed.** Deploy it now, as above, or
  restore the recorded version from the workspace history.
- **Both changed.** Show both against the recorded version, which
  the workspace history finds by its hash, and merge by hand into
  the master before any deploy.
- **Removed on the host.** Deploy it again, or record the removal
  as described under Removing.

The resolution updates `deployed.md` and is logged like any
change. A finding the user leaves standing is reported again next
time; a deliberate difference belongs in the master, not in a note
that excuses it.

## Workstation tools

`memory/tools/<name>` is a script, or a directory of them, that the
operator runs on the workstation against hosts: a certificate
rollout, a key distribution, a wrapper around an appliance's API.
It is never deployed. It opens with a comment saying what it does,
which hosts it reaches and how it is run, and it reads its secrets
from `~/hostwarden-keys/` (`rules/secrets.md` → API Credentials on
the Workstation) and holds none.

Running one against a host is running its commands there. Read it
first, run it only against hosts that passed the pipeline
(`rules/first-connection.md`) in this session, and ask about and log
what it changes as a change of the session's own.

## What this is not

Hostwarden keeps masters and reports differences. It does not
converge hosts to them, enforce them on a schedule, template per
host, or push to a fleet in one command. Where that is what the
user needs, a configuration management tool is the answer — never
suggested unasked (`rules/config-management.md` → Never push for
one).
