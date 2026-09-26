# tests/bin/hostwarden-update/signatures.sh — verified tags, key
# rotation, no step back, and a lower major. Sourced by
# tests/bin/hostwarden-update.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

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

# Signed with the release key: taken. Its VERSION names it, as a
# release's does, for the step back below to compare with.
signers "$TMP/release-key"
echo 2.3.0 > "$U/VERSION"
git -C "$U" add -A
git -C "$U" commit --quiet -m "the release key again"
git -C "$U" tag -a -m "Release v2.3.0" v2.3.0 main
publish v2.3.0
update >/dev/null && at v2.3.0 && ok || bad "a verified tag was refused"

# No step back: a mirror that withholds v2.3.0 offers v2.2.0 as the
# newest on the line, signed and verifying, and the line stays.
V23=$(git -C "$P" rev-parse HEAD)
unpublish v2.3.0
out=$(update) && bad "the line stepped back to v2.2.0: $out"
case "$out" in
*"update refused: v2.2.0"*"older than 2.3.0"*"--pin v2.2.0"*)
  [ "$(git -C "$P" rev-parse HEAD)" = "$V23" ] && follows 2 && ok \
    || bad "a refused step back moved" ;;
*) bad "the step back was not refused: $out" ;;
esac
case "$(update --check)" in
*"v2.2.0 is out, and an update refuses it"*) ok ;;
*) bad "--check offered the step back" ;;
esac
# A pin goes back on purpose; the line then moves up again.
update --pin v2.2.0 >/dev/null && at v2.2.0 && ok \
  || bad "--pin could not go back to v2.2.0"
git -C "$U" tag -a -m "Release v2.3.0" v2.3.0 main
publish v2.3.0
update --follow 2 >/dev/null && at v2.3.0 && ok \
  || bad "the line did not move up again to v2.3.0"

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

# A lower major (Heinzel's 2.22.0 -> 1.0.0) names its notes, no more.
signers "$TMP/release-key"
echo 9.9.0 > "$U/VERSION"
git -C "$U" commit --quiet -am "inherited 9.9.0"
git init --quiet --bare --initial-branch=main "$TMP/m2.git"
git -C "$U" push --quiet "$TMP/m2.git" main
P="$TMP/prod2"
git clone --quiet "$TMP/m2.git" "$P" && mkdir "$P/memory"
touch "$P/memory/.hostwarden-workspace"
release 5.0.0 && git -C "$U" push --quiet "$TMP/m2.git" main v5.0.0
out=$(hook)
case "$out" in *BREAKING* | *"- release 5.0.0"*) bad "notes printed: $out" ;;
*"9.9.0 -> 5.0.0"*"section of CHANGELOG"*) at v5.0.0 && ok || bad "$out" ;;
*) bad "the move to a lower major was not reported: $out" ;; esac
