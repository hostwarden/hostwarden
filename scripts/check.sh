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
  echo "check: missing:$missing — MISE_ENV=dev mise install" \
    "(mise.dev.toml pins them)" >&2
  exit 2
}

if [ "${1:-}" = "--pre-commit" ]; then
  need betterleaks
  exec betterleaks git --pre-commit --staged --redact --verbose \
    --no-banner .
fi
need python3 shellcheck actionlint betterleaks

# --pre-push narrows the two slow steps to what is being pushed:
# the guard matrix runs only when the push touches what it reads,
# and the secret scan reads only the commits the destination lacks.
# The rest costs a second or two and runs as always. CI runs it all.
PUSHED=
if [ "${1:-}" = "--pre-push" ]; then
  remote=${2:-origin}
  # git gives one line per ref: <local ref> <sha> <remote ref> <sha>
  while read -r _ lsha _ rsha; do
    case $lsha in *[!0]*) ;; *) continue ;; esac # a deletion
    # A new ref, or one whose remote tip was never fetched here:
    # every commit no ref of the destination has yet. Not what
    # origin/main lacks -- the destination may be another remote
    # that has less -- and not a range git log cannot resolve,
    # which would read as nothing pushed.
    if case $rsha in *[!0]*) false ;; esac \
      || ! git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      r="$lsha --not --remotes=$remote"
    else
      r="$rsha..$lsha"
    fi
    PUSHED="$PUSHED
$r"
  done
  [ -n "$PUSHED" ] || exit 0
fi

# each_push <command...> -- run once per pushed ref, with its
# git log arguments appended.
each_push() {
  printf '%s\n' "$PUSHED" | while read -r r; do
    [ -n "$r" ] || continue
    # shellcheck disable=SC2086 # the log arguments are several words
    "$@" $r || exit 1 # leaves the pipeline, which is the result
  done
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

# The matrix reads the hooks, settings.json, and the fenced blocks
# of every .md but CHANGELOG.md (corpus.sh).
if [ -n "$PUSHED" ] && ! each_push git log --name-only --format= \
    | grep -v '^CHANGELOG\.md$' \
    | grep -qE '\.md$|^\.claude/(hooks/|settings\.json$)'
then
  echo "== guard matrix: nothing it reads is pushed, skipped"
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
  if [ -z "$PUSHED" ]; then
    betterleaks git --redact --verbose --no-banner .
  else
    each_push leaks
  fi
}
leaks() { betterleaks git --log-opts="$*" --redact --verbose --no-banner .; }
step "secrets" secrets

if [ -n "$failed" ]; then
  echo "check: failed:$failed"
  exit 1
fi
echo "check: all passed"
