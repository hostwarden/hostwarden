#!/bin/sh
# authoring-conventions.sh — name the authoring rules and the
# changelog policy when an instruction file or a bin/ script is
# edited. Neither loads by path from a read of those files.
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

INPUT=$(cat)

# field <key> <class> — the value of <key> in the hook's JSON input,
# if it consists of <class> alone. Read as text with sed, because a
# workstation is whatever the user runs Hostwarden from and this
# hook may not assume jq or python3 is on it; a hook whose whole
# job is to speak up must not fall silent where they are missing.
# Sound for the two keys asked for: `file_path` and `session_id`
# each occur once as a key, a quote inside a string value is
# escaped, and a path carrying an escape is one no case below
# matches anyway.
field() {
  printf '%s' "$INPUT" \
    | sed -n "s/.*\"$1\"[[:blank:]]*:[[:blank:]]*\"\($2*\)\".*/\1/p" \
    | head -1
}

FILE=$(field file_path '[^"]')
[ -n "$FILE" ] || exit 0

# Repo-relative, so a path outside the project cannot match.
case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}" ;;
  *) exit 0 ;;
esac

case "$REL" in
  rules/*.md|.agents/skills/*|bin/*) ;;
  *) exit 0 ;;
esac

# Session-scoped marker, in the directory a SessionStart hook
# creates with mode 0700; the id is letters, digits, _ and - or
# nothing, so it is safe as a file name. A session id the harness
# did not send means no dedup is possible, and saying it once too
# often beats not saying it at all — so does a marker that cannot
# be written.
SESSION=$(field session_id '[A-Za-z0-9_-]')
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
    "additionalContext": "You are changing Hostwarden itself: its instruction set is the product, and `bin/` ships with it. `.claude/rules/instruction-authoring.md` carries the conventions: which mechanism a new instruction belongs to, current state only (no before/after narration), 80-character wrapping, and example identifiers from RFC 2606/5737/3849 with Alice and Bob for people. Every change also gets one entry under `## Unreleased` in `CHANGELOG.md`, written as `.claude/rules/repo-release.md` says. Run `sh .claude/hooks/instructions-test.sh` and `sh .claude/hooks/guard-taboos-test.sh` before committing; they check the mechanical half. Said once per session."
  }
}
JSON
