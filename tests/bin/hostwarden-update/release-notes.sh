# tests/bin/hostwarden-update/release-notes.sh — what an update says
# it brought: every release in between, by lead clause. Sourced by
# tests/bin/hostwarden-update.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- release notes --------------------------------------------
# notes_release <version> <CHANGELOG.md> — commit and tag a release
# whose CHANGELOG.md is the text given.
notes_release() {
  echo "$1" > "$U/VERSION"
  printf '%s' "$2" > "$U/CHANGELOG.md"
  git -C "$U" add -A
  git -C "$U" commit --quiet -m "release $1"
  git -C "$U" tag -a -m "Release v$1" "v$1"
}
M3="$TMP/m3.git"
git init --quiet --bare --initial-branch=main "$M3"
git -C "$U" push --quiet "$M3" main v5.0.0
P="$TMP/prod3"
git clone --quiet "$M3" "$P" && mkdir "$P/memory"
touch "$P/memory/.hostwarden-workspace"
update --follow 5 >/dev/null && at v5.0.0 && ok \
  || bad "--follow 5 is not at v5.0.0"

# 5.1.0 keeps every release in its CHANGELOG.md, 5.2.0 only its own,
# 5.3.0 has no section for itself.
notes_release 5.1.0 '# Changelog

## 5.1.0 - 2026-10-01

Some prose above the entries.

### Added

- **Five one, a lead clause that
  wraps.** Detail five-one.
- Plain entry without a lead.

## 5.0.0

### Added

- **release 5.0.0.** Detail.
'
notes_release 5.2.0 '# Changelog

## 5.2.0

### Fixed

- **Five two.** Detail five-two.
'
notes_release 5.3.0 '# Changelog

## 5.2.9
'
git -C "$U" push --quiet "$M3" main v5.1.0 v5.2.0 v5.3.0
out=$(hook)
at v5.3.0 && ok || bad "the hook did not move to v5.3.0: $out"
case "$out" in
*"5.0.0 -> 5.3.0"*"5.3.0:"*"has no notes"*"5.2.0:"*"Fixed: Five two."*"5.1.0:"*)
  ok ;;
*) bad "the releases in between were not listed newest first: $out" ;;
esac
case "$out" in
*"Added: Five one, a lead clause that wraps."*"Added: Plain entry"*) ok ;;
*) bad "a lead clause, wrapped or plain, is missing: $out" ;;
esac
case "$out" in
*Detail* | *prose* | *"5.0.0:"* | *"5.2.9"*) bad "more than the leads: $out" ;;
*) ok ;;
esac
case "$out" in
*"git show vX.Y.Z:CHANGELOG.md"*) ok ;;
*) bad "the full text was not pointed at: $out" ;;
esac

# On main, a VERSION ahead of its tag reads its notes from HEAD,
# before the tagged releases in between.
update --unpin >/dev/null && follows main && ok || bad "--unpin failed"
notes_release 5.3.5 '# Changelog

## 5.3.5

### Fixed

- **Five three five.** d.
'
echo 5.4.0 > "$U/VERSION"
printf '# Changelog\n\n## 5.4.0\n\n### Changed\n\n- **Untagged.** d.\n' \
  > "$U/CHANGELOG.md"
git -C "$U" commit --quiet -am "release 5.4.0, not tagged yet"
git -C "$U" push --quiet "$M3" main v5.3.5
case "$(hook)" in
*"5.3.0 -> 5.4.0"*"5.4.0:"*"Changed: Untagged."*"5.3.5:"*) ok ;;
*) bad "an untagged VERSION on main had no notes" ;;
esac
