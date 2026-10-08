#!/bin/sh
# tests/bin/hostwarden-sync.sh — what `hostwarden-sync commit` does
# when bin/hostwarden-map fails: the user's own files are committed,
# the failure is said on stderr, and the maps are not added on top.
# Local only: a throwaway checkout and workspace, no server.
cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp sync
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

R="$TMP/ops"
mkdir -p "$R/bin" "$R/lib" "$R/memory/maps"
cp "$REPO/bin/hostwarden-sync" "$R/bin/"
cp "$REPO/lib/mode.sh" "$R/lib/"
mkdir "$R/.git"
: >"$R/memory/.hostwarden-workspace"
git init -q "$R/memory"
git -C "$R/memory" config user.name Alice
git -C "$R/memory" config user.email alice@example.com
git -C "$R/memory" config commit.gpgsign false
printf '#!/bin/sh\nexit 0\n' >"$R/bin/hostwarden-wrap"
# A map that redraws part of the maps and then fails, as a write error
# in bin/hostwarden-map ends.
printf '%s\n' '#!/bin/sh' \
  'echo "hostwarden-map: cannot write memory/maps/wan.md" >&2' \
  'echo partial >memory/maps/wan.md' 'exit 1' >"$R/bin/hostwarden-map"

echo note >"$R/memory/note.md"
( cd "$R" && sh bin/hostwarden-sync commit 'Add note' note.md ) \
  >"$TMP/out" 2>"$TMP/err" \
  && ok || bad "commit exited non-zero because hostwarden-map failed"
git -C "$R/memory" ls-files --error-unmatch note.md >/dev/null 2>&1 \
  && ok || bad "the user's own file was not committed"
git -C "$R/memory" ls-files | grep -q '^maps/' \
  && bad "a failed redraw's maps were committed with a named path" || ok
grep -qF 'bin/hostwarden-map failed' "$TMP/err" \
  && ok || bad "the failed redraw was not reported on stderr"
grep -qF 'cannot write memory/maps/wan.md' "$TMP/err" \
  && ok || bad "hostwarden-map's own line did not reach stderr"

# The whole workspace, no path named: the same, and a removal goes in.
echo other >"$R/memory/other.md"
echo secret >"$R/memory/ssh_config"
printf '/ssh_config\n' >"$R/memory/.gitignore"
git -C "$R/memory" rm -q note.md
( cd "$R" && sh bin/hostwarden-sync commit 'Whole workspace' ) \
  >"$TMP/out" 2>"$TMP/err" \
  && ok || bad "a whole-workspace commit exited non-zero"
git -C "$R/memory" ls-files --error-unmatch other.md >/dev/null 2>&1 \
  && ok || bad "a whole-workspace commit left the user's file out"
git -C "$R/memory" ls-files | grep -q '^maps/' \
  && bad "a failed redraw's maps were committed with no path named" || ok
git -C "$R/memory" cat-file -e HEAD:note.md 2>/dev/null \
  && bad "a removed file stayed in a whole-workspace commit" || ok

# A map below maps/ named beside the dot, in any spelling, is kept.
echo again >"$R/memory/third.md"
echo half >"$R/memory/maps/other site.md"
( cd "$R" && sh bin/hostwarden-sync commit 'Named map' ./ memory/maps/wan.md ) \
  >"$TMP/out" 2>"$TMP/err" \
  && ok || bad "a commit naming a map exited non-zero"
git -C "$R/memory" ls-files --error-unmatch maps/wan.md >/dev/null 2>&1 \
  && ok || bad "a named map below maps/ was excluded beside the dot"
git -C "$R/memory" ls-files --error-unmatch 'maps/other site.md' >/dev/null 2>&1 \
  && bad "an unnamed map was committed beside a named one" || ok
git -C "$R/memory" ls-files --error-unmatch third.md >/dev/null 2>&1 \
  && ok || bad "the user's file was left out beside a named map"

finish hostwarden-sync
