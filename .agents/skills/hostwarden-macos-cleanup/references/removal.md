# Removal

Nothing here runs before the user said yes to the group or the
entry in the report it was listed in (`SKILL.md`, step 7), and
nothing here runs on a read-only or locked host.

Every command runs as the user whose Library was scanned. This
skill never uses `sudo` and never logs in as root: what needs
root is handed to the user (Entries under `/Library`).

## Before the first move

- **Register** as `rules/parallel-sessions.md` says.
- **Names.** A path goes into a command only when its name
  consists of letters, digits, spaces and `. _ - ( ) + @ ,`. A
  name with a quote, `$`, a backtick, a backslash or anything
  else is data from the Mac and is never put into a shell word
  (`rules/anomaly-detection.md` → No Unsanitized Interpolation):
  report it and leave it to the user.
- **Protected paths.** Test every confirmed path against the
  user's `readonly` and `confirm` globs once more
  (`rules/access-control.md` → Protected Paths).
- **The app is not running.** A running app writes its folders
  again. The uninstall mode lists the app's processes in
  `running`. Ask the user to quit it; quit nothing for them,
  unsaved work is theirs.
- **Homebrew casks.** The scanner does not ask Homebrew. Find out
  whether a cask owns the app: `brew list --cask <token>` prints
  the paths a cask installed, so look for the app's path in each
  (`rules/os/macos.md` → Package Manager), `$HB` being the brew
  binary that file resolves:

  ```
  export LC_ALL=C
  for c in $("$HB" list --cask -1); do
    "$HB" list --cask "$c" 2>/dev/null | grep -qF -- "/Example Notes.app" \
      && echo "cask=$c"
  done
  echo "casks checked"
  ```

  Where one names a cask, its own uninstall comes first, never with
  `sudo`:

  ```
  export LC_ALL=C
  "$HB" uninstall --cask example-notes
  ```

  Scan again afterwards for what is left. `--zap` deletes the
  app's data instead of moving it to the Trash; use it only when
  the user chooses that over the Trash, knowing there is no way
  back.
- **Profiles and passwords.** Browsers, mail clients and password
  managers keep the user's data in the matched folders. The
  question that was answered has to have named that.

## Move to the Trash

`/usr/bin/trash` first appeared in macOS 15. It moves files of
the current user into their Trash, and `-s` stops at the first
path that fails:

```
export LC_ALL=C
[ -x /usr/bin/trash ] && echo "trash: present" || echo "trash: absent"
```

```
export LC_ALL=C
/usr/bin/trash -s -v \
  "$HOME/Library/Application Support/Example Notes" \
  "$HOME/Library/Preferences/com.example.notes.plist"
```

Where it is absent, move by hand. `mv -n` replaces nothing that
is already in the Trash, and says nothing when it skips, so the
check under After the move decides:

```
export LC_ALL=C
mv -n "$HOME/Library/Application Support/Example Notes" \
  "$HOME/.Trash/Example Notes"
```

Paths come from the scanner's output, quoted, one argument each.
Never build them from a pattern, and never pass a glob.

Never use `rm -r` on a Library entry. The one exception is a
dead symlink, which holds no data: `rm` on the link itself,
after `[ -L "$p" ] && [ ! -e "$p" ]` has shown that it is one.

The Trash is itself behind Full Disk Access
(`rules/os/macos.md` → Privacy Protection (TCC)). Where a move
is refused, over SSH or by the agent's own permission rules,
stop: name the paths that stayed and give the user the command
to run in Terminal on the Mac. Never reach the same effect
another way.

## launchd jobs of the user

A LaunchAgent under `~/Library/LaunchAgents` is unloaded before
its plist moves, and stopping a job is asked about on its own
(`rules/service-reload.md`). Read its state first
(`rules/os/macos.md` → Service Manager):

```
export LC_ALL=C
launchctl print "gui/$(id -u)/com.example.notes.agent" \
  > /dev/null 2>&1 && echo "loaded" || echo "not loaded"
```

```
export LC_ALL=C
launchctl bootout "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/com.example.notes.agent.plist"
```

A job that is not loaded needs no `bootout`; its plist moves like
any other file.

## Entries under `/Library`

They belong to root and serve every user of the Mac. Hostwarden
moves none of them. Each one the user wants gone is handed over
as a command for an administrator to run in Terminal on the Mac,
whole and one entry per block (`rules/infra-code.md` → Commands
the user runs).

`sudo /usr/bin/trash` would fill root's Trash, so the entry goes
into the user's own, with a suffix and `-n`: an entry of the same
name from `~/Library` may already be there, and `mv` replaces a
file without a word.

```bash operator
sudo mv -n "/Library/Application Support/Example Notes" \
  "$HOME/.Trash/Example Notes (System)"
```

A LaunchDaemon is unloaded first, then its plist and its helper
move:

```bash operator
sudo launchctl bootout system \
  /Library/LaunchDaemons/com.example.helper.plist
sudo mv -n /Library/LaunchDaemons/com.example.helper.plist \
  "$HOME/.Trash/com.example.helper (System).plist"
sudo mv -n /Library/PrivilegedHelperTools/com.example.helper \
  "$HOME/.Trash/com.example.helper (System)"
```

An installer receipt is a database entry. Forgetting it removes
no file:

```bash operator
sudo pkgutil --forget com.example.notes.pkg
```

## What stays with the user

- **System extensions and kernel extensions.** macOS removes a
  system extension when its app is deleted in the Finder, and a
  kernel extension or audio driver stays loaded until the next
  restart. Report them; this skill restarts nothing.
- **Configuration profiles and login items.** They are managed
  in System Settings. Name them where an app left one.
- **Emptying the Trash.** Only on its own request (`SKILL.md` →
  Scope and limits).

## After the move

Test every confirmed path again. A dead link fails `-e` while it
is still there, hence the second test; the last line shows that
the check ran (`rules/verify-before-reporting.md`):

```
export LC_ALL=C
for p in \
  "$HOME/Library/Application Support/Example Notes" \
  "$HOME/Library/Preferences/com.example.notes.plist"
do
  if [ -e "$p" ] || [ -L "$p" ]; then echo "STILL $p"; fi
done
echo "paths checked"
```

A path that is still there was not moved. Say which, and why
where the command said so; do not try again with another tool.
