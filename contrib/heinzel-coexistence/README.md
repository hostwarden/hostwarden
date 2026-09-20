# Telling heinzel That hostwarden Exists

Custom rules for a **heinzel** checkout, for the time
when both tools administer the same hosts.

hostwarden knows about heinzel: its activity check
reads both journal tags, and the first connection to
a host looks for what heinzel left there. heinzel
knows nothing about hostwarden — it reads only its
own tag, so work done by hostwarden is invisible to
it, and its server memory silently drifts away from
the host.

These three files close that gap from heinzel's side.
They are heinzel rule overrides, not hostwarden
files; nothing here is read by hostwarden.

## Install

Copy them into the heinzel checkout, without
clobbering anything that is already there:

```bash
DST=/path/to/heinzel/memory/custom-rules
for f in all.md activity-check.md backups.md; do
  if [ -e "$DST/$f" ]; then
    echo "exists, merge by hand: $DST/$f"
  else
    cp "contrib/heinzel-coexistence/$f" "$DST/$f"
  fi
done
```

The loop rather than `cp -n`, which skips an existing
file without saying which — and a silently skipped
file is the whole failure: the heinzel checkout keeps
its old rule and stays unaware of hostwarden. Every
name it prints has to be merged by hand: open that
file and add the sections from this one. `all.md`
especially, which an installation may already use for
its own rules.

heinzel reads `all.md` once per session and
`<rule>.md` whenever it reads `rules/<rule>.md`. The
directory is gitignored there, so this stays local
unless the user shares custom rules deliberately.

The `hostwarden-adopt` skill offers to do this for
you, following this section.

## What they change

- `activity-check.md` — heinzel reads both journal
  tags, so hostwarden's work shows up in its activity
  summary, and a fresh hostwarden entry warns that a
  session may be running right now.
- `backups.md` — heinzel looks in
  `/var/backups/hostwarden/` as well, and does not
  report its own backup directory as lost when
  hostwarden has adopted it.
- `all.md` — the general rules of the parallel phase:
  server memory is a hint rather than a fact, the
  other tool's files are not litter to clean up, and
  two agents on one host at the same time is the risk
  worth naming.

## When to remove them

When the transition is over and heinzel no longer
touches these hosts. Deleting the three files is
enough; they change nothing else.
