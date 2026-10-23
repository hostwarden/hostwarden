# Diagnosing a Fault

Something is broken, slow or failing and the cause is not
obvious. Reading configs and logs until a theory forms finds
theories, not causes, and the first plausible one gets fixed
whether or not it is the right one. Find the cause by this
order. Skip a step only by saying which and why.

## 1. Show the symptom

Run one **read-only** command that shows the user's exact
symptom: the error, the wrong value, the timing, the failing
request. Not a different fault nearby: the wrong fault gets the
wrong fix. Examples: `curl -sS -o /dev/null -w '%{http_code}
%{time_total}\n' <url>`, `systemctl is-active <unit>`,
`dig +short <name>`.

- Bound it (`rules/log-queries.md`), and run it as a job when it
  can take over a minute (`rules/ssh-connections.md` → Long
  jobs).
- Print what the system returned and let the output speak
  (`rules/verify-before-reporting.md` → Never pre-bake the
  verdict into the check).
- Write down the output as it is now. This is the baseline every
  later run is compared with.

A symptom that appears only sometimes is checked at a higher
rate: run the command in a bounded loop, or ask the user what
they do just before it happens. Never loop `ssh` itself: a fault
in reaching a host follows `rules/ssh-unreachable.md`, which
wins over this file. If it still does not show,
**stop and say so**: list what you ran, and ask for what is
missing (the exact request, the time it last happened, a login
on the right host). No hypotheses without a symptom.

## 2. Rank the hypotheses

Before changing anything, write three to five causes, most
likely first. Each one carries a prediction that can fail: "if
the disk is full, `df` shows 100% on `/var`, and the log
shows `No space left`." A hypothesis without a prediction is a
hunch; sharpen it or drop it.

Show the list to the user before testing. What they know
("we changed the proxy on Tuesday") re-ranks it for free. If
nobody answers, go on with your ranking.

Check the host's memory, `todo.md`, the changelog and the
user's decisions first (`rules/decisions.md`): a setting that
looks like the fault is often a decision.

## 3. Test with reads first, then one change at a time

Test each prediction with reads before any change. The reads
that settle most faults — the unit's state and journal, `df`,
`free`, `ss`, `dig`, a config test — need no change and no
root.

When a hypothesis can only be tested by changing something:

- **One change at a time.** Two at once leave you not knowing
  which one mattered.
- **Decide the revert before the change**, and say it. A config
  file: back it up first (`rules/backups.md`). A firewall,
  network or login-shell change: the safety net first
  (`rules/ssh-safety-net.md`). Anything else: the command that
  undoes it, ready to run.
- **Ask before it** as the rules for that kind of change say:
  restarts, firewall, storage and the rest of the list in
  `AGENTS.md` → Critical Safety Rules.
- **Run the step 1 command again** after every change and
  compare with the baseline. The change did not matter if the
  output is the same; undo it, so that it is not mistaken for the
  fix.

Raising a log level, enabling a debug option or adding a trace
is a change like any other. Ask first, change the one setting
that separates two hypotheses, and tag what you add so that
removing it is a search: a comment `# hostwarden-debug-<id>`
beside the line, or a drop-in file with that name. Note it in the
host's `todo.md` when you add it and mark it `[x]` when it is gone
(`rules/machine-memory.md`), so a session that ends or breaks
off in between leaves the removal to the next one. Logging
everything and grepping is not instrumentation. When the
question is answered, remove what you added, reload or restart
as `rules/service-reload.md` says, and check the tagged text is
gone. A debug setting left on fills a disk and logs secrets.

**sshd and dropbear are never debugged by a configuration
change.** Their configuration stays untouched (`AGENTS.md` →
Critical Safety Rules). Read the journal or auth log the daemon
already writes, and ask the user for a console where more is
needed.

## 4. Fix, then confirm

Fix what the confirmed cause calls for, as any other change
(`rules/backups.md`, `rules/config-management-changes.md`). Run
the step 1 command once more: the symptom is gone, and the
output shows it, not a sentence you wrote. Then tell the user
the cause and the evidence, in
that order, as `rules/verify-before-reporting.md` requires; a
cause the evidence does not show is a lead, and is called one.

## 5. Write it down

The cause and the evidence that confirmed it go into the
changelog entry for the fix: a headline with `— because
<cause>`, and in the local changelog a `Detail:` with the
command and what it showed, a `Rollback:` for each change kept
(`rules/changelog.md`). The next session on this host reads it
instead of finding the cause again. A change that was tried and
undone is named in that entry's `Detail:` as a cause ruled out
when that saves the next session the same trip.
