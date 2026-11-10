---
sidebar_position: 9
description: Finds what removed apps left behind on a Mac, and
  uninstalls one app together with everything it created.
---

# Cleaning up a Mac

```
 ❯ Find what old apps left behind in my Library
 ❯ Uninstall Example Notes completely on mac1
```

`hostwarden-macos-cleanup` works on a Mac over SSH or on the one
you sit at. It runs only when you ask for it, never because a disk
is full.

## Two ways to use it

- **Leftovers.** It lists what apps that are no longer installed
  left in `~/Library` and `/Library`: application support folders,
  containers, preferences, caches, launchd jobs, privileged
  helpers, audio drivers and installer receipts.
- **One app, whole.** It finds the same for an app that is still
  installed, so the app and everything it created go together.

## Report first

- **Nothing is moved before you have seen the list.** Each entry
  comes with its size, the app it belonged to and how sure the
  match is; you confirm what goes.
- **A name is a lead, not a finding.** Before an entry is reported
  as a leftover, Hostwarden checks that no installed app, running
  process, Homebrew package or launchd job still uses it.
- **A folder macOS refuses to show is listed as skipped**, never
  counted as empty. Full Disk Access is yours to grant in System
  Settings.

## What it changes

- **It moves to the Trash and deletes nothing.** Space is free only
  once you empty the Trash, and until then everything can be put
  back.
- **It never uses root.** What sits in `/Library` and needs an
  administrator comes back as a command block for you to run.
- **A launchd job is unloaded before its file moves.**
- **On a read-only or locked host** you get the scan and the report,
  and nothing else.
