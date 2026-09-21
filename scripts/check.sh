#!/bin/sh
# check.sh — everything CI checks, in one place.
#
#   sh scripts/check.sh
#
# CI runs this file and nothing else, so a green run here is a
# green run there. A step added to the workflow instead of here is
# a step nobody runs before pushing, and the first to hear of it
# is CI after the merge.
#
# Every step runs even after one fails, so a single run lists all
# of what is wrong; the exit code is 1 if any step failed.
#
# The tools it needs are pinned in mise.dev.toml, which CI
# installs from. Locally any recent version will do. A missing
# tool fails the run instead of skipping its step: a check that
# quietly did not happen reads exactly like one that passed.

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel) || {
  echo "check: not inside a git checkout" >&2
  exit 2
}
cd "$ROOT" || exit 2

missing=
for t in python3 shellcheck actionlint betterleaks; do
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done
if [ -n "$missing" ]; then
  echo "check: missing:$missing" >&2
  echo "  with mise:     MISE_ENV=dev mise install" >&2
  echo "  with Homebrew: brew install shellcheck actionlint" \
    "betterleaks" >&2
  exit 2
fi

failed=
step() {
  # step <name> <command...>
  echo "== $1"
  name=$1
  shift
  "$@" || failed="$failed
  $name"
}

json_valid() {
  git ls-files '*.json' | while read -r f; do
    python3 -m json.tool "$f" >/dev/null || { echo "  $f"; exit 1; }
  done
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
