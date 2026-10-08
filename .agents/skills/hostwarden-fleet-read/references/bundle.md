# Building and signing a fleet-read bundle

Part of the `hostwarden-fleet-read` skill. A bundle is a shell
script of read-only checks that the wrapper runs as root on a host,
once the operator has signed it. It is built in an interactive
session, in the workspace, and it is the operator's to sign.

## Which bundles

One per baseline reference the fleet needs, named after it:
`src/linux.sh` from `baseline-linux.md`, `src/freebsd.sh`,
`src/macos.sh`. A host whose appliance or platform file changes a
check in its `## Housekeeping and Audits` section gets a bundle of
its own, named after that file (`src/proxmox-ve.sh`), built from
the baseline reference with that section applied. The host's
`Fleet read:` line says which bundle it gets.

Windows has no `sh` and no forced command of this kind; its hosts
get no fleet read.

## When to rebuild

Whenever this skill runs, and whenever the user asks, read each
bundle's header and say which of these holds:

- **The references moved on.** `git log --oneline <built-from>..HEAD`
  over the files the bundle was built from lists commits: a
  Hostwarden update changed a check. Show the log, and rebuild when
  the user agrees.
- **Its date is near.** Less than 30 days to `valid-until`.
- **It names no sections.** A bundle without a `SECTIONS=` line
  runs only whole; `collect <section>…` and
  `bin/hostwarden-fleet-run --section` refuse it. Rebuild it in the
  layout below when the user wants a run by section.
- **A host needs one that does not exist** — a new kind of host
  with a `Fleet read:` line.

A bundle is never edited after it was signed. Any change is a new
build and a new signature.

## What goes in

Take the commands from the housekeeping skill's references —
`baseline-<name>.md` and `backup-presence.md` for every host,
`service-checks.md`, `containers.md` and `smart.md` for what the
fleet's memory files name — word for word, section by section. The
wrapper runs the bundle as root, so a reference's privilege prefix
becomes empty: `SUDO=""` at the top, and `$SUDO` stays where the
reference has it. The same checks as the interactive skill, the
same commands, so the report reads the same.

The bundle is only ever read-only:

- **Nothing that writes.** No package-list refresh (`apt-get
  update`, a `dnf` or `zypper` metadata refresh — use the cached
  form or leave the check out), no `logger`, no file written but in a
  directory of its own from `mktemp -d` that it removes, no service
  action, nothing that reaches the
  network beyond this host's own ports. The version lookup of
  `rules/version-check.md` needs a web search and is left out.
- **No secrets.** Cron entries, environment files and
  configuration that can hold a credential are reported by name,
  count and mode, never by content (`rules/secrets.md`).
- **Nothing from stdin.** The wrapper closes it.
- **Bounded output.** Log excerpts end in `tail -n`, lists in
  `head -n`, as the references have them.

A check that cannot be written this way stays out, and the header
names it. Where a check differs from its reference, a
`# differs:` comment above it says how and why.

## Layout

```sh
#!/bin/sh
# fleet-read bundle: linux
# valid-until: 2027-03-31
# built-from: 3f9c2e1 (Hostwarden 2.22.0)
# sources: baseline-linux.md backup-presence.md service-checks.md
# left out: version-check (needs a web search)

export LC_ALL=C
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
SUDO=""
# The sections, by key, in the order they run. The wrapper reads
# this line; the dispatcher at the end runs from it.
SECTIONS='meta disk'
sec() { printf '\n### %s\n' "$1"; }

sec_meta() {
  sec 'meta'
  hostname; date -u +%Y-%m-%dT%H:%M:%SZ; uname -r
  cat /etc/os-release
}

sec_disk() {
  sec 'baseline-linux.md: Disk Usage'
  df -h -x tmpfs -x devtmpfs -x overlay -x squashfs
}

sec_floors() {
  sec 'floors'
  df -P -x tmpfs -x devtmpfs -x overlay -x squashfs | awk 'NR > 1 {
    p = $5; sub(/%/, "", p); p += 0
    if (p > 95) print "CRITICAL disk-full", $6, "at", p "%"
    else if (p > 85) print "WARN disk-high", $6, "at", p "%" }'
}

# The chosen sections in SECTIONS' order, all of them when none was
# named, then the floors.
WANT=${*:-$SECTIONS}
for s in $SECTIONS; do
  case " $WANT " in *" $s "*) "sec_$s" ;; esac
done
sec_floors
exit 0
```

- `valid-until` is at most a year ahead; the operator may choose
  less. It bounds how long a signed bundle can be replayed.
- `built-from` is `git rev-parse --short HEAD` of this checkout and
  its `VERSION`, which is what the rebuild check compares.
- `SECTIONS='…'` lists every section but the floors, by its key: a
  word of lowercase letters, digits and underscores that starts
  with a letter, such as `disk`, `cert`, `backup_presence` — never
  a hyphen, since the key is part of a function name and `dash`
  refuses `sec_backup-presence`. The line is exactly that shape,
  single quotes and all, at the start of a line: it is the one
  list. The wrapper checks a `collect <section>…` request against
  it, `bin/hostwarden-fleet-run --section` as well, and the
  dispatcher runs from the same variable, so a key on the line is a
  key that runs. A bundle without the line runs only whole.
- Each section is a function `sec_<key>`. It opens with `sec`,
  naming the reference and its heading exactly, so whoever reads
  the output can find the thresholds that apply. The dispatcher at
  the end runs the chosen sections in the line's order, the floors
  after them, and ends with `exit 0`, so a run by section is whole
  in the same way as a full one: the wrapper never picks lines out
  of the bundle, the signed bundle itself decides what each name
  runs.
- `sec_floors` runs its own commands and reads nothing a section
  function set — no variable, no file — because in a run by section
  the other functions did not run. A floor computed from a
  section's leftovers prints nothing when that section was not
  named, and a CRITICAL goes missing.

The last section is `floors`: one line per finding that no verdict
may lower, as `<SEVERITY> <code> <text>`. The fleet run adds each
to the host's findings and holds a finding of the same code to at
least that severity, whatever the model says
(`bin/hostwarden-fleet-run`). The bundle rates them itself, with
the thresholds of the references it was built from and the
overrides that change them, so the signature covers the numbers
too. At least:

- `disk-full` and `disk-high`, for file systems over the disk
  check's thresholds;
- `cert-expiry` and `cert-expiry-soon`, for certificates the
  certificate check finds expired or near their end;
- `firewall-inactive`, only where no packet filter of any kind is
  active — none of ufw, firewalld, nftables with a table, iptables
  rules, pf or the appliance's own. Where that is not certain, no
  line: the verdict decides;
- `auto-updates-off`, where the reference's check is a plain one —
  a configuration file missing, a timer disabled;
- any other CRITICAL of the references that a command, not a
  judgement, decides.

The floors section is the last one, and only the last one counts:
the fleet run ignores a `### floors` line that a check earlier in
the output printed, such as a log excerpt. It is also how the fleet
run knows the output is whole: a run counts as read only when the
section arrived and the bundle ended with the `exit 0` that is its
last line. Whatever fails on the way — a lost connection, a check
the wrapper cut short — leaves the host "not read". The floors run
whole in a run by section too, whichever sections were named, so
no choice of sections hides a CRITICAL the bundle can rate itself.

The bundle and its signature together must stay under 256 KiB, the
wrapper's input limit.

## Try it before signing

Run the unsigned bundle once as root on one host of its kind, in
this session, as an ordinary read-only probe
(`rules/ssh-connections.md` → Bundle commands). Every section must
appear, the run should take seconds, not minutes, and the output
must hold no secret. Then once more with one key after `sh -s`, as
`sh -s disk`: only that section and the floors appear, the floors
whole. Fix the bundle, not the output.

## Show it, and hand it over

A new build is written as `src/<name>.next.sh`, beside the signed
pair it is to replace, so the operations host keeps running what
was signed last until the operator signs the new one. Show it — for
a rebuild, as a diff against `src/<name>.sh` — and give the
operator the command. `-f` names their signing key: its private
file, or its public half when an agent holds the private one:

```bash operator
ssh-keygen -Y sign -n fleet-read -f <signing-key> \
  memory/fleet/fleet-read/src/linux.next.sh
```

It writes `linux.next.sh.sig`. A signature covers the content, not
the name, so check it and then move the pair into place:

```sh
cd memory/fleet/fleet-read &&
ssh-keygen -Y verify -I fleet-read -n fleet-read \
  -f files/etc/fleet-read/allowed_signers \
  -s src/linux.next.sh.sig < src/linux.next.sh &&
mv src/linux.next.sh src/linux.sh &&
mv src/linux.next.sh.sig src/linux.sh.sig
```

Commit the bundle and its signature together (`rules/changelog.md` → The
Workspace), with the bundle's name and date in the message.

A `.next.sh` that sits unsigned is named whenever this skill runs.
