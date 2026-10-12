# tests/hooks/guard-mode/jq.sh — the jq the hooks run: lib/json.sh's
# hook_jq_from_mise and the cache session-mode.sh leaves for it, the
# one place the shared hook library is tested. Sourced by
# tests/hooks/guard-mode.sh, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the jq mise installed -------------------------------------
# A stand-in mise answers bin-paths with a directory of its own, and
# the jq in there is a script that only exits, so what is judged
# does not depend on the workstation's mise or jq. Every case runs
# in a shell whose PATH is built here: sh by its absolute path, the
# helper and nothing else on it.
jt="$TMP/jq-test"
# mkjq <path> — a stand-in jq.
mkjq() {
  mkdir -p "${1%/*}"
  printf '#!/bin/sh\nexit 0\n' > "$1"
  chmod +x "$1"
}
# mkmise <name> <with-jq> — a mise in $jt/<name>-bin that names
# $jt/<name>/installs/jq, which holds a jq when <with-jq> is yes.
mkmise() {
  mkdir -p "$jt/$1-bin" "$jt/$1/installs/jq"
  [ "$2" != yes ] || mkjq "$jt/$1/installs/jq/jq"
  printf '#!/bin/sh\n[ "$1" = bin-paths ] && echo "%s"\n' "$jt/$1/installs/jq" \
    > "$jt/$1-bin/mise"
  chmod +x "$jt/$1-bin/mise"
}
mkmise has yes
mkmise empty no
mkjq "$jt/sys/jq"

# A throwaway checkout root, with the cache a session start leaves.
root="$jt/root"
mkdir -p "$root/.claude"

# jq_case <PATH> <mise data dir> [<shims dir>] — the PATH after the
# helper, what jq resolves to, and whether a mise shim is kept from
# installing.
jq_case() {
  MISE_SHIMS_DIR=${3:-} MISE_DATA_DIR=$2 PATH=$1 /bin/sh -c '. "$1"; hook_jq_from_mise "$2"
    echo "$PATH"; command -v jq || echo none; echo "$MISE_AUTO_INSTALL"' _ \
    "$REPO/lib/json.sh" "$root"
}

# With the cache, mise's jq is in front, whatever else is on the PATH.
echo "$jt/has:$jt/has/installs/jq" > "$root/.claude/mise-jq"
out=$(jq_case "$jt/sys" "$jt/has")
case $out in
"$jt/has/installs/jq:$jt/sys
$jt/has/installs/jq/jq
0") ok ;;
*) bad "hook_jq_from_mise did not put mise's jq first: $out" ;;
esac

# A cache whose jq is gone, one outside mise's data directory and no
# cache leave the PATH alone; shims are still kept from installing.
for c in stale outside none; do
  case $c in
  stale) echo "$jt/empty:$jt/empty/installs/jq" > "$root/.claude/mise-jq" ;;
  outside) echo "$jt/has:$jt/has/installs/jq" > "$root/.claude/mise-jq" ;;
  none) rm -f "$root/.claude/mise-jq" ;;
  esac
  out=$(jq_case "$jt/sys" "$jt/empty")
  case $out in
  "$jt/sys
$jt/sys/jq
0") ok ;;
  *) bad "hook_jq_from_mise changed the PATH with a $c cache: $out" ;;
  esac
done

# Without a usable cache mise's shims are taken off the PATH, so a
# shim that fails with the checkout's pin not installed is never the
# jq a hook runs, and a cache in front of them keeps its place.
mkjq "$jt/data/shims/jq"
rm -f "$root/.claude/mise-jq"
out=$(jq_case "$jt/data/shims:$jt/sys" "$jt/data")
case $out in
"$jt/sys
$jt/sys/jq
0") ok ;;
*) bad "hook_jq_from_mise left mise's shims on the PATH: $out" ;;
esac
# A shims directory MISE_SHIMS_DIR puts elsewhere goes too.
mkjq "$jt/shims-elsewhere/jq"
out=$(jq_case "$jt/shims-elsewhere:$jt/sys" "$jt/data" "$jt/shims-elsewhere")
case $out in
"$jt/sys
$jt/sys/jq
0") ok ;;
*) bad "hook_jq_from_mise left a MISE_SHIMS_DIR on the PATH: $out" ;;
esac
echo "$jt/data:$jt/data/installs/jq" > "$root/.claude/mise-jq"
mkjq "$jt/data/installs/jq/jq"
out=$(jq_case "$jt/data/shims:$jt/sys" "$jt/data")
case $out in
"$jt/data/installs/jq:$jt/data/shims:$jt/sys
$jt/data/installs/jq/jq
0") ok ;;
*) bad "hook_jq_from_mise changed a PATH with a usable cache: $out" ;;
esac

# session-mode.sh leaves the cache: a line with the environment's data
# directory and mise's jq directory. A trailing slash on MISE_DATA_DIR
# is the same environment, written once however often the hook runs.
# Start without the line the parts before it left, where mise has a
# jq installed for real, as in CI.
rm -f "$OPS/.claude/mise-jq"
for d in "$jt/has" "$jt/has/" "$jt/has/"; do
  MISE_DATA_DIR=$d PATH="$jt/has-bin:$PATH" sh "$OPS/.claude/hooks/session-mode.sh" </dev/null >/dev/null
done
if [ "$(cat "$OPS/.claude/mise-jq" 2>/dev/null)" = "$jt/has:$jt/has/installs/jq" ]; then
  ok
else
  bad "session-mode did not leave one line in .claude/mise-jq: $(cat "$OPS/.claude/mise-jq")"
fi
# The reader reads the same environment under either spelling.
echo "$jt/has:$jt/has/installs/jq" > "$root/.claude/mise-jq"
out=$(jq_case "$jt/sys" "$jt/has/")
case $out in
"$jt/has/installs/jq:$jt/sys
$jt/has/installs/jq/jq
0") ok ;;
*) bad "hook_jq_from_mise missed its line with a trailing slash: $out" ;;
esac
# Another environment's line is kept while it still holds a jq and
# dropped when it does not.
mkjq "$jt/other/installs/jq/jq"
printf '%s\n%s\n%s\n' "$jt/old:$jt/old/installs/jq" \
  "$jt/other:$jt/other/installs/jq" "$jt/gone:$jt/gone/installs/jq" \
  > "$OPS/.claude/mise-jq"
MISE_DATA_DIR="$jt/has" PATH="$jt/has-bin:$PATH" sh "$OPS/.claude/hooks/session-mode.sh" </dev/null >/dev/null
if [ "$(cat "$OPS/.claude/mise-jq")" = "$jt/has:$jt/has/installs/jq
$jt/other:$jt/other/installs/jq" ]; then
  ok
else
  bad "session-mode did not keep the other environment's line: $(cat "$OPS/.claude/mise-jq")"
fi
# The reader takes the first line that is its own.
printf '%s\n%s\n' "$jt/other:$jt/other/installs/jq" \
  "$jt/has:$jt/has/installs/jq" > "$root/.claude/mise-jq"
out=$(jq_case "$jt/sys" "$jt/has")
case $out in
"$jt/has/installs/jq:$jt/sys
$jt/has/installs/jq/jq
0") ok ;;
*) bad "hook_jq_from_mise did not find its own line among two: $out" ;;
esac
# It is never removed: a mise with no jq installed yet, as after a
# raised pin, and a session that cannot find mise leave the file.
MISE_DATA_DIR="$jt/has" PATH="$jt/empty-bin:$PATH" sh "$OPS/.claude/hooks/session-mode.sh" </dev/null >/dev/null
if [ "$(head -n 1 "$OPS/.claude/mise-jq" 2>/dev/null)" = "$jt/has:$jt/has/installs/jq" ]; then
  ok
else
  bad "session-mode removed .claude/mise-jq where mise has no jq"
fi

# Every hook that sources json.sh calls it right after, except those
# that never read a tool call through jq: a new hook has to do one or
# the other.
for f in "$HOOKS"/*.sh; do
  h=${f##*/}
  grep -q 'lib/json.sh"' "$f" || continue
  case $h in
  authoring-conventions.sh | check-session.sh | session-mode.sh | wrap-markdown.sh) continue ;;
  esac
  if grep -q '^hook_jq_from_mise ' "$f"; then
    ok
  else
    bad "$h sources json.sh and does not call hook_jq_from_mise"
  fi
done
