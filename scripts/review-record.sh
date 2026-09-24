#!/bin/sh
# review-record.sh — whether a pull request body records the second
# review of its head, as .claude/rules/pull-requests.md → The review
# record says.
#
#   sh scripts/review-record.sh <head sha> < <body>
#
# Exits 0 when the record is there, 1 with what is missing, 2 on a
# usage error. It proves the record exists, not that the review was
# any good. The review-record workflow runs it, the default
# branch's copy, on a pull request that is not a draft.

[ $# -eq 1 ] && printf '%s\n' "$1" | grep -qxE '[0-9a-f]{40}' || {
  echo "usage: sh scripts/review-record.sh <full head sha> < <body>" >&2
  exit 2
}
HEAD_SHA=$1

# A body edited in the browser arrives with CRLF line ends.
BODY=$(tr -d '\r')

# section <title> -- the lines a reader sees as text under the
# heading `## <title>`, up to the next heading of level one or two.
# The body is read as CommonMark 0.31.2 reads its blocks, tabs
# stopping every four columns: only a paragraph's lines count, in a
# list item or not. A code block, fenced or indented, a block quote,
# an HTML block and an HTML comment are examples, not the record.
# A heading nested in a list item or a quote is nested text and
# starts or ends nothing; only one outside every container does.
# Where the reading is in doubt — a setext heading, a paragraph
# that opens like a link reference definition — the lines are left
# out, and a top-level setext heading still ends the section, since
# it can never carry the `## <title>` that would reopen one.
section() {
  printf '%s\n' "$BODY" | awk -v h="$1" '
    BEGIN {
      N = 0; LEAF = ""; ON = 0; PN = 0
      TAGS = "address|article|aside|base|basefont|blockquote|body|" \
        "caption|center|col|colgroup|dd|details|dialog|dir|div|dl|" \
        "dt|fieldset|figcaption|figure|footer|form|frame|frameset|" \
        "h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|" \
        "link|main|menu|menuitem|nav|noframes|ol|optgroup|option|" \
        "p|param|search|section|summary|table|tbody|td|tfoot|th|" \
        "thead|title|tr|track|ul"
      # An attribute value is unquoted (no space, quote, =, <, >,
      # backtick), single- or double-quoted (any character but the
      # quote itself — so a quoted value may hold a bare > or <).
      SQ = "\047"
      VAL = "([^ \t\"" SQ "=<>`]+|" SQ "[^" SQ "]*" SQ "|\"[^\"]*\")"
      ATTR = "[ \t]+[a-z_:][a-z0-9_.:-]*([ \t]*=[ \t]*" VAL ")?"
      OPEN7 = "^<[a-z][a-z0-9-]*(" ATTR ")*[ \t]*/?>[ \t]*$"
      CLOSE7 = "^</[a-z][a-z0-9-]*[ \t]*>[ \t]*$"
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
    function expand(s,   o, i, c, col) {
      if (index(s, "\t") == 0) return s
      o = ""; col = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c != "\t") { o = o c; col++; continue }
        do { o = o " "; col++ } while (col % 4)
      }
      return o
    }
    # scan() -- from POS: NN the first non-blank, IND the columns
    # before it, BLANK whether the rest of the line is empty.
    function scan() {
      NN = POS
      while (NN <= L && substr(LN, NN, 1) == " ") NN++
      IND = NN - POS; BLANK = (NN > L)
    }
    function run(s, i, c,   k) {
      k = 0
      while (substr(s, i + k, 1) == c) k++
      return k
    }
    function quoted(   i) {
      for (i = 1; i <= N; i++) if (CT[i] == "q") return 1
      return 0
    }
    function closeleaf() { if (LEAF == "p") emit(); LEAF = "" }
    # open(m) -- close the current leaf, drop the container stack to
    # depth m, and mark the list item now on top as holding a block
    # after a blank line, where it is one.
    function open(m) {
      closeleaf(); N = m
      if (N && CT[N] == "l") HAS[N] = 1
    }
    # heading(level, title) -- only one outside every container
    # starts or ends a section; one in a list item or a quote is
    # nested text and touches nothing.
    function heading(lv, t) {
      if (N || lv > 2) return
      ON = (lv == 2 && t == h)
    }
    function nl(t,   x) { x = t; gsub(/[^\n]/, "", x); return x }
    # emit() -- a closed paragraph, its HTML comments and any
    # complete link reference definitions at its start taken out,
    # line by line; none of it where the paragraph was quoted.
    function emit(   s, o, i, n, e, a, skip) {
      if (!ON || quoted()) { PN = 0; return }
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
    function hstart(r, para,   l) {
      l = tolower(r)
      if (l ~ /^<(script|pre|textarea|style)([ >]|$)/) return 1
      if (substr(r, 1, 4) == "<!--") return 2
      if (substr(r, 1, 2) == "<?") return 3
      if (substr(r, 1, 9) == "<![CDATA[") return 5
      if (r ~ /^<![A-Za-z]/) return 4
      if (l ~ ("^</?(" TAGS ")([ >]|/>|$)")) return 6
      if (para) return 0
      if (l ~ OPEN7 || l ~ CLOSE7) return 7
      return 0
    }
    function hend(r) {
      if (HT == 1) return tolower(r) ~ /<\/(script|pre|textarea|style)>/
      if (HT == 2) return index(r, "-->")
      if (HT == 3) return index(r, "?>")
      if (HT == 4) return index(r, ">")
      if (HT == 5) return index(r, "]]>")
      return 0
    }
    {
      LN = expand($0); L = length(LN); POS = 1; M = 0
      # The open containers this line continues: a quote by its `>`,
      # a list item by its indentation or a blank line.
      for (i = 1; i <= N; i++) {
        scan()
        if (CT[i] == "q") {
          if (IND > 3 || substr(LN, NN, 1) != ">") break
          POS = NN + 1
          if (substr(LN, POS, 1) == " ") POS++
        } else if (BLANK) {
          if (!HAS[i]) break
          POS = NN
        } else if (IND >= CW[i]) POS += CW[i]
        else break
        M = i
      }
      scan()
      if (M == N) {
        if (LEAF == "f") {
          if (IND <= 3 && (k = run(LN, NN, FC)) >= FL \
            && substr(LN, NN + k) ~ /^ *$/) LEAF = ""
          next
        }
        if (LEAF == "i") {
          if (IND >= 4 || BLANK) next
          LEAF = ""
        }
        if (LEAF == "h") {
          if (BLANK && HT >= 6) LEAF = ""
          else { if (hend(substr(LN, POS))) LEAF = ""; next }
        }
      }
      # The blocks this line opens, containers first.
      while (1) {
        scan()
        para = (M == N && LEAF == "p")
        if (IND >= 4) {
          if (LEAF == "p" || BLANK) break
          open(M); LEAF = "i"; next
        }
        r = substr(LN, NN); c = substr(r, 1, 1)
        if (c == ">") {
          open(M)
          CT[++N] = "q"; M = N; POS = NN + 1
          if (substr(LN, POS, 1) == " ") POS++
          continue
        }
        if (c == "#" && (k = run(r, 1, "#")) <= 6 \
          && (k == length(r) || substr(r, k + 1, 1) == " ")) {
          open(M)
          t = substr(r, k + 1); sub(/^ +/, "", t); sub(/ +$/, "", t)
          if (t ~ /^#+$/) t = ""
          else { sub(/ #+$/, "", t); sub(/ +$/, "", t) }
          heading(k, t); next
        }
        if ((c == "`" || c == "~") && (k = run(r, 1, c)) >= 3 \
          && !(c == "`" && index(substr(r, k + 1), "`"))) {
          open(M); LEAF = "f"; FC = c; FL = k; next
        }
        if (c == "<" && (t = hstart(r, para))) {
          open(M); LEAF = "h"; HT = t
          if (hend(r)) LEAF = ""
          next
        }
        if (para && r ~ /^(=+|-+) *$/) {
          PN = 0; LEAF = ""; heading(c == "=" ? 1 : 2, ""); next
        }
        t = r; gsub(/ /, "", t)
        if (t ~ /^(\*\*\*+|---+|___+)$/) {
          open(M); next
        }
        if (c == "-" || c == "+" || c == "*") { mw = 1; num = 1 }
        else if (match(r, /^[0-9]+[.)]/) && RLENGTH <= 10) {
          mw = RLENGTH; num = substr(r, 1, mw - 1) + 0
        } else break
        t = substr(r, mw + 1)
        if (t != "" && substr(t, 1, 1) != " ") break
        s = run(t, 1, " ")
        if (para && (s == length(t) || num != 1)) break
        pad = (s == length(t) || s >= 5) ? mw + 1 : mw + s
        open(M)
        CT[++N] = "l"; CW[N] = IND + pad; HAS[N] = 0; M = N
        POS = NN + pad
      }
      # What is left is a blank line or a paragraph line, perhaps
      # one continuing a paragraph in a container it did not match.
      # The while loop above already scanned it: every path out of
      # that loop leaves POS where its own last scan() found it.
      if (BLANK) { open(M); next }
      if (LEAF == "p") { P[++PN] = substr(LN, NN); next }
      open(M)
      LEAF = "p"; PN = 1; P[1] = substr(LN, NN)
    }
    END { open(0) }'
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
# `<title> (<path:line>): class <n>, <answer>` each, told apart by
# title and place: the line is cut after each answer, and a clause
# starts after the last `; `, `. ` or ` — ` before its place. A
# GitHub run's answers are its threads, which this does not read.
PLACE='\([^()]*:[0-9]+(-[0-9]+)?\): class [0-9]+(/[0-9]+)*, '
ANSWER='(fixed in `?[0-9a-f]{7,40}|not a bug: |deferred to a follow-up PR)'
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
  answered=$(printf '%s\n' "$line" | sed -E "s#$PLACE$ANSWER#&\\
#g" | grep -E "$PLACE$ANSWER\$" \
    | sed -E 's#\): class .*##; s#.*(; |\. | — )##' | sort -u | grep -c .)
  [ "$answered" -ge "$3" ] \
    || missing "the run on $2 has $3 findings, $answered answered"
done <<EOF
$REVIEW
EOF

# The head is covered when a run or a skip names it, or a rebase or
# squash line leads to it from one that is, with its closing words.
covered() {
  c=$1 i=0
  while [ $i -lt 100 ]; do
    printf '%s\n%s\n' "$RUNS" "$SKIPS" | grep -qx "$c" && return 0
    c=$(printf '%s\n' "$REVIEW" \
      | sed -nE -e "s/^rebase, $c: from ([0-9a-f]{40}), range-diff checked[[:space:]]*$/\\1/p" \
        -e "s/^squash, $c: from ([0-9a-f]{40}), tree unchanged[[:space:]]*$/\\1/p" \
      | head -1)
    [ -n "$c" ] || return 1
    i=$((i + 1))
  done
  return 1
}
covered "$HEAD_SHA" \
  || missing "no run or skip line names the head $HEAD_SHA, and no" \
    "rebase or squash line leads to it from one that does"

[ -z "$fail" ] || exit 1
echo "review record: the head $HEAD_SHA is covered"
