# lib/hostwarden-map/palette.sh — the palette and the helpers every
# level draws with. Sourced by bin/hostwarden-map, in the order its
# PARTS lists, into the one shell every part shares; never run on
# its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the palette --------------------------------------------------
#
# Every stroke reaches 3:1 against both GitHub canvases (light
# #ffffff, dark #0d1117): one neutral ink, #8a8a8a, computed to
# 3.45:1 against white and 5.48:1 against #0d1117 — verified by
# tests/bin/hostwarden-map.sh, not eyeballed. A finding's accent,
# #93691f, is a second colour in the same qualifying band (4.91:1 and
# 3.86:1) chosen apart from Hostwarden's Signal, which the brand
# reserves for the logo's LED alone (hostwarden/brand; its README
# → Color). Every fill and text pair only has to reach 4.5:1 against
# its own fill, which does not sit on the page canvas, so the full
# brand darks and lights are used there: Petrol #0C4A55, Frost
# #ECF2F1, Stone #A9BDBF, Deep #072E36 (contrast 8.7–14.4:1, per
# that same README).
#
# Composing a role class with a state class (router,stale) does not
# reliably restyle the node in this Mermaid version — verified with
# the diagram-render tool before this was written: the two class
# names are joined with a literal comma into one unmatched CSS
# token. Every role therefore carries its own -stale and -finding
# variant, spelling the state out completely rather than composing
# it, and `class` never lists more than one name.
CLASSDEFS='  classDef site fill:none,stroke:#8a8a8a,stroke-width:2px
  classDef internet fill:none,stroke:#8a8a8a,stroke-width:2px
  classDef router fill:#0C4A55,stroke:#8a8a8a,color:#ECF2F1
  classDef router-stale fill:#0C4A55,stroke:#8a8a8a,color:#ECF2F1,stroke-dasharray:6 3
  classDef router-finding fill:#0C4A55,stroke:#93691f,stroke-width:3px,color:#ECF2F1
  classDef host fill:#ECF2F1,stroke:#8a8a8a,color:#072E36
  classDef host-stale fill:#ECF2F1,stroke:#8a8a8a,color:#072E36,stroke-dasharray:6 3
  classDef host-finding fill:#ECF2F1,stroke:#93691f,stroke-width:3px,color:#072E36
  classDef storage fill:#A9BDBF,stroke:#8a8a8a,color:#072E36
  classDef storage-stale fill:#A9BDBF,stroke:#8a8a8a,color:#072E36,stroke-dasharray:6 3
  classDef storage-finding fill:#A9BDBF,stroke:#93691f,stroke-width:3px,color:#072E36
  classDef unknown fill:#f4f4f4,stroke:#8a8a8a,color:#333333,stroke-dasharray:4 3'

# LEGEND — the short table under every diagram, in the same order as
# CLASSDEFS names a shape; kept beside it so the two are edited
# together.
legend() {
  cat <<'EOF'
| Shape | Meaning |
| :--- | :--- |
| Hexagon, petrol | Router or firewall |
| Rectangle, frost | Hypervisor |
| Rounded, frost | VM or a plain server |
| Subroutine `[[ ]]`, frost | Container |
| Cylinder, stone | Storage or an appliance |
| Stadium, frost | An uplink |
| Dashed, light grey | Not known |
| Dashed border | Stale — older than 90 days |
| Thick amber border | A topology finding |
| Solid line | A LAN hop |
| Thick line | A WAN uplink |
| Dotted line | A tunnel or an overlay |
EOF
}

# id_sh <name> -- a Mermaid node or subgraph ID: lowercase, every
# byte outside a-z0-9_ turned into "_".
id_sh() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_' '_'; }

# slug_sh <name> -- a map'"'"'s filename: lowercase, "/" the only byte
# turned into "_", so "web1.example.com" and "colo-fra" stay
# themselves and only a name with a path separator in it is mangled.
slug_sh() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '/' '_'; }

# date_max <a> <b> -- the later of two YYYY-MM-DD dates on stdout,
# "not known" losing to any real date.
date_max() {
  case $1 in '' | 'not known') printf '%s' "$2"; return ;; esac
  case $2 in '' | 'not known') printf '%s' "$1"; return ;; esac
  if str_gt "$1" "$2"; then printf '%s' "$1"; else printf '%s' "$2"; fi
}

# str_gt <a> <b> -- exit 0 when <a> sorts after <b>. POSIX test has
# no > for strings (dash does not carry bash'"'"'s extension, and this
# runs under the one true awk'"'"'s neighbourhood; #278), so this sorts
# the pair instead of comparing them directly.
str_gt() {
  [ "$1" = "$2" ] && return 1
  [ "$(printf '%s\n%s\n' "$1" "$2" | LC_ALL=C sort | tail -n 1)" = "$1" ]
}

# epoch_of <YYYY-MM-DD> -- seconds since the epoch, GNU or BSD date;
# empty on a date this cannot parse.
epoch_of() {
  # GNU date -d is a natural-language parser: "2026" or "today" both
  # succeed, so a truncated or malformed field would silently become
  # a real epoch instead of the "not known" is_stale then treats as
  # a gap, not a guess. The shape is checked by hand first -- and a
  # shape-valid but impossible date (2026-02-30) still needs a
  # second check, since both GNU and BSD date silently roll a day
  # that does not exist into the one after the month it belongs to.
  case $1 in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) return 1 ;; esac
  eo_s=$(date -d "$1" +%s 2>/dev/null) || eo_s=$(date -j -f '%Y-%m-%d' "$1" +%s 2>/dev/null) \
    || return 1
  eo_back=$(date -d "@$eo_s" +%Y-%m-%d 2>/dev/null) \
    || eo_back=$(date -j -f '%s' "$eo_s" +%Y-%m-%d 2>/dev/null) || return 1
  [ "$eo_back" = "$1" ] || return 1
  echo "$eo_s"
}

# TODAY_EPOCH -- once, not once per host: is_stale runs in a loop
# over every host, and TODAY never moves within a single run.
TODAY_EPOCH=$(epoch_of "$TODAY") || TODAY_EPOCH=0

# days_since <YYYY-MM-DD> -- whole days from <date> to TODAY on
# stdout; fails on a date epoch_of cannot parse. Rounded, not
# floored: BSD date fills the time of day from the clock, so two
# dates read a moment apart are not whole days apart, and a DST
# change moves one by an hour.
days_since() {
  hwm_ds_e=$(epoch_of "$1") || return 1
  [ -n "$hwm_ds_e" ] || return 1
  echo $(( (TODAY_EPOCH - hwm_ds_e + 43200) / 86400 ))
}

# is_stale <date> -- exit 0 when <date> is older than 90 days before
# TODAY (rules/machine-memory.md → Onboarded and stale lines), 1 for
# "not known" or a date this cannot parse: a gap is not staleness.
# Its own name, never d: called with a caller'"'"'s own $d live (the
# classification loop in classify.sh), and sh has no true local -- a
# same-named global here would overwrite the caller'"'"'s mid-loop, the
# exact bug this comment is here to stop someone reintroducing.
is_stale() {
  case $1 in '' | 'not known') return 1 ;; esac
  hwm_stale_d=$(days_since "$1") || return 1
  [ "$hwm_stale_d" -gt 90 ]
}
