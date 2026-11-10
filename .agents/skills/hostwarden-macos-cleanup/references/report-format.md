# macOS Cleanup Report Format

The orphans mode prints this structure, and nothing before or
after it:

```
## macOS Cleanup Report: mac1.example.com (alice)

Date: YYYY-MM-DD HH:MM
Scanned: 392 apps, 41 Team IDs

### Leftovers (verified)

AdGuard            176 MB   6 entries
Fantastical        110 MB  11 entries
OrbStack             1 MB   2 entries   /Library, root helper
TeamViewer           0 MB   3 receipts

### Needs a decision

Mozilla            Firefox is installed, holds its profiles
Arc                no app, name only

### Caches (rebuilt on demand)

ms-playwright      933 MB
pip                119 MB

### Kept

Microsoft AutoUpdate helper      used by Office
Viscosity helper                 used by Viscosity
com.user.restart_exchangesyncd   own launchd job

### Skipped

~/Library/Containers   not readable, Full Disk Access is off
```

The uninstall mode:

```
## Uninstall: Brave Browser on mac1.example.com (alice)

App        /Applications/Brave Browser.app   559 MB
Running    no
Homebrew   cask brave-browser
Exact      6 entries   847 MB
By name    BraveSoftware   788 MB   profiles and passwords
Receipts   none
Skipped    none
```

## Rules

- The title names the host and the user whose Library was
  scanned.
- Group leftovers by app, largest first. One line per app.
- Put the verification result in the line where it changes the
  decision: `root helper`, `launchd job loaded`,
  `holds passwords`. An entry under `/Library` says so.
- **Kept** lists only the `vendor` and `custom` entries whose
  owner the verification found. Leave out `apple` and
  `installed`.
- **Skipped** lists every path from `unreadable` with the reason,
  and the checks that did not run. Without the scanner it also
  says that the report comes from the manual probes. Leave the
  section out when it is empty.
- On a read-only or locked host, close with one line: the
  entries that would have been proposed, and that nothing was
  moved.
- List single paths only when the user asks, and per app before
  a removal.
- Sizes come from the scanner's `bytes`, in MB or GB. Mark a size
  the scanner could not fully read with `≥`.
- No recommendation beyond the groups themselves. The question
  of step 7 follows the report; it is not part of it.
