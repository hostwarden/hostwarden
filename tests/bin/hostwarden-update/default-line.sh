# tests/bin/hostwarden-update/default-line.sh — the line a checkout
# on main settles on. Sourced by tests/bin/hostwarden-update.sh, in
# the order its PARTS lists, into the one shell every part shares;
# never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the default line -----------------------------------------
# A checkout on main that never chose follows main until a release
# exists, then the newest release's major, from then on.
M0="$TMP/mirror0.git"
git init --quiet --bare --initial-branch=main "$M0"
git -C "$U" push --quiet "$M0" main
git -C "$M0" tag v0.9.0 main
# The helpers above act on $P: from here on, a second checkout.
P="$TMP/prod0"
git clone --quiet "$M0" "$P"
mkdir -p "$P/memory"
touch "$P/memory/.hostwarden-workspace"
[ -z "$(hook)" ] && follows '' \
  && [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ] && ok \
  || bad "a checkout with only a 0.x release left main"
git -C "$U" push --quiet "$M0" v1.2.0 v2.1.0
case "$(update --check)" in
*"next update follows release line 2"*) follows '' && ok \
  || bad "--check chose a line" ;;
*) bad "--check did not name the line the next update takes" ;;
esac
out=$(hook)
at v2.1.0 && follows 2 && ok || bad "the first release set no line: $out"
case "$out" in
*"follows release line 2"*) ok ;;
*) bad "the new line was not reported: $out" ;;
esac
# The line is recorded: a new major does not move it.
git -C "$U" push --quiet "$M0" v2.2.0
git -C "$U" tag -a -m "Release v3.0.0" v3.0.0 main
git -C "$U" push --quiet "$M0" v3.0.0
out=$(hook)
at v2.2.0 && follows 2 && ok || bad "the default line did not hold at 2"
# ...and says, although nothing moved, that the line gets no fixes.
case "$out" in
*"v3.0.0 is out"*"--follow 3"*) ok ;;
*) bad "the hook did not name the newer major: $out" ;;
esac
case "$(update --check)" in
*"Up to date"*"v3.0.0 is out"*) ok ;;
*) bad "--check did not name the newer major" ;;
esac
# Main, once chosen, stays.
update --unpin >/dev/null
hook >/dev/null
follows main && [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ] \
  && ok || bad "a checkout that chose main left it"
