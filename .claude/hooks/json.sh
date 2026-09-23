# shellcheck shell=sh
# json.sh — the hook input read as text, and a hook's decision
# written, defined once for every hook that does either.
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead. Defining
# the functions starts no process; the guards source it on every
# tool call.
#
#   hook_field <key> [class]
#                  — prints the value of "key":"value" in $INPUT, the
#                    hook's JSON input, when the value consists of
#                    [class] alone ([^"\\] without one: no quote and
#                    no escape). Nothing otherwise. For a hook that
#                    cannot assume jq, or a key read before jq runs.
#   hook_session_id
#                  — prints the session id, letters, digits, _ and -
#                    only, so it is safe in a file name.
#                    check-session.sh names the guard-off-<id> record
#                    with it and guard-taboos.sh looks the record up
#                    with it, so the two never read different ids.
#   hook_decision <deny|ask> <reason>
#   hook_deny <reason>
#                  — prints the PreToolUse decision and exits 0. The
#                    reason is escaped for JSON here: a quote or a
#                    backslash is escaped, a control character becomes
#                    a space. A reason with none of them is printed as
#                    it is, without a process.

# Read as text with sed: a key occurs once in the input, a quote
# inside a string value is escaped, and a value with an escape in
# it is left unread unless the class allows one. The first line on
# which the key has such a value decides, and on that line its last
# occurrence, which in Claude Code's one-line input is the only one.
hook_field() {
  hf_c=${2-}
  [ -n "$hf_c" ] || hf_c='[^"\\]'
  printf '%s' "$INPUT" | sed -n \
    "/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\($hf_c*\\)\".*/{s//\\1/p;q;}"
}

hook_session_id() {
  hook_field session_id '[A-Za-z0-9_-]'
}

hook_decision() {
  hd_r=$2
  case $hd_r in
  *\\*|*\"*|*[[:cntrl:]]*)
    hd_r=$(printf '%s' "$hd_r" | tr '\001-\037' ' ' \
      | sed 's/\\/\\\\/g; s/"/\\"/g') ;;
  esac
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"%s",' "$1"
  printf '"permissionDecisionReason":"%s"}}\n' "$hd_r"
  exit 0
}

hook_deny() {
  hook_decision deny "$1"
}
