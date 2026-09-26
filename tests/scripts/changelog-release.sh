#!/bin/sh
# tests/scripts/changelog-release.sh — dev-only fixture matrix for
# scripts/changelog-release.sh, which checks the changelog
# fragments and folds them into CHANGELOG.md at a release. CI runs
# it through scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Everything runs in a throwaway repository under a temp directory.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp changelog

export GIT_AUTHOR_NAME=alice GIT_AUTHOR_EMAIL=alice@example.com
export GIT_COMMITTER_NAME=alice GIT_COMMITTER_EMAIL=alice@example.com

C="$TMP/changelog"
mkdir -p "$C/scripts" "$C/changelog.d"
cp "$REPO/scripts/changelog-release.sh" "$C/scripts/"
git -C "$C" init --quiet
fold() { sh "$C/scripts/changelog-release.sh" "$@" 2>&1; }
echo 1.1.0 > "$C/VERSION"
printf '# Changelog\n\n## 1.0.0 - 2026-01-01\n\n- old\n' > "$C/CHANGELOG.md"
printf '### Fixed\n\n- **Fix one.** Detail\n  wrapped.\n' \
  > "$C/changelog.d/a.md"
printf '%s\n' '### Added' '' '- **New.** Detail.' '' '### Fixed' '' \
  '- **Fix two.** More.' > "$C/changelog.d/b.md"
git -C "$C" add -A
git -C "$C" commit --quiet -m init
fold --check >/dev/null && ok || bad "well-formed fragments failed --check"
fold >/dev/null && ok || bad "the fold failed"
want=$(printf '%s\n' '# Changelog' '' "## 1.1.0 - $(date -u +%Y-%m-%d)" '' \
  '### Added' '' '- **New.** Detail.' '' '### Fixed' '' \
  '- **Fix one.** Detail' '  wrapped.' '- **Fix two.** More.' '' \
  '## 1.0.0 - 2026-01-01' '' '- old')
[ "$(cat "$C/CHANGELOG.md")" = "$want" ] && ok \
  || bad "the fold wrote: $(cat "$C/CHANGELOG.md")"
[ -z "$(ls "$C/changelog.d" 2>/dev/null)" ] \
  && [ "$(git -C "$C" diff --cached --name-only --diff-filter=D | wc -l \
    | tr -d ' ')" = 2 ] && ok || bad "the fold did not delete the fragments"
fold >/dev/null && bad "a second fold of the same VERSION ran"
# The fold leaves no changelog.d/, and --check takes that as fine.
rm -rf "$C/changelog.d"
fold --check >/dev/null && ok || bad "--check failed without changelog.d/"
# ## Unreleased becomes the section, and the entries end it.
echo 1.2.0 > "$C/VERSION"
printf '# Changelog\n\n## Unreleased\n\n- kept\n\n## 1.1.0\n' \
  > "$C/CHANGELOG.md"
mkdir -p "$C/changelog.d"
printf '### Security\n\n- **Safe.** Now.\n' > "$C/changelog.d/c.md"
fold >/dev/null
want=$(printf '%s\n' '# Changelog' '' "## 1.2.0 - $(date -u +%Y-%m-%d)" '' \
  '- kept' '' '### Security' '' '- **Safe.** Now.' '' '## 1.1.0')
[ "$(cat "$C/CHANGELOG.md")" = "$want" ] && ok \
  || bad "the fold of ## Unreleased wrote: $(cat "$C/CHANGELOG.md")"
# A malformed fragment stops it, and nothing changes.
echo 1.3.0 > "$C/VERSION"
cp "$C/CHANGELOG.md" "$TMP/before.md"
mkdir -p "$C/changelog.d"
for f in '### Fixd\n\n- **x.** y\n' 'text\n' '### Fixed\n\n' \
    '### Fixed\n\n- no lead\n' '### Fixed\n\n- **x.** y\nunindented\n' \
    '### Fixed\n\n- **x never\n  closes\n' \
    '### Fixed\n\n- **x.** y\n  ```\n  ls\n  ```\n'; do
  # shellcheck disable=SC2059 # the fixture is the format
  printf "$f" > "$C/changelog.d/bad.md"
  fold --check >/dev/null && bad "--check passed: $f"
  fold >/dev/null && bad "the fold ran over: $f"
  cmp -s "$C/CHANGELOG.md" "$TMP/before.md" && ok \
    || bad "a refused fold changed CHANGELOG.md: $f"
done
: > "$C/changelog.d/bad.md"
fold --check >/dev/null && bad "--check passed an empty fragment"

# Stray files are named: a subdirectory, another extension.
rm -f "$C/changelog.d/bad.md"
mkdir -p "$C/changelog.d/feat"
echo x > "$C/changelog.d/feat/x.md"
echo x > "$C/changelog.d/y.markdown"
out=$(fold --check)
case "$out" in
*feat/x.md*y.markdown* | *y.markdown*feat/x.md*) ok ;;
*) bad "--check did not name the stray files: $out" ;;
esac
rm -rf "$C/changelog.d/feat" "$C/changelog.d/y.markdown"

# A release waiting in review: what its rebase brings, committed
# before its bump, fails --check until the fold runs again, which
# adds it to the section written. A fragment committed after the
# bump, a pull request queued behind the release, ships after it.
echo 1.2.0 > "$C/VERSION"
git -C "$C" add -A
git -C "$C" commit --quiet -m state
git -C "$C" tag v1.2.0
printf '### Fixed\n\n- **One.** a.\n' > "$C/changelog.d/d.md"
git -C "$C" add -A
git -C "$C" commit --quiet -m "d"
BASE=$(git -C "$C" rev-parse HEAD)
echo 1.3.0 > "$C/VERSION"
fold >/dev/null
git -C "$C" add -A
git -C "$C" commit --quiet -m "release 1.3.0"
RELEASE=$(git -C "$C" rev-parse HEAD)
# e.md merges meanwhile, and the release is rebased onto it.
git -C "$C" checkout --quiet --detach "$BASE"
printf '### Added\n\n- **Late.** b.\n' > "$C/changelog.d/e.md"
git -C "$C" add -A
git -C "$C" commit --quiet -m "e"
git -C "$C" cherry-pick "$RELEASE" >/dev/null
printf '### Fixed\n\n- **Queued.** c.\n' > "$C/changelog.d/g.md"
git -C "$C" add -A
git -C "$C" commit --quiet -m "queued behind"
out=$(fold --check) && bad "--check passed a fragment left out of 1.3.0"
case "$out" in
*"e.md: older than the bump"*) ok ;;
*) bad "--check did not name the fragment left out: $out" ;;
esac
case "$out" in *g.md*) bad "--check named the queued fragment: $out" ;; esac
git -C "$C" rm --quiet changelog.d/g.md
git -C "$C" commit --quiet -m "not the release's"
fold >/dev/null && ok || bad "the second fold of 1.3.0 failed"
[ "$(grep -c '^## 1\.3\.0' "$C/CHANGELOG.md")" = 1 ] \
  && [ "$(awk '/^## 1\.3\.0/ { s = 1; next } /^## / { s = 0 }
    s && /Late/ { print "in" }' "$C/CHANGELOG.md")" = in ] && ok \
  || bad "the second fold did not add to the 1.3.0 section"
# Once the release is tagged, the section is history.
git -C "$C" tag v1.3.0
printf '### Fixed\n\n- **After.** c.\n' > "$C/changelog.d/f.md"
fold --check >/dev/null && ok || bad "--check failed after the tag"
fold >/dev/null && bad "a fold wrote into a tagged release"

finish changelog
