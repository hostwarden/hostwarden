#!/bin/sh
# wrap-test.sh — fixture matrix for bin/hostwarden-wrap, the hook
# that runs it, .claude/hooks/wrap-markdown.sh, and the rewrap in
# bin/hostwarden-sync commit. CI runs it
# through scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# The reflow runs under every awk this machine has of the four it
# has to work with — BWK awk, gawk, mawk and busybox — each put
# first on PATH in turn, since the script calls awk by name.

cd "$(dirname "$0")/.." || exit 2
ROOT=$(pwd -P)
WRAP="$ROOT/bin/hostwarden-wrap"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-wrap-test.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT INT TERM

ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# fixture <name> [<exit code>] -- stdin holds the input, a line
# `=== want`, and the output wanted; without that line, the input
# is wanted back unchanged. Checks the filter's output and exit
# code, and that its output passes through unchanged again.
fixture() {
  name=$1 want_rc=${2:-0}
  awk -v i="$TMP/in" -v w="$TMP/want" '
    $0 == "=== want" { on = 1; next }
    { print > (on ? w : i) }
    END { if (!on) { close(i); while ((getline l < i) > 0) print l > w }
          else if (!NR) printf "" > i }'
  [ -f "$TMP/want" ] || : > "$TMP/want"
  sh "$WRAP" < "$TMP/in" > "$TMP/got" 2> "$TMP/err"
  rc=$?
  if ! cmp -s "$TMP/want" "$TMP/got"; then
    bad "$AWKNAME: $name"
    diff "$TMP/want" "$TMP/got" | sed 's/^/    /'
  elif [ "$rc" -ne "$want_rc" ]; then
    bad "$AWKNAME: $name (exit $rc, want $want_rc)"
  else
    ok
  fi
  sh "$WRAP" < "$TMP/got" > "$TMP/again" 2>/dev/null
  cmp -s "$TMP/got" "$TMP/again" || bad "$AWKNAME: $name is not stable"
  rm -f "$TMP/in" "$TMP/want" "$TMP/got" "$TMP/again" "$TMP/err"
}

# Spaces at the end of a line, which an editor would strip from a
# quoted here-document.
SP=' '

fixtures() {

fixture "a file that fits stays as it is" <<'EOF'
# Title

A paragraph whose lines
are short, and stay where they are.
EOF

fixture "the spill of a long line gets a line of its own" <<'EOF'
One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen
This next line of the same paragraph is long enough that nothing joins it.
And a last one.
=== want
One two three four five six seven eight nine ten eleven twelve thirteen fourteen
fifteen
This next line of the same paragraph is long enough that nothing joins it.
And a last one.
EOF

fixture "the spill joins the next line where both fit" <<'EOF'
One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen
sixteen.
And a last one.
=== want
One two three four five six seven eight nine ten eleven twelve thirteen fourteen
fifteen sixteen.
And a last one.
EOF

fixture "a list item keeps its marker and wraps under its text" <<'EOF'
- A list item that is far too long, so it has to wrap underneath its own text body.
  1. A nested ordered item that also runs over the limit and wraps under its text.
=== want
- A list item that is far too long, so it has to wrap underneath its own text
  body.
  1. A nested ordered item that also runs over the limit and wraps under its
     text.
EOF

fixture "a quote keeps its marker" <<'EOF'
> A quoted paragraph that is far too long to fit, so its next line is quoted too.
=== want
> A quoted paragraph that is far too long to fit, so its next line is quoted
> too.
EOF

fixture "a quoted list item" <<'EOF'
> - An item in a quote whose text is long enough to need a second line of it here.
=== want
> - An item in a quote whose text is long enough to need a second line of it
>   here.
EOF

fixture "no line starts with a block marker, nor with an arrow" <<'EOF'
Words words words words words words words words words words words words abcdefgh - x
Words words words words words words words words words words words words abcdefgh 1. x
Words words words words words words words words words words words words abcdefgh # x
Words words words words words words words words words words words words abcdefgh > x
Words words words words words words words words words words words words abcdefgh <b> x
Words words words words words words words words words words words words abcdefgh === x
Words words words words words words words words words words words words abcdefgh | x
Words words words words words words words words words words words words abcdefgh ``` x
Words words words words words words words words words words words words abcdefgh → x
=== want
Words words words words words words words words words words words words
abcdefgh - x
Words words words words words words words words words words words words
abcdefgh 1. x
Words words words words words words words words words words words words
abcdefgh # x
Words words words words words words words words words words words words
abcdefgh > x
Words words words words words words words words words words words words
abcdefgh <b> x
Words words words words words words words words words words words words
abcdefgh === x
Words words words words words words words words words words words words
abcdefgh | x
Words words words words words words words words words words words words
abcdefgh ``` x
Words words words words words words words words words words words words
abcdefgh → x
EOF

fixture "a pointer's arrow stays with the file it follows" <<'EOF'
Words words words words words words words words words words a `rules/secrets.md` → Commands That Leak
=== want
Words words words words words words words words words words a
`rules/secrets.md` → Commands That Leak
EOF

fixture "a word ending in a backslash never ends a line" <<'EOF'
Words words words words words words words words words words words words ab C:\ next
=== want
Words words words words words words words words words words words words ab
C:\ next
EOF

fixture "spaces after a backslash stay, and so does the glue" <<'EOF'
Words words words words words words words words words words words words ab C:\   next
=== want
Words words words words words words words words words words words words ab
C:\   next
EOF

# Two backslashes are one escaped: the backtick after them opens a
# code span, whose two spaces keep run and of together.
fixture "after an escaped backslash a backtick opens a code span" <<'EOF'
Words words words words words words words words words words words words \\`run  of` bar
=== want
Words words words words words words words words words words words words
\\`run  of` bar
EOF

# Were the backtick to open a code span, the two spaces would glue
# ab and cd, and ab would not fit here.
fixture "an escaped backtick opens no code span" <<'EOF'
Words words words words words words words words words words words words \` ab  cd
=== want
Words words words words words words words words words words words words \` ab
cd
EOF

# A code span that runs onto the next line: the spaces that end the
# line are in it, and two of them are no hard break there. A
# backtick that never closes opens nothing, and its line's two
# spaces are one. Unquoted, for \$SP; each backtick escaped.
fixture "spaces that end a line inside a code span stay in it" <<EOF
Words words words words words words words words words words words words abcd \`foo$SP
bar\` end.

Words words words words words words words words words words words words ab \`foo$SP$SP
bar\` x

Words words words words words words words words words words words words ab \`open$SP$SP
never closes, so a hard break.
=== want
Words words words words words words words words words words words words abcd
\`foo$SP bar\` end.

Words words words words words words words words words words words words ab
\`foo$SP$SP bar\` x

Words words words words words words words words words words words words ab
\`open$SP$SP
never closes, so a hard break.
EOF

fixture "no word crosses a backslash hard break" <<'EOF'
Words words words words words words words words words words words words words words\
next segment.
=== want
Words words words words words words words words words words words words words
words\
next segment.
EOF

fixture "no word crosses a two-space hard break" <<EOF
Words words words words words words words words words words words words words words$SP$SP
next segment.
=== want
Words words words words words words words words words words words words words
words$SP$SP
next segment.
EOF

fixture "characters, not bytes; link targets and URLs do not count" <<'EOF'
Ähm — äöü éè ñ words words words words words words words words words wörds.
See [the docs](https://example.com/a/very/long/path/that/goes/on/and/on) for more.
Or https://example.com/a/very/long/path/that/goes/on/and/on/and/on/and/on inline.
EOF

fixture "what is not a paragraph is left, and listed" 1 <<'EOF'
---
description: a front matter line that is longer than eighty characters, left alone
---

# A heading that is longer than eighty characters is left for a person to shorten

| a table row that is longer than eighty characters is left for a person | to fix |
|---|---|

<div>
an HTML block line that is longer than eighty characters is left for a person too
</div>

[ref]: https://example.com/ "a link reference definition that is left alone, long"
EOF

fixture "a generated file's first line marks it as passed through whole" <<'EOF'
<!-- Generated by decisions.py --write. Do not edit by hand. -->

# Decisions

One line per record, generated as one line no matter how long it runs past eighty characters here.

| Decision | Tags | Rule |
| :--- | :--- | :--- |
| A decision title long enough on its own to run past eighty characters in this table row | tag | — |
EOF

fixture "code is neither moved nor measured" <<'EOF'
```sh
a fenced line that is longer than eighty characters and must never be touched at all
```

    an indented code line that is longer than eighty characters and is never touched

- In a list:

  ```
  a fenced line in a list item that is longer than eighty characters stays as it is
  ```
EOF

fixture "a setext heading's text is left" 1 <<'EOF'
A setext heading whose text line is longer than eighty characters is not a paragraph
=====
EOF

fixture "a paragraph with a tab in it is left" 1 <<'EOF'
Words	with a tab in them in a paragraph that is longer than eighty characters wide ok
EOF

fixture "a tab after a list marker stops at column four" <<'EOF'
-	An item whose marker is followed by a tab, so its text starts at column four.

    Its second paragraph, indented four, still belongs to it and is long enough too.
=== want
-	An item whose marker is followed by a tab, so its text starts at column four.

    Its second paragraph, indented four, still belongs to it and is long enough
    too.
EOF

fixture "spaces inside a code span stay as they are" <<'EOF'
Words words words words words words words words words words words words `run  of` x

A code span opens here `and
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW keeps  its  runs` y z

Outside  one,  runs of spaces stay too, words words words words words words. More words.
=== want
Words words words words words words words words words words words words
`run  of` x

A code span opens here `and
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
keeps  its  runs` y z

Outside  one,  runs of spaces stay too, words words words words words words.
More words.
EOF

fixture "a lazy line continues the quote's paragraph" <<'EOF'
> A quoted paragraph whose second line is lazy and has no marker at all.
so this line is long enough to need wrapping, and it wraps under the quote here too.
=== want
> A quoted paragraph whose second line is lazy and has no marker at all.
so this line is long enough to need wrapping, and it wraps under the quote here
> too.
EOF

fixture "a word longer than a line stands alone" 1 <<'EOF'
Short words then `a/very/long/path/without/any/space/in/it/that/runs/past/eighty/columns/and/more/x` end.
=== want
Short words then
`a/very/long/path/without/any/space/in/it/that/runs/past/eighty/columns/and/more/x`
end.
EOF

}

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

# --- the hook ----------------------------------------------------
# A checkout of each mode, the hook sitting in it: the mode is a
# property of the tree the hook finds its root from.
checkout() {
  c="$TMP/$1"
  mkdir -p "$c/.claude/hooks" "$c/bin" "$c/lib" "$c/rules"
  cp .claude/hooks/wrap-markdown.sh .claude/hooks/json.sh \
    .claude/hooks/mode.sh "$c/.claude/hooks/"
  cp bin/hostwarden-wrap "$c/bin/"
  cp lib/markdown-blocks.awk "$c/lib/"
  printf '/memory/\n' > "$c/.gitignore"
  printf '%s\n' "$LONG" > "$c/rules/shipped.md"
  git -C "$c" init -q
  git -C "$c" add -A
  git -C "$c" -c user.name=alice -c user.email=alice@example.com \
    commit -q -m init
}
checkout dev
checkout ops
mkdir -p "$TMP/ops/memory/machines"
git -C "$TMP/ops/memory" init -q
: > "$TMP/ops/memory/.hostwarden-workspace"
ln -s ../rules "$TMP/ops/memory/linked"
ln -s ../rules/shipped.md "$TMP/ops/memory/link.md"
DEV=$(cd "$TMP/dev" && pwd -P)
OPS=$(cd "$TMP/ops" && pwd -P)

# hook <checkout> <file> <wanted: wrapped|left> <what>
hook() {
  c=$1 file=$2
  [ -e "$file" ] || printf '%s\n' "$LONG" > "$file"
  before=$(cat "$file")
  out=$(printf '{"session_id":"t","tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
    "$file" | sh "$c/.claude/hooks/wrap-markdown.sh")
  if [ "$(cat "$file")" != "$before" ]; then got=wrapped; else got=left; fi
  if [ "$got" != "$3" ]; then
    bad "hook: $4 ($got)"
  elif [ "$got" = wrapped ]; then
    case $out in
      *'"hookEventName":"PostToolUse"'*'rewrapped'*) ok ;;
      *) bad "hook: $4 says nothing: $out" ;;
    esac
  else
    ok
  fi
}
hook "$DEV" "$DEV/rules/shipped.md" wrapped "development rewraps a shipped file"
hook "$DEV" "$DEV/notes.txt" left "a file that is no .md"
hook "$DEV" "$TMP/outside.md" left "a file outside the checkout"
hook "$OPS" "$OPS/memory/machines/web1.example.com.md" wrapped \
  "operations rewraps a file under memory/"
hook "$OPS" "$OPS/rules/shipped.md" left "operations leaves a shipped file"
hook "$OPS" "$OPS/memory/link.md" left \
  "operations leaves a link into a shipped file"
hook "$OPS" "$OPS/memory/linked/shipped.md" left \
  "operations leaves a shipped file behind a directory link"
printf '# %s\n' "$LONG" > "$DEV/head.md"
out=$(printf '{"tool_input":{"file_path":"%s"}}' "$DEV/head.md" \
  | sh "$DEV/.claude/hooks/wrap-markdown.sh")
case $out in
  *'Still over 80'*'head.md:1 (85)'*) ok ;;
  *) bad "hook: a heading over 80 is not named: $out" ;;
esac
out=$(printf '{"tool_input":{"file_path":"%s"}}' "$DEV/rules/shipped.md" \
  | sh "$DEV/.claude/hooks/wrap-markdown.sh")
[ -z "$out" ] && ok || bad "hook: a file that fits gets a message: $out"

# After a shell command, which names no file: what git sees as
# changed or new, in the checkout in development and in memory/
# alone in operations.
bash_hook() {
  printf '{"tool_name":"Bash","tool_input":{"command":"true"}}' \
    | sh "$1/.claude/hooks/wrap-markdown.sh"
}
mkdir "$DEV/docs"
printf '%s\n' "$LONG" > "$DEV/docs/shell.md"
out=$(bash_hook "$DEV")
case $out in
  *'rewrapped docs/shell.md at 80'*'Still over 80'*'head.md:1 (85)'*) ok ;;
  *) bad "hook after a command in development: $out" ;;
esac
printf '%s\n' "$LONG" > "$OPS/memory/machines/db1.example.com.md"
printf '%s\n' "$LONG" >> "$OPS/rules/shipped.md"
out=$(bash_hook "$OPS")
case $out in
  *'rewrapped memory/machines/db1.example.com.md at 80'*) ok ;;
  *) bad "hook after a command in operations: $out" ;;
esac
[ "$(wc -l < "$OPS/rules/shipped.md")" -eq 2 ] && ok \
  || bad "hook after a command rewrapped a shipped file in operations"

# --- hostwarden-sync commit --------------------------------------
# Whatever wrote it, a workspace commit takes Markdown wrapped.
cp bin/hostwarden-sync "$OPS/bin/"
git -C "$OPS/memory" config user.name alice
git -C "$OPS/memory" config user.email alice@example.com
printf '%s\n' "$LONG" > "$OPS/memory/machines/web2.example.com.md"
(cd "$OPS" && sh bin/hostwarden-sync commit "Test" \
  memory/machines/web2.example.com.md) || bad "hostwarden-sync commit failed"
got=$(git -C "$OPS/memory" show HEAD:machines/web2.example.com.md 2>/dev/null)
[ "$got" = "$(printf '%s\n%s' "${LONG% words}" words)" ] && ok \
  || bad "hostwarden-sync commit took Markdown unwrapped: $got"
[ -z "$(git -C "$OPS/memory" status --porcelain -- machines/web2.example.com.md)" ] \
  && ok || bad "hostwarden-sync commit left a change behind"

echo "wrap tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
