# guard-taboos.d/lock.sh — the server lock, /etc/hostwarden.conf and
# /etc/heinzel.conf.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh

# --- The server lock ------------------------------------------
# The machine's owner writes it to keep every Hostwarden and
# Heinzel hands-off (rules/access-control.md -> Server Lock); a
# session that could flip it to true or delete it would make it
# worthless. Moving or deleting it lifts the lock as surely as
# writing true, so the write set is the sshd_config one plus touch: a
# redirect, sed -i, an editor, a delete, move or re-permission,
# a copy, touch or tee onto it, and find -delete, which deletes by
# a name it never spells as a path. Reading it (cat, grep, ls) stays
# allowed.
#
# Matched by the file name alone, in any case and after any path:
# the full path misses /ETC/HEINZEL.CONF on macOS, /etc// and
# /etc/./, and a relative name after cd /etc. A write to any file
# of that name is denied with it; a suffixed copy (hostwarden.conf.bak)
# is another file. The left edge keeps the
# sshd drop-in 10-hostwarden.conf a separate file. Not closable:
# a glob (/etc/heinzel.c*) or a name built at run time still gets
# through, so the written rule stays the first line of defence.
#
# The full scope only. A development checkout reaches no server,
# and this repository names the file in every commit message that
# touches the rule. The file tools are judged by edit.sh, in every
# scope.
LOCKNAME='([Hh][Oo][Ss][Tt][Ww][Aa][Rr][Dd][Ee][Nn]|[Hh][Ee][Ii][Nn][Zz][Ee][Ll])\.[Cc][Oo][Nn][Ff]'
LOCKFILE='(^|[^[:alnum:]_.-])'"$LOCKNAME"'([^[:alnum:]_.-]|$)'
# The same without the right boundary, for a rule that adds its own.
LOCKBARE='(^|[^[:alnum:]_.-])'"$LOCKNAME"
if full; then
  case "$TEXT" in
  *[Cc][Oo][Nn][Ff]*)
    if hit "$LOCKFILE"; then
      # The verb and the name sit in one simple command: no ; & | between
      # them. The probe rides in a call with other commands, and a cp or
      # an rm on another path there is none of the lock's business.
      LKV='(^|[^[:alnum:]_-])'
      # After the verb, a separator, then anything but a command break
      # up to the name, which may follow the separator directly.
      LKN='([^;&|]*[^[:alnum:]_.;&|-])?'"$LOCKNAME"'([^[:alnum:]_.-]|$)'
      # touch -r LOCK TARGET only reads LOCK: the reference operand is
      # taken out before the touch rule looks for the lock as a target.
      LKTOUCH=$(printf '%s\n' "$TEXT" | sed -E "s/[[:space:]](-[[:alpha:]]*r[[:space:]]+|--reference[=[:space:]]+)[\"']?[^[:space:];&|\"']*${LOCKNAME}/ REF/g")
      if hit '>>?[[:space:]]*["'\'']?[^[:space:];|&]*'"$LOCKFILE" \
        || hit "${LKV}(sed|perl)([^[:alnum:]_-][^;&|]*)?[[:space:]](-[[:alpha:]]*[iI][^[:space:]]*|--in-place[^[:space:]]*)[[:space:]]${LKN}" \
        || hit "${LKV}${EDITOR}[^[:alnum:]_-]${LKN}" \
        || hit "${LKV}(${CLOBBER}|cp)[^[:alnum:]_-]${LKN}" \
        || printf '%s\n' "$LKTOUCH" | grep -Eq "${LKV}touch[^[:alnum:]_-]${LKN}" \
        || hit "${LOCKBARE}[^;&|]*[[:space:]]-(delete|exec(dir)?)([^[:alnum:]_-]|\$)" \
        || hit "${LKV}[gm]?awk([^[:alnum:]_-][^;&|]*)?[[:space:]]inplace[[:space:]]${LKN}" \
        || writes_to "$LOCKBARE"
      then
        deny "/etc/hostwarden.conf and /etc/heinzel.conf are the \
server lock; only the machine's owner changes them, never Hostwarden \
(cat and grep read them)"
      fi
      # awk is left out: the activity check pipes every read-back into
      # awk "$C" in the call that carries the lock probe.
      if hit "$(printf '%s' "$INTERP" | sed 's/|\[gmn\]?awk//')"; then
        deny "an interpreter with the server lock's file name on its \
command line can lift the lock - read it with cat or grep instead"
      fi
    fi ;;
  esac
fi
