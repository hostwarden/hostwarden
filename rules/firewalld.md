# firewalld

The expected firewall on the Red Hat family (`rules/os/rhel.md`)
and on openSUSE and SLES (`rules/os/suse.md`). Both family files
point here; what differs between them stays in the family file.

Sources: the `firewall-cmd` man page,
<https://firewalld.org/documentation/man-pages/firewall-cmd.html>;
and firewalld's `reload`,
<https://github.com/firewalld/firewalld/blob/main/src/firewall/core/fw.py>.

## Commands

- Check status: `firewall-cmd --state`
- List rules: `firewall-cmd --list-all | sed -E "${fc:?}"` (`fc`:
  `rules/secrets.md` → Commands That Leak)
- Add rule: `firewall-cmd --add-service=http`, kept with
  `--permanent` once tested (see Changes over SSH)
- Reload: `firewall-cmd --reload`

## Starting firewalld

**Critical:** before `systemctl start firewalld` on a remote host,
verify the `ssh` service is in the active/default zone's permanent
config: `firewall-cmd --permanent --zone=<zone> --list-services`.
Add it if missing: `firewall-cmd --permanent --zone=<zone>
--add-service=ssh`. Starting `firewalld` without it cuts off the
SSH session immediately. The `ssh` service covers port 22 only:
add every other port sshd listens on with `--add-port=<port>/tcp`
(`AGENTS.md` → Critical Safety Rules).

## Changes over SSH

Changes over SSH go through `rules/ssh-safety-net.md`. Make them
without `--permanent` first, so that `firewall-cmd --reload` is
the revert: it replaces the runtime configuration with the
permanent one.

Loaded rules against the files (step 2 of the safety net), in
`sh`, which has no process substitution on Debian:

```
t=$(mktemp); p=$(mktemp)
for v in --list-all-zones --list-all-policies "--direct --get-all-rules"
do
  if firewall-cmd $v > "$t" && firewall-cmd --permanent $v > "$p"
  then diff "$t" "$p" | sed -E "${fc:?}" && echo "compared $v"
  else echo "unread $v"; fi
done
rm -f "$t" "$p"
```

Each view is compared only where `compared <view>` says so;
`unread <view>`, or no such line, means one side was not read, and
nothing is known about that view (`--list-all-policies` needs
firewalld 0.9). An ipset's entries are in none of the views. Any
line above a `compared` but an `interfaces:` line is runtime-only
state the revert discards too, possibly the rule SSH depends on. Settle it
with the user before the change. `--reload` binds every interface
to its zone again, NetworkManager's included (firewalld's
`reload`).

Once a fresh login works, repeat the commands with `--permanent`,
then `firewall-cmd --check-config`. Never
`--runtime-to-permanent`: it saves every runtime-only rule, not
just this change (the man page).

A change made with `--permanent` (the zone target, a service added
before starting firewalld) reverts by restoring the backed-up
`/etc/firewalld/`, then `firewall-cmd --reload`. Starting
firewalld reverts with `systemctl stop firewalld`.

## Default Zone

Note the default zone: `firewall-cmd --get-default-zone`. A custom
or renamed default zone is legitimate — what matters is the zone's
behavior, not its name. Verify it rejects unsolicited incoming
traffic: `firewall-cmd --info-zone=<zone> | sed -E "${fc:?}"` — the
target should be `default` (which means reject). If the zone
target is `ACCEPT`, fix with `firewall-cmd --permanent
--zone=<zone> --set-target=default` and `firewall-cmd --reload`.
