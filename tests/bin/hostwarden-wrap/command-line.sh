# tests/bin/hostwarden-wrap/command-line.sh — every awk, the command
# line, --changed and a file in conflict. Sourced by
# tests/bin/hostwarden-wrap.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it


# The awks to run under: the default, then each other one here.
mkdir "$TMP/bin"
AWKS="awk"
for a in gawk mawk original-awk busybox; do
  command -v "$a" >/dev/null 2>&1 || continue
  if [ "$a" = busybox ]; then
    busybox awk 'BEGIN {}' 2>/dev/null || continue
  fi
  AWKS="$AWKS $a"
done
for a in $AWKS; do
  AWKNAME=$a
  if [ "$a" = awk ]; then
    fixtures
    continue
  fi
  d="$TMP/bin/$a"
  mkdir "$d"
  if [ "$a" = busybox ]; then
    printf '#!/bin/sh\nexec busybox awk "$@"\n' > "$d/awk"
  else
    printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v "$a")" > "$d/awk"
  fi
  chmod +x "$d/awk"
  PATH="$d:$PATH" fixtures
done
echo "awks: $AWKS"

# --- the command line --------------------------------------------
LONG='Words words words words words words words words words words words words words words'
f="$TMP/file.md"
printf '%s\n' "$LONG" > "$f"
chmod 640 "$f"
out=$(sh "$WRAP" "$f")
rc=$?
[ "$out" = "$f: rewrapped" ] && [ $rc -eq 0 ] || bad "a file: '$out' (exit $rc)"
[ "$(sed -n 2p "$f")" = words ] || bad "a file is not rewritten in place"
case $(ls -l "$f") in -rw-r-----*) ok ;; *) bad "a file lost its mode" ;; esac
out=$(sh "$WRAP" "$f")
[ -z "$out" ] && ok || bad "a file rewrapped twice: $out"
printf '%s\n' "$LONG" > "$TMP/one.md"
: > "$TMP/empty.md"
sh "$WRAP" "$TMP/one.md" "$TMP/empty.md" >/dev/null
[ ! -s "$TMP/empty.md" ] && ok || bad "an empty file took the text of the one before"
printf '# %s\n' "$LONG" > "$f"
out=$(sh "$WRAP" --check "$f")
[ $? -eq 1 ] && [ "$out" = "$f:1 (85)" ] && ok || bad "--check: '$out'"
cp "$f" "$TMP/copy.md"
out=$(sh "$WRAP" "$f")
[ $? -eq 1 ] && [ "$out" = "$f:1 (85)" ] && cmp -s "$f" "$TMP/copy.md" \
  && ok || bad "a heading over 80: '$out'"
printf '%s\n' "$LONG" > "$TMP/a=b.md"
(cd "$TMP" && sh "$WRAP" --check a=b.md >/dev/null)
[ $? -eq 1 ] && ok || bad "a file name with = in it is read as an assignment"
sh "$WRAP" --check "$TMP/missing.md" 2>/dev/null
[ $? -eq 2 ] && ok || bad "a missing file is no usage error"
sh "$WRAP" --bogus 2>/dev/null
[ $? -eq 2 ] && ok || bad "an unknown option is no usage error"
sh "$WRAP" --help | grep -q '^Usage:' && ok || bad "--help prints no usage"

# --changed: what git sees as changed or new, and nothing else.
R="$TMP/changed"
mkdir -p "$R/sub"
for n in changed.md same.md notes.txt; do printf '%s\n' "$LONG" > "$R/$n"; done
git -C "$R" init -q
git -C "$R" add -A
git -C "$R" -c user.name=alice -c user.email=alice@example.com commit -q -m init
printf '%s more\n' "$LONG" > "$R/changed.md"
printf '%s\n' "$LONG" > "$R/sub/new.md"
printf '%s more\n' "$LONG" > "$R/notes.txt"
ln -s same.md "$R/link.md"
out=$(cd "$R" && sh "$WRAP" --changed)
want='changed.md: rewrapped
sub/new.md: rewrapped'
[ "$out" = "$want" ] && ok || bad "--changed: '$out'"
[ "$(wc -l < "$R/same.md")" -eq 1 ] && [ "$(wc -l < "$R/notes.txt")" -eq 1 ] \
  && ok || bad "--changed touched a file git sees unchanged, or no .md"
printf '%s\n' "$LONG" >> "$R/sub/new.md"
out=$(cd "$R/sub" && sh "$WRAP" --changed)
[ "$out" = "new.md: rewrapped" ] && ok || bad "--changed in a subdirectory: '$out'"
(cd "$TMP" && sh "$WRAP" --changed 2>/dev/null)
[ $? -eq 2 ] && ok || bad "--changed outside a repository is no error"

# A merge left in conflict is left to whoever resolves it.
git -C "$R" config user.name alice
git -C "$R" config user.email alice@example.com
git -C "$R" add -A
git -C "$R" commit -q -m two
git -C "$R" checkout -q -b other
printf 'Ours, and %s\n' "$LONG" > "$R/same.md"
git -C "$R" commit -q -am ours
git -C "$R" checkout -q -
printf 'Theirs, and %s\n' "$LONG" > "$R/same.md"
git -C "$R" commit -q -am theirs
git -C "$R" merge -q other >/dev/null 2>&1
[ -n "$(git -C "$R" diff --name-only --diff-filter=U)" ] \
  || bad "the merge the conflict cases need did not conflict"
cp "$R/same.md" "$TMP/conflict.md"
out=$(cd "$R" && sh "$WRAP" --changed)
[ -z "$out" ] && cmp -s "$R/same.md" "$TMP/conflict.md" && ok \
  || bad "--changed rewrapped a file in conflict: $out"
out=$(sh "$WRAP" "$R/same.md")
[ -z "$out" ] && cmp -s "$R/same.md" "$TMP/conflict.md" && ok \
  || bad "a file with conflict markers was rewrapped: $out"
