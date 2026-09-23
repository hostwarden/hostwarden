#!/bin/sh
# SessionStart hook: keep an operations install up to date
# through bin/hostwarden-update — main, or the release line the
# checkout follows — and say what changed. A pin, another
# branch and HOSTWARDEN_NO_UPDATE=1 leave it alone.

if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR" || exit 0
fi

# Opt-out via environment variable. HEINZEL_NO_UPDATE
# is the name from before the rename and still works.
if [ "$HOSTWARDEN_NO_UPDATE" = "1" ] || [ "${HEINZEL_NO_UPDATE:-}" = "1" ]; then
  echo "hostwarden auto-update disabled (HOSTWARDEN_NO_UPDATE=1)"
  exit 0
fi

# Only an operations install follows main. A development
# checkout moves by its own branches and pull requests, and a
# pull on its main would only surprise whoever works there
# (.claude/hooks/mode.sh).
# shellcheck source=mode.sh
. "${0%/*}/mode.sh"
hostwarden_mode "${0%/*}/../.."
[ "$HOSTWARDEN_MODE" = operations ] || exit 0

# bin/hostwarden-doctor, beside this hook, reports a missing git.
command -v git >/dev/null 2>&1 || exit 0
# shellcheck source=follow.sh
. "${0%/*}/follow.sh"
if ! hostwarden_clone_top; then
  echo "hostwarden: this is not a git clone (an archive" \
    "download?), so no update check — clone the repository" \
    "to get updates"
  exit 0
fi

# Never hang the SessionStart hook on a prompt (HTTPS remote with
# an expired token, an unknown host key). Fail fast instead and let
# the user fix it.
hostwarden_git_batch .
GIT_ASKPASS=${GIT_ASKPASS:-true}
export GIT_ASKPASS

# A pin or another branch is the user's choice and stays; a
# release line moves the checkout off whatever it is on.
if [ -z "$(hostwarden_follow)" ]; then
  if ! BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null); then
    if TAG=$(git describe --tags --exact-match 2>/dev/null); then
      echo "hostwarden pinned to $TAG — skipping auto-update"
    else
      echo "hostwarden on detached HEAD — skipping auto-update"
    fi
    exit 0
  fi
  if [ "$BRANCH" != "main" ]; then
    echo "hostwarden on branch '$BRANCH' — skipping auto-update"
    exit 0
  fi
fi

# bin/hostwarden-update does the update — pull or tag, migration,
# changelog. This hook only keeps quiet when nothing moved.
BEFORE=$(git rev-parse HEAD)
if ! OUTPUT=$(sh bin/hostwarden-update 2>&1); then
  echo "hostwarden auto-update failed:"
  printf '%s\n' "$OUTPUT" | sed 's/^/  /'
elif [ "$(git rev-parse HEAD)" != "$BEFORE" ]; then
  printf '%s\n' "$OUTPUT"
fi
