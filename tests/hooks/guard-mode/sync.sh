# tests/hooks/guard-mode/sync.sh — bin/hostwarden-sync. Sourced by
# tests/hooks/guard-mode.sh, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- bin/hostwarden-sync ---------------------------------------
sync_a() { sh "$OPS/bin/hostwarden-sync" "$@"; }
# Outside operations, every verb does nothing.
sh "$DEV/bin/hostwarden-sync" commit x && [ ! -e "$DEV/memory" ] && ok \
  || bad "sync acted in a development checkout"
# Without a remote, pull and push do nothing and succeed.
sync_a pull && sync_a push \
  && ok || bad "sync without a remote failed"

# Two machines on one private remote. Commits need an identity;
# a real one comes from the user's git config.
export GIT_AUTHOR_NAME=alice GIT_AUTHOR_EMAIL=alice@example.com
export GIT_COMMITTER_NAME=alice GIT_COMMITTER_EMAIL=alice@example.com
# With a remote, the workspace refuses a commit betterleaks has
# not scanned. Where it is missing, prove that; then stand in a
# stub that finds nothing, so the sync tests below can commit.
git init --quiet --bare --initial-branch=main "$TMP/remote.git"
if ! command -v betterleaks >/dev/null 2>&1; then
  git -C "$OPS/memory" remote add probe "$TMP/remote.git"
  echo x > "$OPS/memory/network.md"
  fails "a workspace with a remote committed without a secret scan" sync_a commit probe
  # ...and never pushes unscanned either.
  fails "a workspace pushed without a secret scan" git -C "$OPS/memory" push --quiet probe HEAD:main
  git -C "$OPS/memory" remote remove probe
  git -C "$OPS/memory" reset --quiet
fi
mkdir -p "$TMP/stub"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stub/betterleaks"
chmod +x "$TMP/stub/betterleaks"
PATH="$TMP/stub:$PATH"
sync_a commit "start the workspace" \
  && ok || bad "sync commit failed"
git -C "$OPS/memory" remote add origin "$TMP/remote.git"
git -C "$OPS/memory" push --quiet -u origin main
B=$(checkout b)
sh "$B/bin/hostwarden-init" --clone "$TMP/remote.git" >/dev/null
mode_is operations "$B"
sync_b() { sh "$B/bin/hostwarden-sync" "$@"; }
# A GIT_SSH_COMMAND the user set gets the no-prompt options too.
got=$(GIT_SSH_COMMAND='ssh -i /tmp/k' HOME="$TMP" sh -c \
  '. "$1"; hostwarden_git_batch; echo "$GIT_SSH_COMMAND"' _ "$REPO/lib/mode.sh")
case "$got" in
"ssh -i /tmp/k -o BatchMode=yes"*ServerAliveInterval=15*) ok ;;
*) bad "an inherited GIT_SSH_COMMAND lost the required options: $got" ;;
esac
# A clone refused for its hooks path is taken back: the marker it
# brought must not make an operations checkout without the scan.
G=$(checkout global-hooks)
if GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
    GIT_CONFIG_VALUE_0=/tmp/elsewhere \
    sh "$G/bin/hostwarden-init" --clone "$TMP/remote.git" >/dev/null 2>&1; then
  bad "init --clone ran with core.hooksPath pointing elsewhere"
else ok; fi
mode_is development "$G"
[ ! -e "$G/memory" ] && [ ! -e "$G/memory.clone" ] && ok \
  || bad "a refused clone was left behind"
# A clone without symlink support says so.
C=$(checkout c)
out=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.symlinks \
  GIT_CONFIG_VALUE_0=false sh "$C/bin/hostwarden-init" --clone "$TMP/remote.git")
case "$out" in
*"made no symlinks"*) ok ;;
*) bad "a clone without symlinks went unmentioned" ;;
esac
LOG=machines/server1.example.com/changelog.log

# Both machines add to the same changelog; union merge keeps both.
printf '[2026-09-21 10:00] from a\n' > "$OPS/memory/$LOG"
sync_a commit "a: changelog"
sync_a push
mkdir -p "$B/memory/machines/server1.example.com"
printf '[2026-09-21 10:05] from b\n' > "$B/memory/$LOG"
sync_b commit "b: changelog"
out=$(sync_b pull)
if [ -z "$out" ] && grep -q 'from a' "$B/memory/$LOG" \
    && grep -q 'from b' "$B/memory/$LOG"; then ok
else bad "pull did not keep both changelog entries: $out"; fi
sync_b push
sync_a pull
grep -q 'from b' "$OPS/memory/$LOG" && ok \
  || bad "a second machine's push did not arrive"

# Uncommitted edits belong to another session, or to one that
# ended before committing: pull leaves them and the workspace
# alone, says so, and stashes nothing.
MEM=machines/server1.example.com/memory.md
echo 'Kernel: 6.0' > "$OPS/memory/$MEM"
sync_a commit "a: base"
sync_a push
sync_b pull
echo 'Kernel: 6.1' > "$OPS/memory/$MEM"
sync_a commit "a: kernel"
sync_a push
echo 'Kernel: 5.10' > "$B/memory/$MEM"
case "$(sync_b pull)" in
*"was not brought up to date"*) ok ;;
*) bad "pull ran over uncommitted changes" ;;
esac
grep -q 'Kernel: 5.10' "$B/memory/$MEM" \
  && [ -z "$(git -C "$B/memory" stash list)" ] && ok \
  || bad "pull touched uncommitted changes or stashed them"
git -C "$B/memory" checkout --quiet -- "$MEM"
sync_b pull
# An uncommitted file the remote did not touch does not stop a
# fast-forward past it.
echo 'Kernel: 6.2' > "$OPS/memory/$MEM"
sync_a commit "a: kernel 6.2" "$MEM"
sync_a push
mkdir -p "$B/memory/machines/server3.example.com"
echo 'OS: Alpine' > "$B/memory/machines/server3.example.com/memory.md"
out=$(sync_b pull)
if [ -z "$out" ] && grep -q 'Kernel: 6.2' "$B/memory/$MEM" \
    && [ -e "$B/memory/machines/server3.example.com/memory.md" ]; then ok
else bad "pull did not fast-forward past an untouched uncommitted file: $out"; fi
rm -rf "$B/memory/machines/server3.example.com"

# commit with paths takes only those files — a new one included —
# and leaves another session's changes where they are.
N=machines/server2.example.com/memory.md
mkdir -p "$B/memory/machines/server2.example.com"
echo 'OS: FreeBSD 14' > "$B/memory/$N"
echo 'Kernel: another session' > "$B/memory/$MEM"
sync_b commit "b: server2" "memory/$N"
git -C "$B/memory" log -1 --name-only --format= | grep -qx "$N" \
  && [ -n "$(git -C "$B/memory" status --porcelain -- "$MEM")" ] && ok \
  || bad "commit with a path took more than that path, or missed it"
git -C "$B/memory" checkout --quiet -- "$MEM"
# Another session's git holding the index is waited out.
echo 'OS: FreeBSD 14.1' > "$B/memory/$N"
: > "$B/memory/.git/index.lock"
( sleep 1; rm -f "$B/memory/.git/index.lock" ) &
sync_b commit "b: server2 again" "$N" \
  && git -C "$B/memory" log -1 --format=%s | grep -qx 'b: server2 again' \
  && ok || bad "commit gave up on a held index.lock"
wait
sync_b push
sync_a pull

# A real disagreement is aborted, reported and left alone.
echo 'OS: Debian 13' > "$OPS/memory/machines/server1.example.com/memory.md"
sync_a commit "a: os"
sync_a push
echo 'OS: Debian 12' > "$B/memory/machines/server1.example.com/memory.md"
sync_b commit "b: os"
out=$(sync_b pull)
case "$out" in
*"could not be brought up to"*) ok ;;
*) bad "a conflicting pull was not reported: $out" ;;
esac
grep -q 'Debian 12' "$B/memory/machines/server1.example.com/memory.md" \
  && [ ! -d "$B/memory/.git/rebase-merge" ] && ok \
  || bad "a conflicting pull did not leave the workspace as it was"

# A rebase the user is resolving by hand is theirs: sync touches
# nothing, not even with a remote to pull from.
git -C "$B/memory" pull --quiet --rebase >/dev/null 2>&1
[ -d "$B/memory/.git/rebase-merge" ] || bad "fixture: no rebase in progress"
out=$(sync_b pull; sync_b commit "b: mid-rebase")
case "$out" in
*"middle of a rebase"*) ok ;;
*) bad "sync did not refuse during a rebase: $out" ;;
esac
[ -d "$B/memory/.git/rebase-merge" ] && ok \
  || bad "sync aborted a rebase the user was resolving"
