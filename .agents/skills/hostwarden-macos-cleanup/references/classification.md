# Classification

`scripts/scan.py` compares every entry in the scanned folders
(`locations.md`) with the installed apps. It collects the bundle
ids of each app and of its nested bundles (helpers, extensions,
XPC services), the Team ID and the app groups from the code
signature, the Homebrew packages and the commands on `PATH`.

## Classes

| Class       | Means                                  | Do            |
|-------------|----------------------------------------|---------------|
| `apple`     | Apple prefix, known Apple data, or an  | Never touch   |
|             | Apple launchd job                      |               |
| `installed` | Belongs to an installed app, command   | Never touch   |
|             | or Homebrew package                    |               |
| `orphan`    | No installed app has this bundle id,   | Verify, then  |
|             | Team ID or program                     | propose       |
| `vendor`    | Same vendor or Team ID as an installed | Find the      |
|             | app, but not its bundle id             | owner first   |
| `cache`     | Cache of a developer tool              | Own group     |
| `custom`    | launchd job that runs a program        | Only when     |
|             | outside an app bundle                  | asked         |
| `unclear`   | Plain name that matches nothing        | One by one    |

`orphans` leaves `apple` and `installed` out; `orphans --all`
prints them.

In the uninstall mode each entry carries `match` in place of a
class: `exact` for the app's own bundle ids and app groups,
`name` for folders named after the app or its vendor and for ids
and groups another app may share. `exact` entries are proposed as
one group, `name` entries one by one.

## Verify before proposing

A class is the scanner's reading of names. Before an `orphan` or
`vendor` entry is proposed, each of these checks runs for its
bundle id, label or helper name, and each has to end in its own
`none` line: empty output alone proves nothing
(`rules/verify-before-reporting.md`).

```
export LC_ALL=C
id='com.example.notes'
mdutil -s /
mdfind "kMDItemCFBundleIdentifier == '$id'" | grep . \
  || echo "none: no app with this id"
pluginkit -m -A | grep -iF -- "$id" || echo "none: no extension"
launchctl list | grep -iF -- "$id" || echo "none: no loaded job"
systemextensionsctl list | grep -iF -- "$id" \
  || echo "none: no system extension"
pgrep -f -- "$id" || echo "none: no process"
```

Use the id only if it consists of letters, digits, `.`, `_` and
`-`; any other character, and the entry is `unclear` with the
name in the report. `pgrep` prints process ids and no `-l`:
with `-f` that prints each process's arguments, which can hold
a credential (`rules/secrets.md`).

- `mdutil -s /` says whether Spotlight indexes the volume. With
  indexing off, `mdfind` finds nothing whatever is installed:
  list `/Applications`, `~/Applications` and the folders the
  user names instead, and say in the report that the app search
  ran without Spotlight.
- `launchctl list` shows the jobs of the logged-in user only. A
  job in the system domain is read with
  `launchctl print system/<label>`
  (`rules/os/macos.md` → Service Manager).
- A hit in any of them means the entry is in use. It stays, and
  goes under Kept with the hit.

A `vendor` entry needs one more answer: which installed app uses
it. The paths in the commands below come from the scan too: put
one into a command only when its name passes the check of
`removal.md` → Before the first move, Names, and otherwise report
the entry as `unclear` with the name. In this order:

1. A launchd job whose program is the entry. Read the two fields
   and nothing else of the plist (`locations.md` says why):

   ```
   export LC_ALL=C
   p='/Library/LaunchDaemons/com.example.helper.plist'
   plutil -extract Program raw -o - "$p" \
     || plutil -extract ProgramArguments.0 raw -o - "$p"
   ```
2. The Team ID of the helper against the installed apps:

   ```
   export LC_ALL=C
   codesign -dv "/Library/PrivilegedHelperTools/com.example.helper" \
     2>&1 | grep TeamIdentifier
   ```
3. The vendor's documentation for the app that ships the helper.

Where an installed app uses the entry, it stays. Where none of
the three names an owner, the entry goes under Needs a decision,
never under Leftovers.

Never open a file inside a matched folder to decide. Profiles,
mail stores and password databases live there; name, size, owner
and modification time are enough (`rules/secrets.md`).

## Why the rules are what they are

Each case below was seen on a real Mac.

- **Group containers carry a Team ID prefix.**
  `85C27NK92C.com.flexibits.fantastical2.mac` belongs to
  `com.flexibits.fantastical2.mac`. Some put `group.` first:
  `group.245B4P8J7P.com.staysorted.Sorted.3`.
- **Group containers are named after app groups, not bundle
  ids.** Office uses `UBF8T346G9.Office` and `UBF8T346G9.ms`,
  Wipr `group.wipr2.rules`. The scanner reads
  `com.apple.security.application-groups` from each app's
  entitlements, of the app itself and not of its nested bundles;
  a listed group is `installed`. In the uninstall mode a group
  another installed app declares is skipped. A group prefixed
  with the app's Team ID is `exact` when no other installed app
  has that Team ID: LocalSend's
  `3W7H4PYMCV.localsend.shared_group` is, Word's groups are not
  while Excel or AutoUpdate is installed. Every other group is a
  `name` match, and so is every group of an app without a Team
  ID: WhatsApp declares `group.com.facebook.family`, which apps
  of another team can declare too.
- **The same vendor is not the same app.** With Pastebot 3
  (`com.tapbots.Pastebot3Mac`) installed, the containers of Ivory
  and of Pastebot 2 are still leftovers. They come out as
  `vendor`, not `installed`.
- **Libraries do not name a vendor.** Ids inside a `.framework`
  or `.bundle` do not count, all other nested ids do. A library
  id counts when it shares the two-part prefix of the app's main
  id, unless that prefix is generic like `com.electron`.
  GoogleUpdater ships `com.google.Keystone` in a `.bundle`, so
  Keystone counts as its own. Firebase brings `com.google.*` ids
  into other apps, and `com.google.Chrome` stays an `orphan`
  all the same. The uninstall mode ignores other library ids
  too: a Sparkle id is no `exact` match for one app.
- **Two installed apps can ship the same library id.** Chrome
  embeds GoogleUpdater. Uninstalling Chrome does not list
  `com.google.GoogleUpdater`, the main id of an installed app,
  and `com.google.Keystone` entries are `name` matches for either
  until one of the two is gone.
- **A similar bundle id is not the same app.** Teams classic left
  `com.microsoft.teams`; the installed Teams is
  `com.microsoft.teams2`.
- **An older major version is a leftover.** With Acorn 8
  installed, `com.flyingmeat.Acorn7.*` is one.
- **Helpers of installed apps have ids of their own.** Office
  uses `com.microsoft.autoupdate.helper` and
  `com.microsoft.office.licensingV2.helper`, Viscosity
  `com.sparklabs.ViscosityHelper`, TimeMachineEditor
  `com.tclementdev.timemachineeditor.scheduler`. All come out as
  `vendor`, and all stay.
- **Vendor folders use the company name.** Firefox keeps data in
  `Mozilla` and `Firefox`, Brave its profiles in `BraveSoftware`,
  ChatGPT in `OpenAI`. These hold profiles with passwords and
  bookmarks. A folder named like the second label of an app's own
  bundle id is `vendor`: `Mozilla` matches `org.mozilla.firefox`.
  The whole name has to match, and nested frameworks do not
  count: `Google` holds Chrome's profiles whatever Firebase ids
  other apps carry.
- **A vendor folder can serve several apps.** The uninstall mode
  skips a vendor folder that any id of another installed app
  names.
- **Apple data often has no Apple prefix.** `coreMLCache`,
  `GeoServices`, `CloudDocs`, `CallHistoryDB`, daemon folders
  like `tipsd`, Shortcuts (`group.is.workflow.*`) and CUPS
  (`org.cups.*`). `ParrotAudioPlugin.driver` is Apple's too,
  which is why the scanner reads the bundle id of driver and
  plug-in bundles.
- **Developer caches belong to tools.** `ms-playwright`, `pip`,
  `mix` and others can hold gigabytes. The tool downloads or
  builds them again on its next run, which costs time and
  network (`rules/disk-space.md` → The Four Classes). Where the tool
  is installed and has a clean command of its own, propose that
  command in place of the move.
- **Own launchd jobs look like leftovers.** A job such as
  `com.user.restart_exchangesyncd.plist` that runs a script from
  `~/.local/bin` is the user's own work. Jobs with a program
  outside an app bundle are `custom`.
- **UUID folders in Application Scripts.** Empty folders named by
  a UUID without a matching container are what removed
  extensions leave. Elsewhere a UUID name says nothing.
- **Dead symlinks.** A link whose target is already gone is
  reported as one; `removal.md` says how it is removed and
  checked.
- **Several apps can share a name.** A second `Firefox.app`
  under `~/Library/Application Support` is a real case. The
  uninstall mode stops and lists every path in `candidates`.
