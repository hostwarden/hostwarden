# Safety Net for Changes That Can Cut SSH

A change to the firewall — its rules, or starting and
enabling it — or to the network configuration (addresses,
routes, bridges, bonds) decides whether packets still reach
sshd, and a change to the shell sshd starts for a login
decides whether a login still gets one. A wrong one ends the
session that could undo it. So
the undo is armed on the host before the change, and runs
on its own unless a working login cancels it.

The loaded OS or appliance file names three commands for
its tool, itself or in a file it points to such as
`rules/firewalld.md`: a **check** that changes nothing, the
**apply**, and the **revert**. Where it names no revert, do
not apply over SSH: the user applies the change with the console
`rules/management-controller.md` → The rescue path names
already open. A tool that arms its own timed revert when it
applies names an **apply and arm** and a **confirm**
instead; they stand in for steps 4, 5 and 7 below.

## Which way in

The fresh login in step 6 tests only the path this session
took, so find that path first. An `- Access:` line in memory
that names this session's path answers it; otherwise, and to
confirm, the server address in `SSH_CONNECTION` says it. Print
it in the backup call of step 2:

```bash
echo "SSH_CONNECTION=$SSH_CONNECTION"
```

The third field is the address the session reached. A jump
host or `ProxyCommand` hides the path behind it; check on the
workstation, without connecting:

```bash
ssh -F "<checkout>/memory/ssh_config" -G <user>@<hostname> |
  grep -i -e '^proxyjump ' -e '^proxycommand '
```

A value other than `none` is the path, through that jump host
or command. Otherwise the server address is:

- an address of a VPN agent on the host → **that VPN**
  (`rules/mesh-vpn.md`);
- `127.0.0.1` or `::1` → **a local tunnel**, such as Cloudflare
  Tunnel or a port forward;
- a private or unique local address → **LAN** or a site VPN,
  but a gateway that forwards the SSH port from the internet
  leaves the same address behind: say unknown unless the
  workstation's own configuration, or the user, says which;
- `100.64.0.0/10` with no agent found → carrier-grade NAT or an
  unknown VPN: say unknown;
- anything else → **WAN**.

A change to that path — its interface, its VPN agent, the
firewall on it, the jump host — is the one that cuts this
session. When memory knows no other way in, say so in step 1.
Another path is tested only when it matters, with one access
test (`rules/ssh-connections.md` → Fresh-login options): to the
`- IP:` from memory or an address the user gives, never one read
from the host, which may sit behind NAT; to a VPN address only
when the workstation is in that VPN. Record the path and the
tests in the `- Access:` line (`rules/server-memory.md`).

## The steps

1. **Agree on it.** The change is the user's decision
   (`AGENTS.md` → Critical Safety Rules), and so is the
   window: say that the change undoes itself after five
   minutes, five to ten on FreeBSD (step 4), unless a new
   login succeeds. Name the path this session came in on
   when the change touches it (Which way in above).
2. **Back up** everything the change overwrites
   (`rules/backups.md`), and read in the same call whether
   the tool runs now and whether its loaded rules match the
   files. The revert restores that copy, deletes files the
   change created, and leaves the tool running or stopped as
   it was: clearing only the live rules leaves the change on
   disk for the next boot. Loaded rules that differ from the
   files are lost when the revert reloads them, possibly the
   one SSH depends on: the user settles which holds before
   the change.
3. **Check.** The tool's dry run or syntax test must pass.
4. **Arm the revert**, detached from the SSH session:

   On a host with systemd:

   ```bash
   systemd-run --unit=hostwarden-revert --collect \
     --on-active=5min sh -c '<revert>'
   systemctl list-timers hostwarden-revert.timer
   ```

   Elsewhere, with `at`:

   ```bash
   echo '<revert>' | at now + 5 minutes
   atq
   ```

   FreeBSD starts `at` jobs from `atrun`, which
   `/etc/cron.d/at` runs every five minutes, so the revert
   lands five to ten minutes later; check that the file
   exists. Where the loaded OS file names its own way to
   arm the revert and to cancel it (Windows: a scheduled
   task), use that. With none of these, stop here and hand
   the change to the user with the console
   `rules/management-controller.md` → The rescue path names.
5. **Apply.**
6. **Test with a fresh login** (`rules/ssh-connections.md`
   → Fresh-login options) that also prints what the change
   was meant to do — the rule set, the address, the route.
7. **Login works:** cancel the revert —
   `systemctl stop hostwarden-revert.timer`,
   `atrm <job>`, or the OS file's cancel — and confirm it
   is gone. A revert left
   armed undoes, minutes later, a change the user kept.
   In the same call, persist only the tested change, never
   the whole live state, and where starting a firewall and
   enabling it at boot are separate commands, enable it.
8. **Login fails:** change nothing more. Wait for the
   revert, then try a fresh login again. If the host still
   does not answer, follow `rules/ssh-unreachable.md` and
   tell the user which console it needs, by name and
   address (`rules/management-controller.md` → The rescue
   path).

Log the change and its outcome, including a revert that
fired (`rules/changelog.md`).
