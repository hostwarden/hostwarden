# shellcheck shell=sh
# corpus.sh — the instruction corpus, defined once.
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead.
#
# Sourced by guard-taboos-test.sh and instructions-test.sh.
# Both walk the same tree for different reasons: one runs every
# fenced command block through the taboo guard, the other checks
# structure and example identifiers. Two lists drifted apart the
# moment there were two, so there is one.
#
# Expects CLAUDE_DIR (.../.claude) to be set. Defines:
#   CORPUS_ROOT   — the repository root, so a path printed in a
#                   failure reads the way a reader would write it
#   corpus_files  — prints every file in the corpus, one per line
#   FENCE_AWK     — the awk functions fenced() and commented(),
#                   below
#
# The corpus is what the repository ships, which is what git
# would carry: tracked files, plus files that are new and not
# ignored. Everything a user generates — server memory, their own
# overrides — is gitignored by construction, so it cannot wander
# in. Naming the directories instead meant a new one was outside
# every scan until somebody remembered to add it, and nothing
# failed while it was. This way a new file is covered the moment
# it exists, which is the moment its author runs the tests, and
# the list below is only what is genuinely not instruction text.

CORPUS_ROOT="$(cd "$CLAUDE_DIR/.." && pwd)"

# Binaries awk and grep cannot read, machine-read files that carry
# no prose, and `.claude/skills`, which is the symlink to
# `.agents/skills` and would scan that tree a second time.
#
# Anchored at the start of a repo-relative path, so a directory
# here takes its contents with it.
CORPUS_EXEMPT_RE='^(assets/|\.claude/skills$|\.claude/settings\.json$|\.gitattributes$|\.gitignore$|LICENSE$|VERSION$)'

corpus_files() {
  # A tree without git is a tree this cannot describe, and a
  # silently empty corpus is the failure both callers exist to
  # rule out — so say so and return nothing rather than pretend.
  if ! git -C "$CORPUS_ROOT" rev-parse --git-dir >/dev/null 2>&1
  then
    echo "corpus.sh: $CORPUS_ROOT is not a git checkout," \
      "so the instruction corpus cannot be listed" >&2
    return 1
  fi
  # --others --exclude-standard adds the files that are new and
  # not ignored: an instruction written this session is what the
  # author is about to run the tests over, and a scan that sees
  # it only once it is staged passes the one file nobody has
  # checked yet.
  #
  # quotePath=false so a non-ASCII name arrives as itself rather
  # than as git's \nnn escaping, and the root is prefixed through
  # ENVIRON rather than a sed replacement, where a checkout path
  # containing & or # would be read as syntax and every path the
  # scan produced would name a file that does not exist.
  git -C "$CORPUS_ROOT" -c core.quotePath=false ls-files \
    --cached --others --exclude-standard \
    | grep -vE "$CORPUS_EXEMPT_RE" \
    | CORPUS_ROOT="$CORPUS_ROOT" awk \
      '{ print ENVIRON["CORPUS_ROOT"] "/" $0 }'
}

# fenced(line) -- awk: whether a line opens, sits in or closes a
# fenced block. Inside one, a `#` line is a shell comment rather
# than a heading, and a long line is a command rather than prose;
# the guard matrix runs what the blocks hold through the guard. As
# in Markdown, only a run of the opener's character at least as
# long, and nothing after it, closes the block: a four-backtick
# fence that shows a three-backtick example stays open across it.
# FM holds the open marker; reset it per file.
# shellcheck disable=SC2034 # read by the scripts that source this
FENCE_AWK='
function fenced(l,   m) {
  m = l; sub(/^[ \t]*/, "", m); sub(/[ \t]+$/, "", m)
  if (FM == "") {
    if (!match(m, /^(```+|~~~+)/)) return 0
    FM = substr(m, 1, RLENGTH)
  } else if (m ~ /^(`+|~+)$/ && index(m, FM) == 1) FM = ""
  return 1
}
# commented(l) -- whether line l opens or sits inside an HTML
# comment: a <!-- outside a fence, at most three spaces in (four
# make it code), up to the line that holds -->. Call it before
# fenced(). CM holds the state; reset it with FM.
function commented(l) {
  if (CM == "" && FM == "" && l ~ /^ ? ? ?<!--/) CM = 1
  if (CM == "") return 0
  if (l ~ /-->/) CM = ""
  return 1
}'
