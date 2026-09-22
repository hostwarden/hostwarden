# Safety Net for Changes That Can Cut SSH

A change to the firewall — its rules, or starting and
enabling it — or to the network configuration (addresses,
routes, bridges, bonds) decides whether packets still reach
sshd. A wrong one ends the session that could undo it. So
the undo is armed on the host before the change, and runs
on its own unless a working login cancels it.

The loaded OS or appliance file names three commands for
its tool: a **check** that changes nothing, the **apply**,
and the **revert**. Where it names no revert, do not apply
over SSH: the user applies the change with console access
ready. A tool that arms its own timed revert when it
applies names an **apply and arm** and a **confirm**
instead; they stand in for steps 4, 5 and 7 below.

## The steps

1. **Agree on it.** The change is the user's decision
   (`AGENTS.md` → Critical Safety Rules), and so is the
   window: say that the change undoes itself after five
   minutes, five to ten on FreeBSD (step 4), unless a new
   login succeeds.
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
   exists. With neither systemd nor a working `at`, stop
   here and hand the change to the user.
5. **Apply.**
6. **Test with a fresh login** (`rules/ssh-connections.md`
   → Fresh-login options) that also prints what the change
   was meant to do — the rule set, the address, the route.
7. **Login works:** cancel the revert —
   `systemctl stop hostwarden-revert.timer`, or
   `atrm <job>` — and confirm it is gone. A revert left
   armed undoes, minutes later, a change the user kept.
   In the same call, persist only the tested change, never
   the whole live state, and where starting a firewall and
   enabling it at boot are separate commands, enable it.
8. **Login fails:** change nothing more. Wait for the
   revert, then try a fresh login again. If the host still
   does not answer, follow `rules/ssh-unreachable.md` and
   tell the user it needs the console.

Log the change and its outcome, including a revert that
fired (`rules/changelog.md`).
