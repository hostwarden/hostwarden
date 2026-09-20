# corpus.sh — the instruction corpus, defined once.
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
#   CORPUS_DIRS   — directories and files to walk
#   corpus_files  — prints every file in them, one per line
#
# A path that does not exist yet is dropped rather than passed
# to find, which fails on a missing argument and would take the
# whole matrix down with it.

CORPUS_ROOT="$(cd "$CLAUDE_DIR/.." && pwd)"

CORPUS_DIRS=""
for _p in .agents rules contrib .github \
          .claude/rules .claude/agents .claude/hooks \
          AGENTS.md CLAUDE.md README.md CHANGELOG.md; do
  [ -e "$CORPUS_ROOT/$_p" ] &&
    CORPUS_DIRS="$CORPUS_DIRS $CORPUS_ROOT/$_p"
done
unset _p

corpus_files() {
  # shellcheck disable=SC2086
  find $CORPUS_DIRS -type f 2>/dev/null
}
