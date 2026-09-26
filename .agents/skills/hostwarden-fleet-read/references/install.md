# Setting up fleet read on a host

Part of the `hostwarden-fleet-read` skill. Setting up is a change on
the host: the pipeline runs first (`rules/first-connection.md`), a
host in `memory/readonly.md` gets none of it, and a session without
root ends in the sysadmin report (`rules/privilege-escalation.md`)
with these steps in it.

The workspace needs `memory/fleet/fleet-read/` with the wrapper, a
signers file and a signed bundle for this host's kind
(`references/bundle.md`) before a host is worth setting up: without
them the check run at the end has nothing to prove.

## 1. Can this host take it?

One read, as root or through `sudo -n`:

```sh
ssh -V 2>&1
sshd -T 2>/dev/null | grep -iE '^(permitrootlogin|authorizedkeysfile) '
command -v logger mktemp
```

- **OpenSSH before 8.1** has no `ssh-keygen -Y` and cannot check a
  signature. The host gets no fleet read; say so, and leave it to
  the operations host's report.
- **`permitrootlogin no`** refuses the key line however it is
  written. `forced-commands-only` is the value made for this, and
  `prohibit-password` works too. Changing it is an edit of sshd's
  configuration, which Hostwarden never makes: report it, and the
  operator decides.
- **`authorizedkeysfile`** says where root's keys are read from; the
  line in step 4 goes there. An appliance whose web interface owns
  the keys — its file in `rules/appliance/` says so — takes the
  line there if it accepts key options at all. If it does not, the
  host gets no fleet read.
- **No `logger`** leaves the wrapper's log request failing; the
  checks still run. Say so.

## 2. Deploy the wrapper and the signers file

Both follow `rules/deployed-files.md` → Deploying, as one fleet
artifact, registered first (`rules/parallel-sessions.md`):

- `/usr/local/sbin/fleet-read`, from `files/usr/local/sbin/fleet-read`,
  mode 755, owned by root;
- `/etc/fleet-read/allowed_signers`, from
  `files/etc/fleet-read/allowed_signers`, mode 644, owned by root.

`/etc/fleet-read/` is created first with `install -d -m 755`. Both
land in the host's `deployed.md` with the source `fleet/fleet-read`.

## 3. The operations host's name and address

The key line carries two facts about the operations host:

- **Its name** — the `Operator:` of its own `memory/user.md`
  (`references/operations-host.md`). The wrapper puts it in front
  of every journal line, so a nightly run is told apart from
  anyone's session. Write the key line only once the remote's
  `memory/operators.md` holds that handle; until then the
  operations host has not reserved it, and it may be a teammate's.
- **Its address as this host sees it** — for `from=`. Read it from
  the operations host's memory, and mind NAT, a VPN or a mesh: the
  address that arrives can be another than the one it has. When in
  doubt, use the address the host's own log shows for the
  operations host's last login.

## 4. The key line — the operator's step

Write the line out with the real values, and ask the operator to
add it to root's authorized keys on the host:

```
from="192.0.2.30",restrict,command="/usr/local/sbin/fleet-read ops1" ssh-ed25519 AAAA… ops1 fleet-read
```

`restrict` turns off forwarding, the terminal and `~/.ssh/rc`;
`command=` makes every login run the wrapper, whatever the client
asked for; `from=` refuses the key anywhere else. The public key
comes from the operations host, where the operator made it — the
session never makes, copies or reads a private key.

Record the host as waiting (SKILL.md → Machine memory) and carry on
with the next host. Once the operator says it is done, confirm it,
reading only:

```sh
grep -c 'command="/usr/local/sbin/fleet-read ' /root/.ssh/authorized_keys
```

`0` means the line is not there, or in another file than
`authorizedkeysfile` names.

## 5. The check run

Prove the chain on the host itself, with the host's signers file
and the bundle this host will get. The wrapper runs as it does for
sshd, with a test name, and prints the sections; nothing is
written:

```sh
cat memory/fleet/fleet-read/src/linux.sh.sig \
  memory/fleet/fleet-read/src/linux.sh \
  | ssh root@web1.example.com \
    'SSH_ORIGINAL_COMMAND=collect /usr/local/sbin/fleet-read check'
```

(with the SSH options from `AGENTS.md` → SSH Options). It passes
when every section of the bundle appears; `signature not valid`
means the signers file on the host and the one the bundle was
signed against differ, `expired` that the bundle needs rebuilding.

The run through the real key, from the operations host, is that
host's to make — its first scheduled run shows it. It connects with
the SSH options of `AGENTS.md` → SSH Options and checks the host's
key against the workspace's `memory/known_hosts`, which this
session's pipeline filled (`rules/host-keys.md`) and the workspace
carries to the operations host: commit and push it before that
run, or the host is not read. A login refused
there, with this check passed, is the `from=` address or the key
line.

Update the `Fleet read:` line with the date and log the change
(SKILL.md → Changelog).
