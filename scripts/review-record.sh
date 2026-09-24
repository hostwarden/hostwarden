#!/bin/sh
# review-record.sh — whether a pull request body records the second
# review of its head, and the own review's tier, as
# .claude/rules/pull-requests.md → The review record says.
#
#   sh scripts/review-record.sh <head sha> [<merge base sha>] < <body>
#
# Exits 0 when the record is there, 1 with what is missing, 2 on a
# usage error or without its block reader. It proves the record
# exists, not that the review was any good. The review-record
# workflow runs it, the default branch's copy, on a pull request
# that is not a draft, in a checkout of that branch, and gives it
# the head's merge base with the base branch, without which the own
# review's line is not read: that line (ownreview() below) and a fix
# line (covered() below) are judged by
# the files between two commits, which are fetched from `origin` by
# their SHAs for that, their names read and nothing of them run.

[ $# -ge 1 ] && [ $# -le 2 ] \
  && ! printf '%s\n' "$@" | grep -qvxE '[0-9a-f]{40}' || {
  echo "usage: sh scripts/review-record.sh <full head sha>" \
    "[<full merge base sha>] < <body>" >&2
  exit 2
}
HEAD_SHA=$1
BASE_SHA=${2:-}

# A body edited in the browser arrives with CRLF line ends.
BODY=$(tr -d '\r')

# The block reader both this and bin/hostwarden-wrap run. The
# review-record workflow checks it out beside this file.
BLOCKS=$(cat "$(dirname "$0")/../lib/markdown-blocks.awk") || exit 2

# section <title> -- the lines a reader sees as text under the
# heading `## <title>`, up to the next heading of level one or two.
# The body is read as CommonMark 0.31.2 reads its blocks
# (lib/markdown-blocks.awk): only a paragraph's lines count, in a
# list item or not. A code block, fenced or indented, a block quote,
# an HTML block and an HTML comment are examples, not the record.
# A heading nested in a list item or a quote is nested text and
# starts or ends nothing; only one outside every container does.
# Where the reading is in doubt — a setext heading, a paragraph
# that opens like a link reference definition — the lines are left
# out, and a top-level setext heading still ends the section, since
# it can never carry the `## <title>` that would reopen one.
section() {
  printf '%s\n' "$BODY" | awk -v h="$1" "$BLOCKS"'
    BEGIN {
      # A link reference definition, on its own line: a label, a
      # colon, a destination, and an optional title in one of the
      # three quote forms. Only a complete one is stripped — a
      # title that spills onto the next line is past what this
      # checks, and is left as paragraph text rather than guessed
      # at, the same way a setext heading or a fenced block whose
      # closer never comes is left as what it plainly is.
      TITLE = "(\"[^\"]*\"|" SQ "[^" SQ "]*" SQ "|\\([^()]*\\))"
      LRDLINE = "^\\[[^][]+\\]:[ \t]*(<[^<>]*>|[^ \t<>]+)" \
        "([ \t]+" TITLE ")?[ \t]*$"
    }
    function quoted(   i) {
      for (i = 1; i <= N; i++) if (CT[i] == "q") return 1
      return 0
    }
    function on_para(lazy) { P[++PN] = substr(LN, NN) }
    function on_other(kind) { }
    # on_heading(level, title) -- only one outside every container
    # starts or ends a section; one in a list item or a quote is
    # nested text and touches nothing.
    function on_heading(lv, t) {
      if (N || lv > 2) return
      ON = (lv == 2 && t == h)
    }
    function nl(t,   x) { x = t; gsub(/[^\n]/, "", x); return x }
    # on_para_end(setext) -- a closed paragraph, its HTML comments
    # and any complete link reference definitions at its start taken
    # out, line by line; none of it where the paragraph was quoted or
    # the text of a setext heading.
    function on_para_end(setext,   s, o, i, n, e, a, skip) {
      if (setext || !ON || quoted()) { PN = 0; return }
      skip = 0
      while (skip < PN && P[skip + 1] ~ LRDLINE) skip++
      if (skip >= PN) { PN = 0; return }
      s = P[skip + 1]
      for (i = skip + 2; i <= PN; i++) s = s "\n" P[i]
      PN = 0; o = ""; i = 1; n = length(s)
      while (i <= n) {
        if (substr(s, i, 5) == "<!-->") { i += 5; continue }
        if (substr(s, i, 6) == "<!--->") { i += 6; continue }
        if (substr(s, i, 4) == "<!--" \
          && (e = index(substr(s, i + 4), "-->"))) {
          o = o nl(substr(s, i, e + 6)); i += e + 6; continue
        }
        o = o substr(s, i, 1); i++
      }
      n = split(o, a, "\n")
      for (i = 1; i <= n; i++) print a[i]
    }
    { block() }
    END { blocks_end() }'
}

REVIEW=$(section 'Review')
SKIP=$(section 'Second review skipped')

fail=
missing() { echo "review record: $*"; fail=1; }

# The heads a run or a skip names, each where its line puts it: a
# run's `<reviewer> <model> <effort>, <where>, <sha>: <k> findings,
# <left>…`, a skip's `<sha>: <reason>, resets <time>; <who>
# decided`.
SHAPE='^[^,]+, ([^,]+), ([0-9a-f]{40}): (no findings|1 finding|[0-9]+ findings)'
RUN="$SHAPE, [^ ]"
RUNS=$(printf '%s\n' "$REVIEW" | sed -nE "s/$RUN.*$/\\2/p")
SKIPS=$(printf '%s\n' "$SKIP" \
  | sed -nE 's/^([0-9a-f]{40}): .+, resets [^;]+; .+ decided[[:space:]]*$/\1/p')

# A local run's line carries one answer per finding, a clause
# `<title> (<path:line>): P<n>, class <n>, <answer>` each, told
# apart by title and place: the line is cut after each answer, and
# a clause starts after the last `; `, `. ` or ` — ` before its
# place. A GitHub run's answers are its threads, which this does not
# read. The priority is needed only where a fix line relies on it,
# so a clause without one still counts as answered. FIXES collects
# `<run> P<n> <sha>` for each clause answered "fixed in <sha>",
# `<run>` the head the run reviewed and `P` alone where the clause
# names no priority. HIGH is the first run whose line carries a P0
# or a P1, whatever its answer, which turns a light own review full.
FORM='<title> (<path:line>): P<n>, class <n>, <answer>'
PLACE='\([^()]*:[0-9]+(-[0-9]+)?\): (P[0-3], )?class [0-9]+(/[0-9]+)*, '
ANSWER='(fixed in `?[0-9a-f]{7,40}|not a bug: |deferred to a follow-up PR)'
FIXES=
HIGH=
while IFS= read -r line; do
  run=$(printf '%s\n' "$line" | sed -nE "s/$SHAPE.*$/\\1 \\2 \\3/p")
  [ -n "$run" ] || continue
  # shellcheck disable=SC2086 # three words, none with a blank
  set -- $run
  # A run line short of its shape is a run all the same: its
  # findings still want their answers.
  printf '%s\n' "$line" | grep -qE "$RUN" \
    || missing "the run line on $2 lacks what is left, ', <left>'"
  case $1 in [Gg][Ii][Tt][Hh][Uu][Bb]) continue ;; esac
  [ "$3" != no ] || continue
  clauses=$(printf '%s\n' "$line" | sed -E "s#$PLACE$ANSWER#&\\
#g" | grep -E "$PLACE$ANSWER\$")
  answered=$(printf '%s\n' "$clauses" \
    | sed -E 's#\): (P[0-3], )?class .*##; s#.*(; |\. | — )##' | sort -u | grep -c .)
  [ "$answered" -ge "$3" ] \
    || missing "the run on $2 has $3 findings, $answered answered as '$FORM'"
  printf '%s\n' "$clauses" | grep -qE '\): P[01], class ' && HIGH=${HIGH:-$2}
  FIXES="$FIXES$(printf '%s\n' "$clauses" \
    | sed -nE "s#.*\\): (P([0-3]), )?class .*, fixed in \`?([0-9a-f]{7,40})\$#$2 P\\2 \\3#p")
"
done <<EOF
$REVIEW
EOF

# tier <old> <new> -- the tier of the files between two commits, as
# scripts/review-tier.sh prints it; nothing where a commit cannot
# be read. Trees and names are all the tier reads, so no blob is
# fetched.
tier() {
  { git cat-file -e "$1^{commit}" && git cat-file -e "$2^{commit}"; } \
    2>/dev/null || git fetch -q --no-tags --depth=1 --filter=blob:none \
    origin "$1" "$2" 2>/dev/null
  sh "$(dirname "$0")/review-tier.sh" "$1" "$2" 2>/dev/null
}

# lightfix <new> <old> -- whether the fix line from <old> to <new>
# holds: <new> answers a finding of the local run on <old>, every
# finding of that run it answers names its priority and is a P2 or
# a P3, and it touches light-tier files only, which the two
# commits' trees tell.
lightfix() {
  prios=
  while read -r r p s; do
    [ "$r" = "$2" ] && [ -n "$s" ] || continue
    case $1 in "$s"*) prios="$prios$p
" ;; esac
  done <<EOF
$FIXES
EOF
  if [ -z "$prios" ]; then
    missing "no finding of a local run on $2 is answered 'fixed in'" \
      "$1, which the fix line between them needs"
    return 1
  fi
  if printf '%s\n' "$prios" | grep -qx P; then
    missing "a finding answered 'fixed in' $1 names no priority," \
      "'$FORM'"
    return 1
  fi
  if printf '%s\n' "$prios" | grep -qxE 'P[01]'; then
    missing "$1 fixes a P0 or P1: the next run is due"
    return 1
  fi
  # After the squash neither commit is on a branch any more; GitHub
  # still serves them by SHA, but no server has to, and where one
  # does not the line fails closed: the run it skipped is due.
  t=$(tier "$2" "$1") || {
    missing "the commits of the fix line on $1 cannot be read, so" \
      "what it changes is unknown: a run on the head is due"
    return 1
  }
  [ "$t" = light ] && return 0
  missing "$1 changes $(printf '%s\n' "$t" | sed -n 2p)," \
    "outside the light tier: the next run is due"
  return 1
}

# The head is covered when a run or a skip names it, or a rebase,
# squash or fix line leads to it from one that is, with its closing
# words.
covered() {
  c=$1 i=0
  while [ $i -lt 100 ]; do
    printf '%s\n%s\n' "$RUNS" "$SKIPS" | grep -qx "$c" && return 0
    step=$(printf '%s\n' "$REVIEW" \
      | sed -nE -e "s/^(rebase), $c: from ([0-9a-f]{40}), range-diff checked[[:space:]]*$/\\1 \\2/p" \
        -e "s/^(squash), $c: from ([0-9a-f]{40}), tree unchanged[[:space:]]*$/\\1 \\2/p" \
        -e "s/^(fix), $c: from ([0-9a-f]{40}), light fix checked by own review[[:space:]]*$/\\1 \\2/p" \
      | head -1)
    o=${step#* }
    case $step in
      '') return 1 ;;
      fix\ *) lightfix "$c" "$o" || return 1 ;;
    esac
    c=$o i=$((i + 1))
  done
  return 1
}
covered "$HEAD_SHA" \
  || missing "no run or skip line names the head $HEAD_SHA, and no" \
    "rebase, squash or fix line leads to it from one that does"

# ownreview -- the own review's line, `Own review: <tier> (<paths>),
# …` under ## Review, given the head's merge base: the last one
# counts. A record without a run line may leave it out: skip lines,
# each a person's decision, are then all of it, whether the pull
# request is a person's or an agent's skipped at capacity. `full`
# holds as written. `light` holds where the files between the merge
# base and the head are light and no local run found a P0 or P1, or
# where the line says the tier turned, `, full from round <n>` or
# `, full from <sha>`. A GitHub run's priorities are its threads,
# which this does not read.
OWN='Own review: <tier> (<paths>), …'
ownreview() {
  own=$(printf '%s\n' "$REVIEW" \
    | grep -E '^Own review: (light|full) \(' | tail -1)
  if [ -z "$own" ]; then
    [ -z "$RUNS" ] || missing "no own review line under ## Review, '$OWN'"
    return
  fi
  printf '%s\n' "$own" \
    | grep -qE '^Own review: full |, full from (round [0-9]+|`?[0-9a-f]{7,40})' \
    && return
  if [ -n "$HIGH" ]; then
    missing "the own review says light, and the run on $HIGH found a" \
      "P0 or P1: it turns full, '…, full from round <n>'"
    return
  fi
  t=$(tier "$BASE_SHA" "$HEAD_SHA") || {
    missing "the head $HEAD_SHA or its merge base $BASE_SHA cannot be" \
      "read, so the own review's tier cannot be held to the files"
    return
  }
  [ "$t" = light ] || missing "the own review says light, and the pull" \
    "request changes $(printf '%s\n' "$t" | sed -n 2p), outside the" \
    "light tier: it is full, or turned full, '…, full from <sha>'"
}
[ -z "$BASE_SHA" ] || ownreview

[ -z "$fail" ] || exit 1
echo "review record: the head $HEAD_SHA is covered"
