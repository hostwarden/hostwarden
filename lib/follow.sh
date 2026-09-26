# shellcheck shell=sh
# follow.sh — the release line a checkout follows, defined once.
#
# Sourced, never executed, by bin/hostwarden-update and
# check-updates.sh, from the top of the checkout.
#
# The line is `hostwarden.follow` in the checkout's own git
# config: a major ("1"), a major.minor ("1.2"), or "main" for a
# checkout that follows main by choice. Only there (--local): a
# global value would make every clone follow it and outlive an
# --unpin. Never a shipped file — an update would carry it to
# every install, and a checkout at a tag could not change it.
#
# A checkout on main with no value follows main until a release
# exists, then the major of the newest release, recorded the
# first time an update sees one (hostwarden_follow_default).
#
# Expects nothing. Defines:
#   hostwarden_follow          — prints the line, or nothing for
#                                main
#   hostwarden_follow_chosen   — true when the checkout has a
#                                value, "main" included
#   hostwarden_follow_set L    — follows line L, or main, from
#                                now on
#   hostwarden_follow_clear    — follows nothing: a pin
#   hostwarden_follow_valid L  — true when L is a major or a
#                                major.minor
#   hostwarden_follow_fetch    — brings origin's tags, and only
#                                its tags
#   hostwarden_follow_tag L    — prints the highest vX.Y.Z tag on
#                                line L this clone knows, or
#                                nothing
#   hostwarden_follow_default  — on main with no value: prints the
#                                major of the newest release this
#                                clone knows, when it is 1 or
#                                more; nothing otherwise. Only an
#                                operations checkout settles on it
#                                (bin/hostwarden-update)
#   hostwarden_clone_top       — true at the top of a clone that
#                                tracks Hostwarden

# Outside a clone every git call fails, and the caller would blame
# something else, a detached HEAD for one. Unpacked into some other
# repository, git would pull that one, and unpacked at the top of
# another checkout, the first test passes but git does not track
# bin/hostwarden-update there.
hostwarden_clone_top() {
  [ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$(pwd -P)" ] \
    && git ls-files --error-unmatch bin/hostwarden-update >/dev/null 2>&1
}

hostwarden_follow() {
  hf=$(git config --local --get hostwarden.follow 2>/dev/null) || return 0
  [ "$hf" = main ] || printf '%s\n' "$hf"
}

hostwarden_follow_chosen() {
  git config --local --get hostwarden.follow >/dev/null 2>&1
}

hostwarden_follow_set() { git config --local hostwarden.follow "$1"; }

hostwarden_follow_clear() {
  git config --local --unset hostwarden.follow 2>/dev/null || true
}

hostwarden_follow_valid() {
  case $1 in
  '' | *[!0-9.]* | .* | *. | *..* | *.*.*) return 1 ;;
  esac
}

# No branch: a follower never uses main, and this runs at session
# start. No force: a tag that moved upstream stays as it was here.
hostwarden_follow_fetch() {
  git fetch --quiet --no-tags origin 'refs/tags/*:refs/tags/*'
}

# v1.* never matches v10.0.0, and v1.2.* never v1.20.0: the dot
# ends the number. A pre-release (v1.3.0-rc1) is no release.
hostwarden_follow_tag() {
  git tag -l "v$1.*" --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1
}

# A 0.x release is no line to settle on: main until 1.0.0.
hostwarden_follow_default() {
  [ "$(git symbolic-ref --short -q HEAD)" = main ] || return 0
  ! hostwarden_follow_chosen || return 0
  hd=$(hostwarden_follow_tag '[1-9]*')
  hd=${hd#v}
  [ -z "$hd" ] || printf '%s\n' "${hd%%.*}"
}
