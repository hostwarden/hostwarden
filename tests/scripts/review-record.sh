#!/bin/sh
# tests/scripts/review-record.sh — fixture matrix for
# scripts/review-record.sh and scripts/review-tier.sh. CI runs it
# through scripts/check.sh; an agent session leaves it to CI
# (.claude/rules/pull-requests.md → Checks).
#
# Runs from scripts/, where the two scripts it checks live.

cd "$(dirname "$0")/../../scripts" || exit 2
# shellcheck source=../helpers.sh
. ../tests/helpers.sh

A=1111111111111111111111111111111111111111
B=2222222222222222222222222222222222222222
C=3333333333333333333333333333333333333333

HERE=$(pwd)
IN=.
BASE=

# expect <exit code> <head> <what> -- the body on stdin, the checker
# run in $IN, where a fix line's commits are read, and given $BASE
# as the head's merge base where it is set
expect() {
  want=$1 head=$2
  shift 2
  (cd "$IN" && sh "$HERE/review-record.sh" "$head" ${BASE:+"$BASE"}) \
    >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    ok
  else
    bad "$* (exit $got, want $want)"
  fi
}

expect 0 "$A" "a clean run on the head" <<EOF
## Review

Codex gpt-6-sol medium, local, $A: no findings, 7d 8% used
EOF

expect 0 "$A" "a list marker" <<EOF
## Review
- Codex gpt-6-sol medium, local, $A: no findings, 7d 8% used
EOF

# A body edited in the browser.
CR=$(printf '\r')
SP=" "
expect 0 "$A" "CRLF line ends" <<EOF
## Review$CR
$CR
Codex m e, local, $A: no findings, x$CR
EOF

expect 1 "$B" "a run on an older head only" <<EOF
## Review

Codex gpt-6-sol medium, local, $A: no findings, 7d 8% used
EOF

expect 0 "$B" "every finding answered, the fix reviewed" <<EOF
## Review

Codex m e, local, $A: 2 findings, x; One (a.md:1): class 1, fixed in 22222222; Two (b.md:2): class 2/3, not a bug: why
Codex m e, local, $B: 1 finding, x; Three (c.md:3): class 4, deferred to a follow-up PR
EOF

expect 0 "$C" "full SHAs in backticks, a rebase after the fix" <<EOF
## Review

Codex m e, local, $A: 1 finding, x; One (a.md:1): class 1, fixed in \`22222222\`
Codex m e, local, $B: no findings, x
rebase, $C: from $B, range-diff checked
EOF

expect 1 "$C" "a rebase line with short SHAs" <<EOF
## Review

Codex m e, local, $B: no findings, x
rebase, 33333333: from 22222222, range-diff checked
EOF

expect 1 "$B" "a finding left unanswered" <<EOF
## Review

Codex m e, local, $A: 2 findings, x; One (a.md:1): class 1, fixed in 22222222
Codex m e, local, $B: no findings, x
EOF

expect 0 "$A" "a GitHub run, answered in its threads" <<EOF
## Review

Codex -, GitHub, $A: 2 findings, -
EOF

expect 0 "$C" "a rebase from a reviewed head, twice" <<EOF
## Review

Codex m e, local, $A: no findings, x
rebase, $B: from $A, range-diff checked
rebase, $C: from $B, range-diff checked
EOF

expect 0 "$C" "a squash of a reviewed head" <<EOF
## Review

Codex m e, local, $A: no findings, x
squash, $C: from $A, tree unchanged
EOF

expect 0 "$C" "a stacked child's base and re-review notes" <<EOF
## Review

Codex m e, local, $A: no findings, x
base under $A: $B
rebase, $C: from $A, range-diff checked
re-review skipped: base unchanged since $B
EOF

expect 1 "$C" "a re-review note appended to the rebase line" <<EOF
## Review

Codex m e, local, $A: no findings, x
rebase, $C: from $A, range-diff checked, re-review skipped: base unchanged since $B
EOF

expect 1 "$C" "a rebase from a head nobody reviewed" <<EOF
## Review

Codex m e, local, $A: no findings, x
rebase, $C: from $B, range-diff checked
EOF

expect 1 "$A" "a loop of rebase lines" <<EOF
## Review

rebase, $A: from $B, range-diff checked
rebase, $B: from $A, range-diff checked
EOF

expect 1 "$C" "a skip on an earlier head only" <<EOF
## Second review skipped

$A: Codex limit reached, resets 2026-09-30 15:18 CEST; Alice decided
EOF

expect 0 "$C" "a skip on the head, and a squash from a skipped head" <<EOF
## Second review skipped

$A: Codex limit reached, resets 2026-09-30 15:18 CEST; Alice decided
$B: Codex limit reached, resets 2026-09-30 15:18 CEST; Alice decided

## Review

squash, $C: from $B, tree unchanged
EOF

expect 1 "$C" "a skip that names the head in its reason only" <<EOF
## Second review skipped

$A: Codex limit reached while $C waited, resets -; Alice decided
EOF

expect 1 "$A" "a skip without its decision" <<EOF
## Second review skipped

$A: skipped
EOF

expect 0 "$A" "a skip with no limit to reset, a blank at the end" <<EOF
## Second review skipped

$A: a person's pull request, resets -; Alice decided$SP
EOF

expect 1 "$B" "a rebase line without its closing words" <<EOF
## Review

Codex m e, local, $A: no findings, x
rebase, $B: from $A
EOF

expect 1 "$B" "a squash line with the rebase's closing words" <<EOF
## Review

Codex m e, local, $A: no findings, x
squash, $B: from $A, range-diff checked
EOF

expect 0 "$B" "a rebase line with a blank at the end" <<EOF
## Review

Codex m e, local, $A: no findings, x
rebase, $B: from $A, range-diff checked$SP
EOF

expect 1 "$B" "an older run line without what is left" <<EOF
## Review

Codex m e, local, $A: 2 findings; One (a.md:1): class 1, fixed in 22222222
Codex m e, local, $B: no findings, x
EOF

expect 1 "$A" "a run line without what is left" <<EOF
## Review

Codex m e, local, $A: no findings
EOF

expect 1 "$B" "not a bug without a reason" <<EOF
## Review

Codex m e, local, $A: 1 finding, x; One (a.md:1): class 1, not a bug
Codex m e, local, $B: no findings, x
EOF

expect 0 "$B" "one title in two places" <<EOF
## Review

Codex m e, local, $A: 2 findings, x; Quote it (a.sh:1): class 6, not a bug: why; Quote it (b.sh:9): class 6, deferred to a follow-up PR
Codex m e, local, $B: no findings, x
EOF

expect 1 "$B" "one answer repeated for two findings" <<EOF
## Review

Codex m e, local, $A: 2 findings, x; One (a.md:1): class 1, not a bug: why; One (a.md:1): class 1, not a bug: why
Codex m e, local, $B: no findings, x
EOF

expect 0 "$B" "two findings in one place, a range, and . between" <<EOF
## Review

Codex m e, local, $A: 3 findings, x. One (a.md:1): class 1, not a bug: why. Two (a.md:1): class 1, not a bug: why. Three (b.md:5-9): class 2, deferred to a follow-up PR
Codex m e, local, $B: no findings, x
EOF

expect 1 "$A" "a local run spelled Local, unanswered" <<EOF
## Review

Codex m e, Local, $A: 1 finding, x
EOF

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

# The rule's light list and review-tier.sh's are one list: the
# paths in backticks in the rule's Light bullet, word for word.
rule=$(awk '/^- \*\*Light\*\* when/ { on = 1 }
  on && sub(/included\..*/, "") { print; exit }
  on { print }' ../.claude/rules/pull-requests.md \
  | grep -o '`[^`]*`' | tr -d '`' | sort)
script=$(sed -nE "s/^LIGHT='(.*)'$/\\1/p" review-tier.sh | tr ' ' '\n' | sort)
[ -n "$rule" ] && [ "$rule" = "$script" ] \
  && ok || bad "the light list differs between the rule and review-tier.sh"

# A fix line is judged by what its commit touches, so these run in
# a repository of their own: $L1 a head the round ran on, then fixes
# of it that touch docs/ alone ($L2), a script ($F2), a script moved
# into docs/ ($M2), this rule file ($P2), and a non-ASCII name in
# docs/ ($U2).
IN=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-review-record-test.XXXXXX") \
  || exit 2
trap 'rm -rf "$IN"' EXIT INT TERM
g() { git -C "$IN" -c user.name=alice -c user.email=alice@example.com \
  -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
# fixof <message> <command...> -- a commit on $L1 made by the command
# in the repository, its SHA printed.
fixof() {
  m=$1; shift
  g checkout -q "$L1" && (cd "$IN" && "$@") && g add -A \
    && g commit -q -m "$m" && git -C "$IN" rev-parse HEAD
}
g init -q
mkdir -p "$IN/docs" "$IN/scripts" "$IN/.claude/rules"
echo a >"$IN/docs/a.md"
echo x >"$IN/scripts/x.sh"
echo y >"$IN/scripts/y.sh"
g add -A && g commit -q -m round
L1=$(git -C "$IN" rev-parse HEAD)
L2=$(fixof light sh -c 'echo b >>docs/a.md')
F2=$(fixof full sh -c 'echo z >>scripts/x.sh')
M2=$(fixof moved git mv scripts/y.sh docs/y.md)
P2=$(fixof rules sh -c 'echo r >.claude/rules/pull-requests.md')
U2=$(fixof umlaut sh -c 'echo u >docs/ümlaut.md')

tier() { (cd "$IN" && sh "$HERE/review-tier.sh" "$@" 2>/dev/null | head -1); }
[ "$(tier "$L1" "$L2")" = light ] && ok || bad "a docs change is light"
[ "$(tier "$L1" "$F2")" = full ] && ok || bad "a script change is full"
[ "$(tier "$L1" "$M2")" = full ] && ok || bad "a script moved into docs is full"
[ "$(tier "$L1" "$P2")" = full ] \
  && ok || bad "pull-requests.md is full"
[ "$(tier "$L1..$L2")" = light ] && ok || bad "a range alone"
[ "$(tier "$L1" "$U2")" = light ] && ok || bad "a non-ASCII name in docs"
(cd "$IN" && sh "$HERE/review-tier.sh" -p "$L1" >/dev/null 2>&1)
[ $? -eq 2 ] && ok || bad "an option is a usage error"

round="Codex m e, local, $L1: 2 findings, x"

expect 0 "$L2" "a light fix of two P2s" <<EOF
## Review

$round; One (docs/a.md:1): P2, class 1, fixed in $(printf %.8s "$L2"); Two (docs/a.md:2): P3, class 2, fixed in $L2
fix, $L2: from $L1, light fix checked by own review
EOF

expect 0 "$L2" "a light fix, squashed" <<EOF
## Review

$round; One (docs/a.md:1): P2, class 1, fixed in $L2; Two (docs/a.md:2): P3, class 2, not a bug: why
fix, $L2: from $L1, light fix checked by own review
squash, $C: from $L2, tree unchanged
EOF

expect 1 "$L2" "a light fix of a P1" <<EOF
## Review

$round; One (docs/a.md:1): P1, class 1, fixed in $L2; Two (docs/a.md:2): P3, class 2, fixed in $L2
fix, $L2: from $L1, light fix checked by own review
EOF

expect 1 "$L2" "a light fix of a finding without its priority" <<EOF
## Review

$round; One (docs/a.md:1): class 1, fixed in $L2; Two (docs/a.md:2): P3, class 2, fixed in $L2
fix, $L2: from $L1, light fix checked by own review
EOF

expect 1 "$L2" "a fix line that answers no finding" <<EOF
## Review

$round; One (docs/a.md:1): P2, class 1, not a bug: why; Two (docs/a.md:2): P3, class 2, deferred to a follow-up PR
fix, $L2: from $L1, light fix checked by own review
EOF

expect 1 "$F2" "a fix that touches a script" <<EOF
## Review

$round; One (x.sh:1): P2, class 1, fixed in $F2; Two (x.sh:2): P3, class 2, fixed in $F2
fix, $F2: from $L1, light fix checked by own review
EOF

expect 1 "$M2" "a fix that moves a script into docs" <<EOF
## Review

$round; One (docs/y.md:1): P2, class 1, fixed in $M2; Two (docs/y.md:2): P3, class 2, fixed in $M2
fix, $M2: from $L1, light fix checked by own review
EOF

expect 1 "$L2" "a light fix from a head nobody reviewed" <<EOF
## Review

Codex m e, local, $A: 1 finding, x; One (docs/a.md:1): P2, class 1, fixed in $L2
fix, $L2: from $L1, light fix checked by own review
EOF

expect 1 "$L2" "a light fix whose clause is another run's" <<EOF
## Review

Codex m e, local, $A: 1 finding, x; One (docs/a.md:1): P2, class 1, fixed in $L2
Codex m e, local, $L1: no findings, x
fix, $L2: from $L1, light fix checked by own review
EOF

expect 1 "$L2" "a light fix after a GitHub round" <<EOF
## Review

Codex -, GitHub, $L1: 2 findings, -
fix, $L2: from $L1, light fix checked by own review
EOF

expect 1 "$L2" "a fix line without its closing words" <<EOF
## Review

$round; One (docs/a.md:1): P2, class 1, fixed in $L2; Two (docs/a.md:2): P3, class 2, fixed in $L2
fix, $L2: from $L1
EOF

expect 1 "$B" "a fix line whose commits are not there" <<EOF
## Review

Codex m e, local, $A: 1 finding, x; One (docs/a.md:1): P2, class 1, fixed in $B
fix, $B: from $A, light fix checked by own review
EOF

expect 2 "${A%?}" "a short head" </dev/null

# The own review's line is held to the files between the merge base
# and the head, once the merge base is given.
BASE=$L1
own="Own review: light (docs/a.md), 1 pass, no findings"
p1="Codex m e, local, $L1: 1 finding, x; One (docs/a.md:1): P1, class 1, not a bug: why"

expect 1 "$L2" "no own review line, given the merge base" <<EOF
## Review

Codex m e, local, $L2: no findings, x
EOF

expect 0 "$L2" "no own review line where skip lines are the record" <<EOF
## Second review skipped

$L2: a person's pull request, resets -; Alice decided
EOF

expect 0 "$F2" "no own review line, an agent's capacity skip the record" <<EOF
## Second review skipped

$F2: Codex limit reached, resets 2026-09-30 15:18 CEST; Alice decided
EOF

expect 1 "$F2" "a light own review of a script, a skip the record" <<EOF
## Second review skipped

$F2: a person's pull request, resets -; Alice decided

## Review

$own
EOF

expect 0 "$L2" "a light own review of a docs change" <<EOF
## Review

$own
Codex m e, local, $L2: no findings, x
EOF

expect 0 "$L2" "a full own review of a docs change" <<EOF
## Review

Own review: full (docs/a.md), 2 focused, no findings
Codex m e, local, $L2: no findings, x
EOF

expect 1 "$F2" "a light own review of a script change" <<EOF
## Review

$own
Codex m e, local, $F2: no findings, x
EOF

expect 1 "$M2" "a light own review of a script moved into docs" <<EOF
## Review

$own
Codex m e, local, $M2: no findings, x
EOF

expect 0 "$F2" "a full own review of a script change" <<EOF
## Review

- Own review: full (scripts/x.sh), 2 focused, 1 fix pass, 3 findings.
- Codex m e, local, $F2: no findings, x
EOF

expect 0 "$F2" "a light own review turned full by a push" <<EOF
## Review

$own, full from $F2
Codex m e, local, $F2: no findings, x
EOF

expect 1 "$F2" "an own review shown in an example only" <<EOF
## Review

Codex m e, local, $F2: no findings, x

    Own review: full (scripts/x.sh), 2 focused, no findings
EOF

expect 1 "$L2" "a light own review after a round found a P1" <<EOF
## Review

$own
$p1
Codex m e, local, $L2: no findings, x
EOF

expect 0 "$L2" "a light own review turned full by a round" <<EOF
## Review

$own, full from round 1
$p1
Codex m e, local, $L2: no findings, x
EOF

expect 0 "$L2" "a light own review, a P2 in the round" <<EOF
## Review

$own
Codex m e, local, $L1: 1 finding, x; One (docs/a.md:1): P2, class 1, fixed in $L2
fix, $L2: from $L1, light fix checked by own review
EOF

expect 0 "$L2" "a light own review, a GitHub round" <<EOF
## Review

$own
Codex -, GitHub, $L1: 2 findings, -
Codex m e, local, $L2: no findings, x
EOF

BASE=$A

expect 1 "$B" "a light own review whose commits are not there" <<EOF
## Review

$own
Codex m e, local, $B: no findings, x
EOF

expect 0 "$B" "a full own review needs no commit" <<EOF
## Review

Own review: full (scripts/x.sh), 2 focused, no findings
Codex m e, local, $B: no findings, x
EOF

BASE=${A%?}
expect 2 "$A" "a short merge base" </dev/null

finish "review record tests"
