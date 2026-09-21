#!/bin/sh
# check.sh — everything CI checks, in one place.
#
#   sh scripts/check.sh               every check, as CI runs it
#   sh scripts/check.sh --pre-commit  the staged changes' secret scan
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

step "guard matrix" sh .claude/hooks/guard-taboos-test.sh
step "instruction layout" sh .claude/hooks/instructions-test.sh
step "JSON" json_valid
step "shell syntax" sh_syntax
# shellcheck disable=SC2046 # one argument per file is the point
step "ShellCheck" shellcheck -S warning $(shell_files)
step "workflows" actionlint
# The whole history, not the working tree: a secret that was
# committed and deleted again is still published by the next push.
step "secrets" betterleaks git --redact --verbose --no-banner .

if [ -n "$failed" ]; then
  echo "check: failed:$failed"
  exit 1
fi
echo "check: all passed"
