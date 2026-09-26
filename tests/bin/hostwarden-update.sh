#!/bin/sh
# tests/bin/hostwarden-update.sh — dev-only fixture matrix for how a copy of
# Hostwarden gets its releases: bin/hostwarden-mirror,
# bin/hostwarden-update and check-updates.sh, with follow.sh
# between them. CI runs it through scripts/check.sh; an agent
# session leaves it to CI (.claude/rules/pull-requests.md →
# Checks). Not invoked by Claude Code at runtime.
#
# Everything runs against throwaway repositories under a temp
# directory: an upstream, a bare mirror of it, and a production
# clone of the mirror.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp release

export GIT_AUTHOR_NAME=alice GIT_AUTHOR_EMAIL=alice@example.com
export GIT_COMMITTER_NAME=alice GIT_COMMITTER_EMAIL=alice@example.com
unset HOSTWARDEN_NO_UPDATE HEINZEL_NO_UPDATE CLAUDE_PROJECT_DIR \
  HOSTWARDEN_MIRROR_TOKEN

# Upstream: the scripts under test, and one commit per release.
U="$TMP/upstream"
mkdir -p "$U/bin" "$U/lib" "$U/.claude/hooks"
cp "$REPO/bin/hostwarden-update" "$REPO/bin/hostwarden-mirror" "$U/bin/"
cp "$REPO/lib/mode.sh" "$REPO/lib/follow.sh" "$U/lib/"
cp "$REPO/.claude/hooks/check-updates.sh" "$U/.claude/hooks/"
printf 'memory/\n' > "$U/.gitignore"
git -C "$U" init --quiet --initial-branch=main
# A throwaway release key, made for this run only, signs every tag
# upstream; .github/release-signers carries its public half.
ssh-keygen -q -t ed25519 -N '' -C release -f "$TMP/release-key"
mkdir -p "$U/.github"
signers() {
  echo "release@hostwarden namespaces=\"git\" $(cat "$1.pub")" \
    > "$U/.github/release-signers"
}
signers "$TMP/release-key"
git -C "$U" config gpg.format ssh
git -C "$U" config user.signingkey "$TMP/release-key"
git -C "$U" config tag.gpgSign true
# release <version> — commit VERSION and tag it; "-" commits only.
release() {
  echo "$1" > "$U/VERSION"
  printf '# Changelog\n\n## %s\n\n- release %s\n' "$1" "$1" > "$U/CHANGELOG.md"
  git -C "$U" add -A
  git -C "$U" commit --quiet -m "release $1"
  [ "$1" = - ] || git -C "$U" tag -a -m "Release v$1" "v$1"
}
for v in 1.0.0 1.2.0 1.2.1 1.3.0-rc1 1.10.0 2.0.0 -; do release "$v"; done

# --- bin/hostwarden-mirror ------------------------------------
M="$TMP/mirror.git"
git init --quiet --bare --initial-branch=main "$M"
# A plain clone of upstream runs the job, as CI would.
J="$TMP/job"
git clone --quiet "$U" "$J"
mirror() { sh "$J/bin/hostwarden-mirror" --upstream "$U" "$M"; }
same_main() {
  [ "$(git -C "$M" rev-parse main)" = "$(git -C "$U" rev-parse main)" ]
}

mirror >/dev/null && same_main && ok || bad "an empty mirror was not filled"
[ "$(git -C "$M" tag | wc -l | tr -d ' ')" = 6 ] && ok \
  || bad "the mirror did not get every tag"
case "$(mirror)" in
*"already current"*) ok ;;
*) bad "a current mirror was not left alone" ;;
esac
release 1.2.2
mirror >/dev/null && same_main && git -C "$M" rev-parse -q --verify v1.2.2 \
  >/dev/null && ok || bad "a new release did not reach the mirror"

# Commits of the mirror's own stop it, and it pushes nothing.
W="$TMP/mirror-work"
git clone --quiet "$M" "$W"
echo patch > "$W/local.txt"
git -C "$W" add local.txt
git -C "$W" commit --quiet -m "local patch"
git -C "$W" push --quiet origin main
OWN=$(git -C "$M" rev-parse main)
release -
out=$(mirror 2>&1) && bad "a mirror with commits of its own was overwritten"
case "$out" in
*"local patch"*) ok ;;
*) bad "the commit of the mirror's own was not named: $out" ;;
esac
[ "$(git -C "$M" rev-parse main)" = "$OWN" ] && ok \
  || bad "the mirror's main moved although it had commits of its own"
git -C "$M" update-ref refs/heads/main "$(git -C "$U" rev-parse main~1)"

# A tag of the mirror's on another commit stops it too.
git -C "$M" tag -f v1.0.0 "$(git -C "$M" rev-parse main)" >/dev/null
out=$(mirror 2>&1) && bad "a clashing tag in the mirror was overwritten"
case "$out" in
*v1.0.0*) ok ;;
*) bad "the clashing tag was not named: $out" ;;
esac
git -C "$M" tag -f v1.0.0 "$(git -C "$U" rev-parse 'v1.0.0')" >/dev/null
# ...a tag only the mirror has does not.
git -C "$M" tag local-1 main
mirror >/dev/null && same_main && ok || bad "a mirror-only tag stopped the job"

# The token reaches the mirror and nothing else: a git that notes
# which calls carry the askpass.
mkdir -p "$TMP/gitlog"
REALGIT=$(command -v git)
printf '#!/bin/sh\necho "${GIT_ASKPASS:-none} $*" >> "%s"\nexec "%s" "$@"\n' \
  "$TMP/git.log" "$REALGIT" > "$TMP/gitlog/git"
chmod +x "$TMP/gitlog/git"
HOSTWARDEN_MIRROR_TOKEN=t0ken PATH="$TMP/gitlog:$PATH" mirror >/dev/null
if grep " fetch .*$U" "$TMP/git.log" | grep -q askpass; then
  bad "the upstream fetch was offered the mirror's token"
elif grep " push .*$M" "$TMP/git.log" | grep -q askpass; then ok
else bad "the push to the mirror did not get the token"; fi

# No credential reaches the log. The @ is added at run time, so
# the secret scan does not take the fixture for a real one.
AT=@
out=$(sh "$J/bin/hostwarden-mirror" --upstream "$U" \
  "https://alice:s3cret${AT}git.invalid/ops/hostwarden-mirror.git" 2>&1) \
  && bad "an unreachable mirror succeeded"
case "$out" in
*s3cret*) bad "the mirror job printed a credential" ;;
*"cannot reach the mirror"*) ok ;;
*) bad "an unreachable mirror was not reported: $out" ;;
esac

# --- bin/hostwarden-update --follow ---------------------------
# Production: an operations install cloned from the mirror.
P="$TMP/prod"
git clone --quiet "$M" "$P"
mkdir -p "$P/memory"
touch "$P/memory/.hostwarden-workspace"
update() { sh "$P/bin/hostwarden-update" "$@" 2>&1; }
hook() { CLAUDE_PROJECT_DIR=$P sh "$P/.claude/hooks/check-updates.sh"; }
at() { [ "$(git -C "$P" describe --tags --exact-match 2>/dev/null)" = "$1" ]; }
follows() { [ "$(git -C "$P" config --get hostwarden.follow)" = "$1" ]; }

# The mirror job refuses an operations install.
out=$(sh "$P/bin/hostwarden-mirror" --upstream "$U" "$M" 2>&1) \
  && bad "the mirror job ran from an operations install"
case "$out" in *"operations install"*) ok ;; *) bad "no reason: $out" ;; esac

update --follow 1.2 >/dev/null && at v1.2.2 && follows 1.2 && ok \
  || bad "--follow 1.2 is not at v1.2.2"
# Versions sort as versions, and a pre-release is no release.
update --follow 1 >/dev/null && at v1.10.0 && follows 1 && ok \
  || bad "--follow 1 is not at v1.10.0"
update --follow 1.1 >/dev/null && bad "--follow 1.1 found a release"
at v1.10.0 && follows 1 && ok || bad "a failed --follow changed the checkout"
for l in x 1.2.3 1. .1 ''; do
  update --follow "$l" >/dev/null && bad "--follow '$l' was accepted"
done
follows 1 && ok || bad "an invalid line changed the setting"
case "$(update --check)" in
*"Following 1"*"Up to date"*) ok ;;
*) bad "--check does not report the line" ;;
esac

# The session-start hook moves along the line, and only along it.
update --follow 1.2 >/dev/null
release 1.2.3
release 2.1.0
mirror >/dev/null
out=$(hook)
at v1.2.3 && ok || bad "the hook did not move to v1.2.3"
case "$out" in
*"1.2.2 -> 1.2.3"*"release 1.2.3"*) ok ;;
*) bad "the hook did not report the update: $out" ;;
esac
# With nothing to do it says only that a newer release is out.
case "$(hook)" in
"hostwarden: v2.1.0 is out"*) ok ;;
*) bad "the hook said more than the newer major with nothing to do" ;;
esac
update >/dev/null && at v1.2.3 && ok || bad "plain update left the line"
# The line is recorded once the checkout is on it, even when the
# migration after it fails.
printf '#!/bin/sh\nexit 1\n' > "$P/bin/hostwarden-migrate"
update --follow 1 >/dev/null && bad "a failing migration went unnoticed"
at v1.10.0 && follows 1 && ok || bad "a failed migration lost the new line"
rm "$P/bin/hostwarden-migrate"

# A pin replaces the line; unpin returns to main.
update --pin v1.0.0 >/dev/null && at v1.0.0 && follows '' && ok \
  || bad "--pin did not replace the line"
case "$(hook)" in
*"pinned to v1.0.0"*) at v1.0.0 && ok || bad "the hook moved a pin" ;;
*) bad "the hook did not report the pin" ;;
esac
# A line in the user's global config is not this checkout's.
mkdir -p "$TMP/home"
out=$(HOME="$TMP/home"; git config --global hostwarden.follow 1; hook)
case "$out" in
*"pinned to v1.0.0"*) at v1.0.0 && ok || bad "a global line moved a pin" ;;
*) bad "the hook followed a line from the global config" ;;
esac

# A line with no release yet is reported, and nothing moves.
git -C "$P" config hostwarden.follow 9
case "$(hook)" in
*"auto-update failed"*"no release v9.x"*) at v1.0.0 && ok || bad "moved" ;;
*) bad "the hook did not report a line without a release" ;;
esac
update --follow 2 >/dev/null
# An unpin that cannot leave the tag keeps the line.
echo local > "$P/VERSION"
update --unpin >/dev/null && bad "--unpin succeeded over a local change"
follows 2 && ok || bad "a failed --unpin dropped the line"
git -C "$P" checkout --quiet -- VERSION
update --unpin >/dev/null && follows main \
  && [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ] \
  && [ "$(git -C "$P" rev-parse HEAD)" = "$(git -C "$M" rev-parse main)" ] \
  && ok || bad "--unpin did not record main and return to it"

# Main by choice: the hook pulls it.
release 2.2.0
mirror >/dev/null
out=$(hook)
[ "$(git -C "$P" rev-parse HEAD)" = "$(git -C "$U" rev-parse main)" ] && ok \
  || bad "the hook did not pull main"
case "$out" in
*"2.1.0 -> 2.2.0"*"release 2.2.0"*) ok ;;
*) bad "the hook did not report the pull: $out" ;;
esac
[ -z "$(hook)" ] && ok || bad "the hook spoke on main with nothing to do"
# A changelog fragment that arrives on main is named by its lead
# clause, wrapped or not.
mkdir -p "$U/changelog.d"
printf '### Fixed\n\n- **A lead clause that\n  wraps.** Detail.\n' \
  > "$U/changelog.d/fix-x.md"
git -C "$U" add -A
git -C "$U" commit --quiet -m "fix x"
mirror >/dev/null
out=$(hook)
case "$out" in
*"not released yet"*"Fixed: A lead clause that wraps."*) ok ;;
*) bad "the hook did not name the new fragment: $out" ;;
esac
# An edited entry is named as changed, a renamed file not at all, a
# deleted one as no longer listed; `## Unreleased` counts as well.
printf '### Fixed\n\n- **A lead clause that\n  wraps.** More detail.\n' \
  > "$U/changelog.d/fix-x.md"
printf '# Changelog\n\n## Unreleased\n\n### Safety\n\n- **Kept.** k.\n' \
  > "$U/CHANGELOG.md"
git -C "$U" add -A
git -C "$U" commit --quiet -m "edit x"
mirror >/dev/null
out=$(hook)
case "$out" in
*"Fixed: A lead clause that wraps. (changed)"*) ok ;;
*) bad "the hook did not name the changed fragment: $out" ;;
esac
case "$out" in
*"Safety: Kept."*) ok ;;
*) bad "the hook did not name the entry under ## Unreleased: $out" ;;
esac
git -C "$U" mv changelog.d/fix-x.md changelog.d/fix-y.md
git -C "$U" commit --quiet -m "rename x"
mirror >/dev/null
case "$(hook)" in
*"not released yet"*) bad "a renamed fragment was news" ;;
*) ok ;;
esac
git -C "$U" rm --quiet changelog.d/fix-y.md
git -C "$U" commit --quiet -m "withdraw x"
mirror >/dev/null
case "$(hook)" in
*"no longer listed: A lead clause that wraps."*) ok ;;
*) bad "the hook did not name the withdrawn entry" ;;
esac
# A diverged main fails loudly and stays as it was.
echo local > "$P/local.txt"
git -C "$P" add local.txt
git -C "$P" commit --quiet -m "local"
release -
mirror >/dev/null
case "$(hook)" in
*"auto-update failed"*) ok ;;
*) bad "a diverged main was not reported" ;;
esac

# The rest lives in tests/bin/hostwarden-update/, one file per stage,
# sourced in this order into this shell: each reads what the ones
# before it set.
PARTS='default-line signatures'
for part in $PARTS; do
  [ -f "$REPO/tests/bin/hostwarden-update/$part.sh" ] || {
    echo "hostwarden-update.sh: tests/bin/hostwarden-update/$part.sh" \
      "is missing" >&2
    exit 1
  }
done
for part in $PARTS; do
  # shellcheck source=/dev/null
  . "$REPO/tests/bin/hostwarden-update/$part.sh"
done

finish release
