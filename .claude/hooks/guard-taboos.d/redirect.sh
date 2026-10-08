# guard-taboos.d/redirect.sh — a redirect onto a computed target.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run on its
# own.
# shellcheck shell=sh

# --- A redirect onto a computed target -------------------------
# In unquoted echo text, -> is a dash and a redirect, and the word
# after it names the file the redirect truncates:
#
#   ssh root@h 'bash -ic "echo editor: \$E -> \$(readlink -f \$E)"'
#
# printed nothing and replaced /usr/bin/nvim with the prose before
# the arrow, as root; the empty output was read as "fine". Denied:
# any redirect (>, >|, >>, >&, 1>) onto a $( ) or ` ` lookup, and
# an arrow onto any expansion ($VAR, ${VAR}, $( )) or onto such a
# lookup, with or without the backslashes an inner ssh or bash -c
# level puts in front of the $ and of a quote.
# A plain > "$VAR" stays allowed: scripts write that way, and the
# variable was set in sight. <( ) and >( ) are process
# substitutions, not redirects, and pass. Only the thin arrow
# counts: => before a variable is PHP's and Perl's fat arrow, and
# the instruction blocks carry such code. Before a backtick, the
# word the > ends must hold no < and not end in a dash, and the
# arrow must not follow a backtick: in prose, a > closes a
# <placeholder> and the backtick after it closes the code span,
# and an arrow is quoted as a code span of its own.
#
# Full scope only. The target is whatever the lookup returns, and
# in a development checkout that is one of this user's own files,
# which the local scope leaves to the user; this repository's
# tests and commit messages spell these shapes all day.
#
# Accepted false positive: the same text in double quotes,
# echo "editor -> $(readlink -f $E)", which is prose where it
# stands -- but one ssh or bash -c level further in those quotes
# are gone, and the guard cannot count quote depth.
#
# Most commands hold no lookup after a > and no arrow at all, so a
# case on the texts hit reads keeps the grep off them.
if full; then
  case "$TEXT" in
  *'>'*'$('*|*'>'*'`'*|*'->'*)
    if hit '(>[|&]?[[:space:]]*(\\?["'\''])?\\?\$\(|(^|[[:space:]])([^<[:space:]]*[^-<[:space:]])?>>?[|&]?[[:space:]]*(\\?["'\''])?\\?`|->[[:space:]]*(\\?["'\''])?\\?\$|(^|[^`])->[[:space:]]*(\\?["'\''])?\\?`)'
    then
      deny "a redirect onto a computed target overwrites whatever \
file the lookup names, and an arrow in echo text is a redirect too \
- print data, not prose, and write only to a file you named"
    fi
    ;;
  esac
fi
