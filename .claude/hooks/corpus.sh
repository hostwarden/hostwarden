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
#
# A path that does not exist yet is dropped rather than passed
# to find, which fails on a missing argument and would take the
# whole matrix down with it.

CORPUS_ROOT="$(cd "$CLAUDE_DIR/.." && pwd)"

# Held as positional parameters inside corpus_files rather than
# a space-joined string: a checkout under a path with a space in
# it would otherwise split into arguments find cannot resolve,
# and every scan would silently cover nothing.
CORPUS_PATHS=".agents rules contrib .github
.claude/rules .claude/agents .claude/hooks
AGENTS.md CLAUDE.md README.md CHANGELOG.md"

corpus_files() {
  set --
  for _p in $CORPUS_PATHS; do
    [ -e "$CORPUS_ROOT/$_p" ] && set -- "$@" "$CORPUS_ROOT/$_p"
  done
  [ "$#" -gt 0 ] || return 0
  find "$@" -type f 2>/dev/null
}
