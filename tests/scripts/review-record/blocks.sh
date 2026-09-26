# tests/scripts/review-record/blocks.sh — what counts as the record
# and what as an example: fences, quotes, comments and headings.
# Sourced by tests/scripts/review-record.sh, in the order its PARTS
# lists, into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

expect 1 "$A" "a record shown in a fenced example only" <<EOF
## How to write one

~~~
## Review
Codex m e, local, $A: no findings, x
~~~
EOF

R="Codex m e, local, $A: no findings, x"
T=$(printf '\t')

expect 1 "$A" "a four-backtick fence around a three-backtick example" <<EOF
## Review

\`\`\`\`
\`\`\`
$R
\`\`\`
\`\`\`\`
EOF

expect 1 "$A" "a closing fence indented four spaces" <<EOF
## Review

~~~
    ~~~
$R
~~~
EOF

expect 1 "$A" "a closing fence with text after it" <<EOF
## Review

~~~
~~~ end
$R
~~~
EOF

expect 1 "$A" "an indented code block after a blank line" <<EOF
## Review

    $R
EOF

expect 1 "$A" "an indented code block by a tab, after the heading" <<EOF
## Review
$T$R
EOF

expect 0 "$A" "an indented line that continues a paragraph" <<EOF
## Review

Recorded:
    $R
EOF

expect 1 "$A" "an indented code block in a list item" <<EOF
## Review

- The run:

      $R
EOF

expect 1 "$A" "a block quote, and a line it continues lazily" <<EOF
## Review

> An example:
$R
EOF

expect 1 "$A" "a fence in a block quote, a heading in one" <<EOF
> ## Review
> \`\`\`
> $R
EOF

expect 0 "$A" "a fence left open in a block quote ends with it" <<EOF
## Review

> \`\`\`
$R
EOF

expect 1 "$A" "an HTML comment" <<EOF
## Review

<!--
$R
-->
EOF

expect 1 "$A" "a comment inside a paragraph" <<EOF
## Review

Nothing yet <!--
$R
-->
EOF

expect 1 "$A" "an HTML block" <<EOF
## Review

<details>
$R
</details>
EOF

expect 0 "$A" "a paragraph between HTML blocks" <<EOF
## Review

<details>

$R

</details>
EOF

expect 0 "$A" "inline code, still visible to a reader" <<EOF
## Review

\`$R\`
EOF

expect 1 "$A" "a setext heading" <<EOF
## Review

$R
---
EOF

expect 0 "$A" "a heading with a closing sequence, indented" <<EOF
   ## Review ##

$R
EOF

expect 1 "$A" "a heading indented four spaces" <<EOF
    ## Review

$R
EOF

expect 0 "$A" "a heading nested in a list item ends nothing" <<EOF
## Review

- ## Notes
  $R
EOF

expect 0 "$A" "a heading nested in a block quote ends nothing" <<EOF
## Review

> ## Notes
$R
EOF

expect 1 "$A" "an HTML block opener with a quoted > in an attribute" <<EOF
## Review

<custom title=">">
$R
</custom>
EOF

expect 1 "$A" "a bare link reference definition, nothing left of it" <<EOF
## Review

[docs]: https://example.com
EOF

expect 0 "$A" "a link reference definition stripped, the record left" <<EOF
## Review

[docs]: https://example.com
$R
EOF

expect 1 "$A" "a link reference definition with a title, and nothing else" <<EOF
## Review

[docs]: https://example.com "The docs"
EOF

expect 1 "$A" "a run named outside the section" <<EOF
## Summary

Codex m e, local, $A: no findings, x

## Review

nothing yet
EOF

expect 1 "$A" "no body at all" </dev/null

expect 0 "$B" "priorities in the clauses" <<EOF
## Review

Codex m e, local, $A: 2 findings, x; One (a.md:1): P1, class 1, fixed in 22222222; Two (b.md:2): P3, class 2, not a bug: why
Codex m e, local, $B: no findings, x
EOF
