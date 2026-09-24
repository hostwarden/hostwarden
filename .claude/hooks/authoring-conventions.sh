#!/bin/sh
# authoring-conventions.sh — name the authoring rules and the
# changelog policy when an instruction file, a bin/ script or the
# lib/ it reads is edited. Neither loads by path from a read of
# those files.
#
# Registered as a PostToolUse hook on Edit|Write. Emits
# hookSpecificOutput.additionalContext, which that event honors.
#
# Why a hook and not a `paths` glob: .claude/rules/ files load
# when a matching file is *read*, and a glob cannot tell reading
# a rule in order to follow it on a production host from reading
# it in order to edit it. rules/** and .agents/skills/** are the
# product, so a glob over them would load authoring conventions
# into every sysadmin session — the exact cost the layout removes.
# An edit is unambiguous: nobody edits the product by accident.
#
# Once per session, not once per edit. The pointer is worth
# saying; saying it after every Edit call is noise, and noise is
# what gets instructions ignored.

ROOT=$(cd "${0%/*}/../.." && pwd)

# shellcheck disable=SC2034 # read by hook_field in json.sh
INPUT=$(cat)
# The fields are read as text (json.sh), because a workstation is
# whatever the user runs Hostwarden from and this hook may not assume
# jq or python3 is on it; a hook whose whole job is to speak up must
# not fall silent where they are missing. A path carrying an escape
# is one no case below matches anyway.
# shellcheck source=json.sh
. "$ROOT/.claude/hooks/json.sh"

FILE=$(hook_field file_path '[^"]')
[ -n "$FILE" ] || exit 0

# Repo-relative, so a path outside the project cannot match.
case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}" ;;
  *) exit 0 ;;
esac

case "$REL" in
  rules/*.md|.agents/skills/*|bin/*|lib/*) ;;
  *) exit 0 ;;
esac

# Session-scoped marker, in the directory a SessionStart hook
# creates with mode 0700; the id is letters, digits, _ and - or
# nothing, so it is safe as a file name. A session id the harness
# did not send means no dedup is possible, and saying it once too
# often beats not saying it at all — so does a marker that cannot
# be written.
SESSION=$(hook_session_id)
if [ -n "$SESSION" ]; then
  MARK="$HOME/.cache/hostwarden/authoring-$SESSION"
  [ -e "$MARK" ] && exit 0
  # shellcheck disable=SC2174 # 0700 is for the last directory alone
  { : > "$MARK"; } 2>/dev/null \
    || { mkdir -p -m 700 "${MARK%/*}" && : > "$MARK"; } 2>/dev/null
  # Markers of sessions long gone; once per session, so it costs
  # the edits after the first nothing.
  find "${MARK%/*}" -name 'authoring-*' -mtime +2 -exec rm -f {} + \
    2>/dev/null
fi

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "You are changing Hostwarden itself: its instruction set is the product, and `bin/` ships with it. `.claude/rules/instruction-authoring.md` carries the conventions: which mechanism a new instruction belongs to, current state only (no before/after narration), 80-character wrapping, and example identifiers from RFC 2606/5737/3849 with Alice and Bob for people. A user-visible change also gets its changelog entry as a fragment in `changelog.d/`, never an addition to `CHANGELOG.md`, written as `.claude/rules/repo-release.md` → CHANGELOG.md says. CI checks the mechanical half through `scripts/check.sh`; locally run only `--pre-commit`, and no test script on its own (`.claude/rules/pull-requests.md` → Checks). Said once per session."
  }
}
JSON
