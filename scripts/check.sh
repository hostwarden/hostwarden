#!/bin/sh
# check.sh — everything CI checks, in one place.
#
#   sh scripts/check.sh               every check, as CI runs it
#   sh scripts/check.sh --pre-commit  the staged changes' secret scan
#   sh scripts/check.sh --pre-push    what the pushed commits need,
#                                     refs on stdin as git gives them
#
# CI runs this file and nothing else, so a green run here is a
# green run there. A check added to the workflow instead is first
# heard of after the merge. Every step runs even after one fails,
# so one run lists everything that is wrong.
#
# A missing tool fails the run instead of skipping its step: a
# check that quietly did not happen reads like one that passed.

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel) || {
  echo "check: not inside a git checkout" >&2
  exit 2
}
cd "$ROOT" || exit 2

# Tools installed from mise.dev.toml are on PATH only with
# MISE_ENV=dev; bring them in here, so no shell has to export it.
if command -v mise >/dev/null 2>&1; then
  eval "$(MISE_ENV=dev mise env -s bash 2>/dev/null)"
fi

need() {
  missing=
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
  done
  [ -z "$missing" ] && return
  echo "check: missing:$missing — MISE_ENV=dev mise install," \
    "or see CONTRIBUTING.md" >&2
  exit 2
}

if [ "${1:-}" = "--pre-commit" ]; then
  need betterleaks
  exec betterleaks git --pre-commit --staged --redact --verbose \
    --no-banner .
fi
need python3 shellcheck actionlint betterleaks

# --pre-push narrows the two slow steps to what is being pushed:
# the guard matrix runs only when the push touches what it covers,
# and the secret scan reads only the commits the remote lacks. The
# rest costs a second or two and runs as always. CI runs it all.
RANGES=
if [ "${1:-}" = "--pre-push" ]; then
  # git gives one line per ref: <local ref> <sha> <remote ref> <sha>
  while read -r _ lsha _ rsha; do
    case $lsha in *[!0]*) ;; *) continue ;; esac # a deletion
    case $rsha in
      *[!0]*) base=$rsha ;;
      *) base=$(git merge-base "$lsha" origin/main 2>/dev/null) ;;
    esac
    RANGES="$RANGES ${base:+$base..}$lsha"
  done
  [ -n "$RANGES" ] || exit 0
fi

# pushed_files -- every file the pushed commits touch.
pushed_files() {
  for r in $RANGES; do git log --name-only --format= "$r"; done
}

failed=
step() {
  name=$1
  shift
  echo "== $name"
  "$@" || failed="$failed
  $name"
}

json_valid() {
  rc=0
  for f in $(git ls-files '*.json'); do
    python3 -m json.tool "$f" >/dev/null || { echo "  $f"; rc=1; }
  done
  return $rc
}

# Every shell file the repository ships: the bin/ scripts carry
# no extension, the hooks and this directory do.
shell_files() {
  git ls-files 'bin/*' '.claude/hooks/*.sh' 'scripts/*.sh' \
    '.githooks/*'
}

sh_syntax() {
  rc=0
  for f in $(shell_files); do
    sh -n "$f" || { echo "  $f"; rc=1; }
  done
  return $rc
}

# The matrix runs the guard and every fenced block under rules/ and
# .agents/skills/ through it (corpus.sh).
if [ -n "$RANGES" ] && ! pushed_files | grep -qE \
    '^(\.claude/hooks/(guard-taboos|corpus)|rules/|\.agents/skills/)'
then
  echo "== guard matrix: nothing it covers is pushed, skipped"
else
  step "guard matrix" sh .claude/hooks/guard-taboos-test.sh
fi
step "instruction layout" sh .claude/hooks/instructions-test.sh
step "JSON" json_valid
step "shell syntax" sh_syntax
# shellcheck disable=SC2046 # one argument per file is the point
step "ShellCheck" shellcheck -S warning $(shell_files)
step "workflows" actionlint
# History, not the working tree: a secret committed and deleted
# again is still published by the push. All of it, or with
# --pre-push the commits being pushed.
secrets() {
  [ -n "$RANGES" ] || {
    betterleaks git --redact --verbose --no-banner .
    return
  }
  rc=0
  for r in $RANGES; do
    betterleaks git --log-opts="$r" --redact --verbose --no-banner . \
      || rc=1
  done
  return $rc
}
step "secrets" secrets

if [ -n "$failed" ]; then
  echo "check: failed:$failed"
  exit 1
fi
echo "check: all passed"
