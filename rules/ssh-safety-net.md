# Safety Net for Changes That Can Cut SSH

A change to the firewall — its rules, or starting and
enabling it — to the network configuration (addresses,
routes, interfaces, VLANs, bridges, bonds), to a network
sysctl (`net.ipv4.*`, `net.ipv6.*`, FreeBSD's `net.inet.*` and
`net.inet6.*`) or to a VPN or tunnel
the SSH path runs through decides whether packets still
reach sshd. A change to PAM (`/etc/pam.d/`) or to the shell
sshd starts for a login decides whether a login still gets
one. A wrong one ends the session that could undo it. So
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

PAM and a network sysctl have no tool file; their commands:

- **PAM:** no tool checks PAM syntax, so step 3 is a reading,
  not a gate: `diff -u` of the new file against the step-2
  backup (it exits 1 for any real edit), and for each module
  line that the module file exists at its path, or for a bare
  name by looking for the file itself (`find /lib /usr/lib
  -name '<module as written>*'`, which also finds macOS's
  `.so.2`);
  `@include` files and the control flags are read the same way. The
  authentication test below is
  the safety. Apply writes the file (PAM reads its files at each login, so
  nothing reloads); revert restores the backup. A
  key login runs PAM's account and session modules only, never
  its `auth` stack, so the step-6 login does not test a change
  to one (`common-auth`, `sudo`, `sshd`), and no call of
  Hostwarden can, since none authenticates by password. Say so
  in step 1. The revert stays armed until the user has tried
  the changed service's own authentication, a password or
  keyboard-interactive login for `sshd`, a `sudo` that prompts
  for the password and takes it for `sudo` (`sudo -k` first,
  since a cached credential or `NOPASSWD` skips the stack),
  with the console `rules/management-controller.md` → The
  rescue path names open; a key login proves none of it. If
  that is not tried, let the revert fire.
- **A network sysctl:** check `sysctl -n <key>`, which gives
  the old value; apply `sysctl -w <key>=<value>`; revert
  `sysctl -w <key>=<old value>`. The file that persists it
  (`sysctl.d/`, FreeBSD's `/etc/sysctl.conf`) is written in
  step 7.
- **A VPN or tunnel:** the file that covers it
  (`rules/mesh-vpn.md`, the OS file) names the commands. Where
  none does, the change has no revert to arm: it is the
  user's, at the console.

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
  (`rules/mesh-vpn.md`), and its own SSH server rather than
  sshd where that file's This session came in through one
  says so. Tailscale's server answers inside the agent, past
  the host firewall, so a fresh login through it proves
  nothing about a firewall change: test on a path to sshd, or
  say in step 1 that none was tested;
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
tests in the `- Access:` line (`rules/machine-memory.md`).

## The steps

A firewall, network, VPN or network sysctl change on a host in
service, not one this session is creating, goes through
`bin/hostwarden-impact announce <host> firewall|network` and
`wait`, as `rules/coordination.md` → Announce, wait, go says,
before step 5 applies it: `firewall` for a firewall change,
`network` for the rest. A firewall or network reload takes the
whole radius, guests and jump-host traffic included. PAM and a
login shell reach no one else and are not announced. `impact.sh` denies the
apply mechanically where
another live session is on the radius and this session has not;
announcing before step 1 means the window agreed there already
accounts for it.

1. **Agree on it.** The change is the user's decision
   (`AGENTS.md` → Critical Safety Rules), and so is the
   window: say that the change undoes itself after five
   minutes, five to ten on FreeBSD (step 4), unless a new
   login succeeds, or after the longer window a play run
   from the workstation needs (step 5). Name the path this session came in on
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
4. **Arm the revert**, and run step 5 in the same command,
   joined with `&&`, so the change never runs without an armed
   timer and no turn between the two eats into the window. The
   timer is detached from the SSH session:

   On a host with systemd:

   ```bash
   systemd-run --unit=hostwarden-revert --collect \
     --on-active=5min sh -c '<revert>' &&
     systemd-run --unit=hostwarden-apply --collect --wait \
       sh -c '<apply>'
   systemctl list-timers hostwarden-revert.timer
   ```

   The apply runs under systemd, so a connection the change
   drops does not kill it halfway; `--wait` returns once it
   has finished; its output is in `journalctl -u
   hostwarden-apply`, not tied to the session. A shell started
   this way has none of the session's variables, so the apply
   writes out what it uses. The unit name is fixed, so a
   second window makes the first `systemd-run` fail and `&&`
   skips the apply.

   Elsewhere, with `at`, the apply runs in the SSH session and
   is not detached. `at` queues a job even when nothing will
   run it, and `atq` lists every user's jobs, so the proof is
   the daemon that runs them: `pgrep -x atd`, or on FreeBSD
   `test -f /etc/cron.d/at`. macOS disables `atrun` by default,
   so there is no timer there. An apply of several commands is
   grouped, so `&&` covers all of it:

   ```bash
   <daemon check> &&
     echo '<revert>' | at now + 5 minutes && { <apply>; }
   ```

   FreeBSD starts `at` jobs from `atrun`, which
   `/etc/cron.d/at` runs every five minutes, so the revert
   lands five to ten minutes later. Where the loaded OS file names its own way
   to arm the revert and to cancel it (Windows: a scheduled
   task), use that. Its arm call reports success in its
   output, not in its exit status: the apply follows in a
   call of its own, once the arm printed that it is armed.
   With none of these, stop here and hand the change to the
   user with the console `rules/management-controller.md` →
   The rescue path names.
5. **Apply**, as the second half of step 4's command, except
   where the OS file's arm call is separate or the apply runs
   on the workstation, as an Ansible play does
   (`rules/workspace-playbook.md`). Then the arm is a call of
   its own that confirms the timer is pending, the apply
   follows only after that. The timer must outlast the run:
   one host at a time, and the arm call's `--on-active` (or
   `at` time) is the longer window the user agreed to in
   step 1, not five minutes. Where a tool
   separates runtime from boot configuration, change the
   runtime only and persist in step 7 (firewalld without
   `--permanent`, whose revert is then `firewall-cmd --reload`).
   A network configuration is applied from its files, so the
   login tests them.
6. **Test with a fresh login** (`rules/ssh-connections.md`
   → Fresh-login options) that also prints what the change
   was meant to do — the rule set, the address, the route.
   When the change moves the host's address, the login goes
   to the new one (→ When the address moves).
7. **Login works:** persist only the tested change, never
   the whole live state.
   Where the revert restores the step-2 backup of the file
   that is persisted (a network file, `/etc/pf.conf`), persist
   it, run the tool's check of step 3 on it and cancel the
   revert in one call joined with `&&`: a file that fails its
   check leaves the armed revert to put the backup back. A
   check that prints its result, such as the loaded OS file's
   `rc=<n>`, and exits 0 whatever it found is tested on that
   result, not on its exit status. Where
   the revert undoes the runtime only (firewalld's
   `--reload`, a sysctl's `sysctl -w`), cancel it first, then
   persist, and read the persisted file back, since a revert
   that fired after the write would reload what was written.
   Nothing is armed in that gap, so before the cancel, add a
   task to the host's `todo.md` (`rules/machine-memory.md`)
   that names the file to persist, the command that writes it
   and the revert, and mark it `[x]` once the read-back
   matched. If the write or the read-back fails, the runtime
   and the files disagree, and the revert alone does not close
   that: it resets the runtime, not a file that was written.
   Put the files back from the step-2 backup, then make the
   runtime match (a sysctl: `sysctl -w <key>=<old value>`;
   firewalld: `firewall-cmd --reload`, which loads the restored
   files, so arm the revert and test with a fresh login as in
   steps 4 to 6). Or, if the user wants the change kept,
   correct the file and persist again. Tell the user which.
   A PAM file persists nothing here. On Windows, whose cancel
   reports in its output and not its exit status, the check
   runs first and the cancel follows in a call of its own once
   it passed. The cancel is
   `systemctl stop hostwarden-revert.timer`,
   `atrm <job>`, or the OS file's. Confirm the revert
   is gone, and only then, where starting a firewall and
   enabling it at boot are separate commands, enable it. A
   revert left armed undoes, minutes later, a change the user
   kept. If a check fails and the revert is
   still armed, let it fire, report what it restored, and
   start the change again with the file corrected; do not race
   the timer.
8. **Login fails:** change nothing more. Wait for the
   revert, then try a fresh login again. If the host still
   does not answer, follow `rules/ssh-unreachable.md` and
   tell the user which console it needs, by name and
   address (`rules/management-controller.md` → The rescue
   path).

Never reboot the host while the revert is armed: a reboot
boots the new files from disk without the timer.

Log the change and its outcome, including a revert that
fired (`rules/changelog.md`).

## When the address moves

The old address no longer answers once the change works. The
fresh login of step 6 names the host as always, so its port,
jump host and user stay, and adds `-o HostName=<new-address>`
and `-o HostKeyAlias=<key name>` to the options of
`rules/ssh-connections.md` → Fresh-login options. The key
name is the one `rules/host-keys.md` → Before the First
Connection looks up, `[<name>]:<port>` off port 22, so the
key already in `memory/known_hosts` is the one checked.
Cancel the timer only through that login, never from the old
session. A new address that answers with another host key is
not this host: leave the timer armed.

Once the login worked, the address is made permanent before
the move counts as done: the host's `- IP:` line in memory
takes the new address, and its name resolves to it through
`rules/ssh-config.md` → Adding a Block, which keeps
`HostKeyAlias`, regenerates `memory/ssh_config` and checks the
result with `ssh -G`. A host that logs in by password finds no
stored password at the new address (`rules/ssh-passwords.md`):
tell the user before the next login.

## Failures that show later

The window tests the login, not the next boot, the next cron
run or the next renewal. Before the change is called done,
and always before a reboot, run what proves the files:

- `fstab` (Linux): `findmnt --verify`; a typo hangs the next
  boot in emergency mode. Mounting or editing an entry is a
  storage change (`rules/storage.md`).
- A unit enabled with `enable` (systemd): `systemd-analyze
  verify <unit>` before the next boot needs it; starting it
  follows `rules/port-check.md`.
- A cron job or timer: its command once by hand, as its user.
- A network or firewall configuration file written in step 7
  rather than loaded by the apply, and a sysctl file: checked
  or read back as step 7 says.
- A renewal or rotation configuration: its dry run
  (`certbot renew --dry-run`, `logrotate -d <file>`).
- A one-shot boot entry (`efibootmgr` `BootNext`, `grub-reboot`)
  applies to the next boot only: the old entry stays the way
  back, and the change is proven when that boot has come up.
