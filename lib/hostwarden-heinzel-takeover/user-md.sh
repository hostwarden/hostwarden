# lib/hostwarden-heinzel-takeover/user-md.sh — user.md, merged line
# by line. Sourced by bin/hostwarden-heinzel-takeover, in the order
# its PARTS lists, into the one shell every part shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

CR=$(printf '\r')
US=$(printf '\037')

# user_line <id> <file>: the first line of <file> that
# sets <id>, or nothing. The id is the text before ": "
# with its list form: "- Default" is a host named
# Default, "Default" the default user (rules/ssh-user.md).
# A commented line sets nothing: the template ships its
# preferences as comments.
user_line() {
  while IFS= read -r ul_line || [ -n "$ul_line" ]; do
    ul_line=${ul_line%"$CR"}
    case "$ul_line" in '#'*|'') continue ;; esac
    if [ "${ul_line%%: *}" = "$1" ]; then
      printf '%s\n' "$ul_line"
      return 0
    fi
  done < "$2"
}

# A user.md of this clone's own is merged rather than
# kept whole: the old one's language, reply address and
# per-machine SSH users would otherwise stay behind
# unnoticed. Every "Key: value" line this clone does not
# set comes across, under the heading it had in the old
# file — "# Preferences", "# SSH Users",
# "## Per-server overrides" or one of the user's own —
# which this file gets at its end where it lacks it. A
# key both set differently is reported, never chosen,
# and so is a greeting that signs as Heinzel.
UM_SRC="$OLD/memory/user.md"
UM_DST="memory/user.md"
case " $SHARED_PENDING " in
  *" user.md "*)
    if [ -f "$UM_SRC" ] && [ -f "$UM_DST" ] && [ ! -L "$UM_DST" ]; then
      # UM_Q: one "<heading><US><line>" per line to add.
      UM_Q='' UM_DIFF='' UM_SEEN="$NL" UM_N=0 UM_HEAD=''
      while IFS= read -r UM_LINE || [ -n "$UM_LINE" ]; do
        UM_LINE=${UM_LINE%"$CR"}
        case "$UM_LINE" in
          '# '*|'## '*) UM_HEAD=$UM_LINE; continue ;;
          '#'*|'') continue ;;
        esac
        UM_ITEM=${UM_LINE#- }
        case "$UM_ITEM" in *': '*) ;; *) continue ;; esac
        UM_ID=${UM_LINE%%: *}
        UM_KEY=${UM_ID#- }
        # This script writes that line itself.
        [ "$UM_KEY" = "Taken over from heinzel" ] && continue
        # The first line for a key decides, as for the
        # agent that reads the file.
        case "$UM_SEEN" in *"$NL$UM_ID$NL"*) continue ;; esac
        UM_SEEN="$UM_SEEN$UM_ID$NL"
        UM_HAVE=$(user_line "$UM_ID" "$UM_DST")
        if [ -n "$UM_HAVE" ]; then
          [ "$UM_HAVE" = "$UM_LINE" ] \
            || UM_DIFF="$UM_DIFF  $UM_ID: \"${UM_HAVE#*: }\" here, \"${UM_LINE#*: }\" in the old checkout$NL"
          continue
        fi
        case "$UM_ITEM" in
          Greeting:*[Hh]einzel*)
            UM_DIFF="$UM_DIFF  Greeting: the old checkout's signs as Heinzel, not taken$NL"
            continue ;;
        esac
        UM_N=$((UM_N + 1))
        UM_Q="$UM_Q$UM_HEAD$US$UM_LINE$NL"
      done < "$UM_SRC"
      # user.md is the first shared item, so it leads the
      # list when it is pending.
      SHARED_PENDING=${SHARED_PENDING# user.md}
      if [ -n "$UM_DIFF" ]; then
        printf 'kept memory/user.md where it differs from the old checkout:\n%s' \
          "$UM_DIFF" >&2
      fi
      if [ "$UM_N" -eq 0 ]; then
        NOTHING_LEFT=yes
      else
        plan "user.md (merged: $UM_N lines added)"
        if [ -z "$LIST" ]; then
          UM_TMP=$(mktemp "$UM_DST.XXXXXX")
          # um_under <heading>: the queued lines for it.
          um_under() {
            printf '%s' "$UM_Q" | while IFS= read -r uu; do
              [ "${uu%%"$US"*}" != "$1" ] || printf '%s\n' "${uu#*"$US"}"
            done
          }
          UM_DONE="$NL"
          {
            # Lines that stood above every heading.
            um_under ''
            while IFS= read -r UM_LINE || [ -n "$UM_LINE" ]; do
              UM_LINE=${UM_LINE%"$CR"}
              printf '%s\n' "$UM_LINE"
              case "$UM_LINE" in
                '# '*|'## '*)
                  case "$UM_DONE" in *"$NL$UM_LINE$NL"*) ;; *)
                    um_under "$UM_LINE"
                    UM_DONE="$UM_DONE$UM_LINE$NL" ;;
                  esac ;;
              esac
            done < "$UM_DST"
            # Headings this file lacks, in the old order.
            printf '%s' "$UM_Q" | while IFS= read -r UM_QL; do
              UM_H=${UM_QL%%"$US"*}
              [ -n "$UM_H" ] || continue
              case "$UM_DONE" in *"$NL$UM_H$NL"*) continue ;; esac
              UM_DONE="$UM_DONE$UM_H$NL"
              printf '\n%s\n\n' "$UM_H"
              um_under "$UM_H"
            done
          } > "$UM_TMP"
          # Through cat, not mv: the file keeps its own
          # mode, and mktemp's is 0600.
          cat "$UM_TMP" > "$UM_DST"
          rm -f "$UM_TMP"
        fi
      fi
    fi ;;
esac
