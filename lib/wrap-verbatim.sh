# shellcheck shell=sh
# wrap-verbatim.sh — the workspace's Markdown whose bytes are a copy,
# which neither bin/hostwarden-wrap --changed nor
# .claude/hooks/wrap-markdown.sh rewraps or lists. Sourced, never
# run.
#
#   machines|fleet|clusters/<name>/files/…  a master: exactly the
#                                           bytes the host has
#   machines|fleet|clusters/<name>/src/…    what renders one, but
#                                           a host's
#                                           src/<name>/README.md,
#                                           which Hostwarden writes
#   machines/<host>/notes/…                 evidence
#   machines/<host>/heinzel-memory.md       Heinzel's memory, byte
#                                           for byte until the
#                                           host's first connection
#
# and, in a host directory that still holds heinzel-memory.md,
# everything but the files Hostwarden writes there: until the
# takeover's step 6 sorts them, Heinzel's copies — READMEs, notes,
# plans, configs — sit there as they came
# (.claude/skills/hostwarden-heinzel-takeover/references/masters.md).
# A file of Hostwarden's missed below is only wrapped later, once
# the first connection has deleted heinzel-memory.md.

# wrap_verbatim <workspace> <path> -- 0 when <path>, relative to the
# workspace's top <workspace>, is one of them.
wrap_verbatim() {
  case $2 in
    machines/*/*|fleet/*/*|clusters/*/*) ;;
    *) return 1 ;;
  esac
  _wv_rest=${2#*/}
  _wv_name=${_wv_rest%%/*}
  _wv_rest=${_wv_rest#*/}
  case $_wv_rest in
    files/*|src/*/*/*) return 0 ;;
    # A host's src/<name>/ has its README.md from Hostwarden; a fleet
    # artifact's or a cluster's sits beside src/ instead.
    src/*/README.md) [ "${2%%/*}" != machines ]; return ;;
    src/*) return 0 ;;
  esac
  case $2 in machines/*) ;; *) return 1 ;; esac
  case $_wv_rest in
    heinzel-memory.md|notes/*) return 0 ;;
  esac
  [ -e "$1/machines/$_wv_name/heinzel-memory.md" ] || return 1
  case $_wv_rest in
    memory.md|rules.md|todo.md|decisions.md|decisions/*|guests.md \
      |storage.md|network.md|deployed.md|heinzel-inventory.md) return 1 ;;
  esac
  return 0
}
