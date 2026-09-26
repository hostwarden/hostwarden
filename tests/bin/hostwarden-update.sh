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

# --- signatures -----------------------------------------------
# Before a checkout of a tag, an operations checkout verifies it
# against the release key of the commit it is on. One that does
# not verify is refused, and the checkout stays where it is.
update --follow 2 >/dev/null && at v2.2.0 && ok || bad "--follow 2 missed v2.2.0"
# publish <tag> — to the mirror; unpublish takes it back everywhere.
publish() { git -C "$U" push --quiet "$M0" "$1"; }
unpublish() {
  for r in "$U" "$M0" "$P"; do git -C "$r" tag -d "$1" >/dev/null; done
}
refused() {
  out=$(update "$@") && bad "a tag that does not verify was taken: $out"
  at v2.2.0 && follows 2 && ok || bad "a refused tag moved the checkout"
  case "$out" in
  *"update refused: v2.3.0"*) ok ;;
  *) bad "the refusal did not name the tag: $out" ;;
  esac
}

# change <message> — a commit upstream for the next tag to sit on,
# since a tag on the commit checked out moves nothing.
change() { git -C "$U" commit --quiet --allow-empty -m "$1"; }

# Unsigned.
change unsigned
git -C "$U" -c tag.gpgSign=false tag -a -m "Release v2.3.0" v2.3.0 main
publish v2.3.0
refused
case "$(hook)" in
*"auto-update failed"*"refused: v2.3.0"*) at v2.2.0 && ok || bad "moved" ;;
*) bad "the hook did not report the refused tag" ;;
esac
case "$(update --check)" in
*"v2.3.0 is out, and an update refuses it"*) ok ;;
*) bad "--check did not report the tag that does not verify" ;;
esac
unpublish v2.3.0

# Signed by another key that the tag's own tree lists: the key
# comes from the checkout, never from the tag being checked.
ssh-keygen -q -t ed25519 -N '' -C other -f "$TMP/other-key"
signers "$TMP/other-key"
git -C "$U" add -A
git -C "$U" commit --quiet -m "another key"
git -C "$U" -c user.signingkey="$TMP/other-key" \
  tag -a -m "Release v2.3.0" v2.3.0 main
publish v2.3.0
refused
unpublish v2.3.0

# A signed tag of another release, under a new name.
git -C "$M0" update-ref refs/tags/v2.3.0 "$(git -C "$U" rev-parse v2.1.0)"
refused
refused --pin v2.3.0
git -C "$M0" tag -d v2.3.0 >/dev/null
git -C "$P" tag -d v2.3.0 >/dev/null

# Signed with the release key: taken.
signers "$TMP/release-key"
git -C "$U" add -A
git -C "$U" commit --quiet -m "the release key again"
git -C "$U" tag -a -m "Release v2.3.0" v2.3.0 main
publish v2.3.0
update >/dev/null && at v2.3.0 && ok || bad "a verified tag was refused"

# A development checkout is not verified.
D="$TMP/dev"
git clone --quiet "$M0" "$D"
change development
git -C "$U" -c tag.gpgSign=false tag -a -m "Release v2.4.0" v2.4.0 main
publish v2.4.0
sh "$D/bin/hostwarden-update" --pin v2.4.0 >/dev/null 2>&1 &&
  [ "$(git -C "$D" describe --tags --exact-match)" = v2.4.0 ] && ok \
  || bad "a development checkout verified a tag"

# A new key reaches the checkout through a release the old key
# signed, whose tree lists both, although the update skips it; the
# unsigned v2.4.0 on the way hands nothing on.
ssh-keygen -q -t ed25519 -N '' -C next -f "$TMP/next-key"
signers "$TMP/release-key"
echo "release@hostwarden namespaces=\"git\" $(cat "$TMP/next-key.pub")" \
  >> "$U/.github/release-signers"
git -C "$U" add -A
git -C "$U" commit --quiet -m "the next key"
git -C "$U" tag -a -m "Release v2.5.0" v2.5.0 main
signers "$TMP/next-key"
git -C "$U" add -A
git -C "$U" commit --quiet -m "the old key retired"
git -C "$U" -c user.signingkey="$TMP/next-key" \
  tag -a -m "Release v2.6.0" v2.6.0 main
publish v2.5.0
publish v2.6.0
update >/dev/null && at v2.6.0 && ok \
  || bad "a key a verified release lists was not trusted"

# The program git verifies with decides, not the ssh on PATH: one
# that skips a valid-after line, as ssh-keygen before 8.7 does, is
# refused, although the tag, whose key is listed without one, would
# verify with it.
cat > "$TMP/keygen-8.6" <<'EOF'
#!/bin/sh
f=
for a; do
  [ "$f" = -f ] && grep -q valid-after "$a" 2>/dev/null && exit 255
  f=$a
done
exec ssh-keygen "$@"
EOF
chmod +x "$TMP/keygen-8.6"
git -C "$P" config gpg.ssh.program "$TMP/keygen-8.6"
change "an old ssh-keygen"
git -C "$U" -c user.signingkey="$TMP/next-key" \
  tag -a -m "Release v2.7.0" v2.7.0 main
publish v2.7.0
out=$(update) && bad "an ssh-keygen before 8.7 verified: $out"
at v2.6.0 && ok || bad "an ssh-keygen before 8.7 moved the checkout"
case "$out" in
*"cannot verify"*"$TMP/keygen-8.6"*) ok ;;
*) bad "the refusal did not name the program: $out" ;;
esac
git -C "$P" config --unset gpg.ssh.program
update >/dev/null && at v2.7.0 && ok \
  || bad "the default ssh-keygen did not verify v2.7.0"

# A checkout on main that settles on its first line and meets a tag
# that does not verify leaves main where it was.
P="$TMP/prod1"
git clone --quiet "$M0" "$P"
mkdir -p "$P/memory"
touch "$P/memory/.hostwarden-workspace"
BEFORE=$(git -C "$P" rev-parse HEAD)
change "main moves"
git -C "$U" push --quiet "$M0" main
git -C "$U" -c tag.gpgSign=false tag -a -m "Release v4.0.0" v4.0.0 main
publish v4.0.0
out=$(update) && bad "a settle onto a tag that does not verify passed"
[ "$(git -C "$P" rev-parse HEAD)" = "$BEFORE" ] && follows '' \
  && [ "$(git -C "$P" symbolic-ref --short HEAD)" = main ] && ok \
  || bad "a refused settle moved main: $out"
case "$(update --check)" in
*"next update follows release line 4"*"It refuses v4.0.0"*) ok ;;
*) bad "--check did not report the settle tag that does not verify" ;;
esac
# A newer major that does not verify is named, never recommended.
P="$TMP/prod0"
case "$(hook)" in
*"v4.0.0 is out"*"An update refuses it"*)
  case "$(hook)" in *"--follow 4"*) bad "a refused major was recommended" ;;
  *) ok ;; esac ;;
*) bad "the hook did not name the refused major" ;;
esac

finish release
