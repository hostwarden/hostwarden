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

case "${1:-}" in
  --pre-commit)
    # Only betterleaks: a commit must not wait on tools it does not
    # run.
    command -v betterleaks >/dev/null 2>&1 || {
      echo "check: betterleaks is missing — sh bin/hostwarden-doctor" \
        "--dev says how to install it" >&2
      exit 2
    }
    exec betterleaks git --pre-commit --staged --redact --verbose \
      --no-banner . ;;
esac

# Which tools there are, and how to install the rest, is the
# doctor's to say.
# A doctor that fails to run at all must not read as nothing missing.
missing=$(sh bin/hostwarden-doctor --dev --quiet) || exit 2
[ -z "$missing" ] || { printf '%s\n' "$missing" >&2; exit 2; }

# --pre-push skips the one slow step, the guard matrix, when the
# pushed commits touch nothing it reads. CI runs everything.
PUSHED='' ALL='' TIPS=''
if [ "${1:-}" = "--pre-push" ]; then
  # One line per ref: <local ref> <sha> <remote ref> <sha>.
  while read -r _ lsha _ rsha; do
    case $lsha in *[!0]*) ;; *) continue ;; esac # a deletion
    TIPS="$TIPS $lsha"
    if git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      PUSHED="$PUSHED $rsha..$lsha"
    else
      # A new ref, or a remote tip never fetched here: what the
      # destination lacks is not knowable from local refs, which
      # may be stale. Run everything.
      ALL=1
    fi
  done
  [ -n "$PUSHED$ALL" ] || exit 0
fi

# pushed_files -- every file the pushed commits touch; -m shows a
# merge's own changes too, conflict resolutions included.
pushed_files() {
  # shellcheck disable=SC2086 # one range per word
  for r in $PUSHED; do git log -m --name-only --format= "$r" || exit 1; done
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
if [ -n "$PUSHED" ] && [ -z "$ALL" ] && ! pushed_files \
    | grep -v '^CHANGELOG\.md$' \
    | grep -qE '\.md$|^\.claude/(hooks/|settings\.json$)'
then
  echo "== guard matrix: nothing it reads is pushed, skipped"
else
  step "guard matrix" sh .claude/hooks/guard-taboos-test.sh
fi
# The mode matrix exercises the mode hooks and the scripts that
# make and keep a workspace, in throwaway checkouts.
if [ -n "$PUSHED" ] && [ -z "$ALL" ] && ! pushed_files \
    | grep -qE '^\.claude/hooks/|^bin/|^templates/workspace/'
then
  echo "== mode matrix: nothing it reads is pushed, skipped"
else
  step "mode matrix" sh .claude/hooks/guard-mode-test.sh
fi
step "instruction layout" sh .claude/hooks/instructions-test.sh
step "JSON" json_valid
step "shell syntax" sh_syntax
# shellcheck disable=SC2046 # one argument per file is the point
step "ShellCheck" shellcheck -S warning $(shell_files)
step "workflows" actionlint
# The whole history of what is published: a secret committed and
# deleted again still goes out with it. That is HEAD's history, or
# the pushed tips' before a push -- not every ref this clone has,
# since other people's branches are theirs to answer for, and CI
# fetches them all.
step "secrets" betterleaks git --log-opts="${TIPS:-HEAD}" --redact \
  --verbose --no-banner .

if [ -n "$failed" ]; then
  echo "check: failed:$failed"
  exit 1
fi
echo "check: all passed"
