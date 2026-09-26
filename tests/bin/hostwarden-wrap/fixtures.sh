# tests/bin/hostwarden-wrap/fixtures.sh — the filter's fixtures, one
# function run under every awk. Sourced by
# tests/bin/hostwarden-wrap.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

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
