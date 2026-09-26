# tests/scripts/review-record/own-review.sh — the own review's line,
# held to the files between the merge base and the head. Sourced by
# tests/scripts/review-record.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

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
