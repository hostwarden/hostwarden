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
#   hook_jq_from_mise <root>
#                  — puts the jq mise installed for the checkout in
#                    front of the PATH. Called right after this file
#                    is sourced by every hook that reads jq.

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

# The jq the hooks run is the one mise installed for this checkout,
# where there is one: pinned, so the guards read a tool call the same
# way on every workstation and in CI. session-mode.sh leaves its
# directory in <root>/.claude/mise-jq at every session start, a line
# `<data directory>:<jq directory>` per mise environment, since a
# hook cannot ask mise on every tool call. The data directory is the
# environment's own spelling (MISE_DATA_DIR, else XDG_DATA_HOME, else
# ~/.local/share/mise, without a trailing slash), which the hooks and
# the session start share, so no path is matched against another; a
# colon cannot be in either, as both go on a PATH. This reads the
# file with builtins alone and puts the first jq directory of its own
# environment that still holds a jq in front of the PATH. Without a
# usable file the jq the PATH has runs, but never through mise's
# shims: with the checkout's pin not installed a shim fails, and
# starts to install it in a hook that has 5 seconds and, on a
# timeout, lets the call through. The settings keep any other path
# to a shim from installing.
hook_jq_from_mise() {
  MISE_AUTO_INSTALL=0 MISE_EXEC_AUTO_INSTALL=0 MISE_NOT_FOUND_AUTO_INSTALL=0
  export MISE_AUTO_INSTALL MISE_EXEC_AUTO_INSTALL MISE_NOT_FOUND_AUTO_INSTALL
  hj_data=${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}
  hj_data=${hj_data%/}
  if [ -r "$1/.claude/mise-jq" ]; then
    while IFS= read -r hj_line; do
      hj_dir=${hj_line#*:}
      if [ "${hj_line%%:*}" = "$hj_data" ] && [ -x "$hj_dir/jq" ]; then
        PATH=$hj_dir:$PATH
        export PATH
        return 0
      fi
    done < "$1/.claude/mise-jq"
  fi
  hj_new='' hj_rest=$PATH:
  while [ -n "$hj_rest" ]; do
    hj_entry=${hj_rest%%:*}
    hj_rest=${hj_rest#*:}
    [ "$hj_entry" = "$hj_data/shims" ] ||
      [ "$hj_entry" = "${MISE_SHIMS_DIR:-}" ] ||
      hj_new=$hj_new${hj_new:+:}$hj_entry
  done
  PATH=$hj_new
  export PATH
}
