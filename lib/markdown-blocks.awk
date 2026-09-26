# markdown-blocks.awk — a Markdown document's blocks, read as
# CommonMark 0.31.2 reads them, tabs stopping every four columns, in
# awk that BWK awk, gawk, mawk and busybox all run. One addition,
# only where the caller sets ADMON: a line that starts with `:::`,
# the fence of a Docusaurus admonition such as `:::warning` or its
# bare closing `:::`, is a block of its own that ends a paragraph,
# never a line of one. The one reader of scripts/review-record.sh
# and bin/hostwarden-wrap: each runs it with its own program after
# it, as one program text.
#
# The caller's main rule calls block() for each line of the
# document, and blocks_end() once the document is over, which
# closes what is open and leaves the reader ready for the next.
# block() calls back what the caller defines:
#
#   on_para(lazy)    a line of a paragraph: LN is the line with its
#                    tabs expanded, NN where its text starts. lazy is
#                    1 where it continues the paragraph in a
#                    container whose marker it lacks.
#   on_para_end(setext)
#                    the paragraph is closed; setext is 1 where an
#                    underline made it a heading's text, and
#                    on_heading follows.
#   on_heading(level, text)
#                    a heading: an ATX one with its text, or a
#                    setext underline, whose text is "".
#   on_other(kind)   any other line: "f" fenced code, its fences
#                    included, "i" indented code, "h" an HTML block,
#                    "t" a thematic break, "d" an admonition fence
#                    where ADMON is set, "b" a blank line.
#
# N is the depth of containers the line is in, CT[1..N] their kinds,
# "q" a block quote and "l" a list item, and CW[i] a list item's
# width; a hook reads them, and changes none of the reader's state.

BEGIN {
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
  N = 0; LEAF = ""
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
function closeleaf() { if (LEAF == "p") on_para_end(0); LEAF = "" }
# open(m) -- close the current leaf, drop the container stack to
# depth m, and mark the list item now on top as holding a block
# after a blank line, where it is one.
function open(m) {
  closeleaf(); N = m
  if (N && CT[N] == "l") HAS[N] = 1
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
function blocks_end() { open(0) }
# block() -- the current line, $0.
function block(   i, k, t, r, c, s, mw, num, pad, para) {
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
      on_other("f"); return
    }
    if (LEAF == "i") {
      if (IND >= 4 || BLANK) { on_other("i"); return }
      LEAF = ""
    }
    if (LEAF == "h") {
      if (BLANK && HT >= 6) LEAF = ""
      else { if (hend(substr(LN, POS))) LEAF = ""; on_other("h"); return }
    }
  }
  # The blocks this line opens, containers first.
  while (1) {
    scan()
    para = (M == N && LEAF == "p")
    if (IND >= 4) {
      if (LEAF == "p" || BLANK) break
      open(M); LEAF = "i"; on_other("i"); return
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
      on_heading(k, t); return
    }
    if ((c == "`" || c == "~") && (k = run(r, 1, c)) >= 3 \
      && !(c == "`" && index(substr(r, k + 1), "`"))) {
      open(M); LEAF = "f"; FC = c; FL = k; on_other("f"); return
    }
    if (ADMON && c == ":" && substr(r, 1, 3) == ":::") {
      open(M); on_other("d"); return
    }
    if (c == "<" && (t = hstart(r, para))) {
      open(M); LEAF = "h"; HT = t
      if (hend(r)) LEAF = ""
      on_other("h"); return
    }
    if (para && r ~ /^(=+|-+) *$/) {
      on_para_end(1); LEAF = ""; on_heading(c == "=" ? 1 : 2, ""); return
    }
    t = r; gsub(/ /, "", t)
    if (t ~ /^(\*\*\*+|---+|___+)$/) {
      open(M); on_other("t"); return
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
  if (BLANK) { open(M); on_other("b"); return }
  if (LEAF == "p") { on_para(M < N); return }
  open(M)
  LEAF = "p"; on_para(0)
}
