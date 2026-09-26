# tests/scripts/review-record/fixes.sh — the light list, and fix
# lines judged by what their commits touch. Sourced by
# tests/scripts/review-record.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

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
