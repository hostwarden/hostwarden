# Locations

`scripts/scan.py` lists the top level of each folder below and
descends into none of them.

## Per user (`~/Library`)

| Folder                    | Holds                                    |
|---------------------------|------------------------------------------|
| `Application Support`     | App data, often in a folder named after  |
|                           | the app or its vendor                    |
| `Application Scripts`     | Script folders of sandboxed apps and     |
|                           | extensions, mostly empty                 |
| `Caches`                  | Caches                                   |
| `Containers`              | Sandbox data per bundle id               |
| `Group Containers`        | Data an app shares with its extensions,  |
|                           | often with a Team ID prefix              |
| `Preferences`             | `<bundle id>.plist`                      |
| `Saved Application State` | Window state                             |
| `HTTPStorages`, `WebKit`, | Web data of apps with an embedded        |
| `Cookies`                 | browser                                  |
| `LaunchAgents`            | launchd jobs of the user                 |
| `Logs`                    | Logs                                     |
| `Internet Plug-Ins`,      | Plug-ins, usually empty today            |
| `PreferencePanes`,        |                                          |
| `QuickLook`,              |                                          |
| `Screen Savers`           |                                          |

## System (`/Library`)

| Folder                   | Holds                                     |
|--------------------------|-------------------------------------------|
| `LaunchDaemons`          | launchd jobs that run as root             |
| `LaunchAgents`           | launchd jobs for every user               |
| `PrivilegedHelperTools`  | Root helpers of apps, started by a        |
|                          | LaunchDaemon                              |
| `Application Support`    | Shared data and updaters                  |
| `Audio/Plug-Ins/HAL`     | Audio drivers                             |
| `Extensions`             | Kernel extensions                         |
| `Preferences`, `Caches`, | As per user                               |
| `Logs`                   |                                           |
| `Internet Plug-Ins`,     | As per user                               |
| `PreferencePanes`,       |                                           |
| `QuickLook`,             |                                           |
| `Screen Savers`          |                                           |

Two kinds keep running after their app is gone: launchd jobs with
their helpers, and drivers or extensions. Look at them first.

Not a folder, and a leftover all the same: installer receipts.
`pkgutil --pkgs` lists them. They take no space.

System extensions live in a database, not in `/Library`:

```
systemextensionsctl list
```

## Outside the scan

The scanner does not look at `~/Library/Keychains`, `~/.ssh`,
dotfiles in the home directory, `/usr/local`, `/opt`, `/private`
or other volumes. What an app left there is not in the report;
say so when the user asks whether the report is complete.

## Manual probes without the Command Line Tools

Where the scanner cannot run (`SKILL.md`, step 3), these read-only
probes give the material, and `classification.md` the rules to
classify it by hand.

Installed bundle ids:

```
export LC_ALL=C
mdfind "kMDItemContentType == 'com.apple.application-bundle'" \
  | while IFS= read -r app; do
      defaults read "$app/Contents/Info" CFBundleIdentifier
    done 2>/dev/null | sort -u
```

Team IDs of the installed apps:

```
export LC_ALL=C
for app in /Applications/*.app; do
  codesign -dv "$app" 2>&1 | grep TeamIdentifier
done | sort -u
```

Entries per folder, largest last, one folder per call:

```
export LC_ALL=C
du -sk "$HOME/Library/Application Support"/* | sort -n | tail -30
```

launchd jobs whose program is missing. launchd prefers `Program`
over `ProgramArguments`, and a bare command name goes through
`PATH`. Only these two fields are read: a job's plist can carry
environment variables with a secret in them, so it is never
printed whole (`rules/secrets.md`):

```
export LC_ALL=C
for p in "$HOME"/Library/LaunchAgents/*.plist \
         /Library/LaunchAgents/*.plist \
         /Library/LaunchDaemons/*.plist; do
  prog=$(plutil -extract Program raw -o - "$p" 2>/dev/null \
    || plutil -extract ProgramArguments.0 raw -o - "$p" 2>/dev/null)
  case "$prog" in
    /*) [ -e "$prog" ] || echo "$p: $prog" ;;
    ?*) command -v "$prog" > /dev/null || echo "$p: $prog" ;;
  esac
done
echo "launchd jobs checked"
```

Group containers, vendor folders and helpers cannot be matched to
their apps this way. A report built from these probes proposes
only entries whose bundle id no installed app has, and lists the
rest under Needs a decision.
