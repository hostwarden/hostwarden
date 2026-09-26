# tests/scripts/review-record/lines.sh — run, rebase, squash, skip
# and fix lines, and the answers to findings. Sourced by
# tests/scripts/review-record.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

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
