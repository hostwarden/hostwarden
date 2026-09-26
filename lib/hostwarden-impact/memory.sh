# lib/hostwarden-impact/memory.sh — radius: the hosts, guests and
# jump hosts memory holds, indexed once. Sourced by
# bin/hostwarden-impact, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- memory -----------------------------------------------------

# sshg <config> <user> <port> <host> — ssh -G for <host>; <config>
# is - for the standard options, empty for the user's own, or the
# file to read. With -v, ssh names on stderr each configuration file
# it reads, Include targets wherever they are among them.
sshg() {
  sg_c=$SSHCFG
  [ "$1" = - ] || sg_c=$1
  ssh ${sg_c:+-F "$sg_c"} -v -G ${2:+-l "$2"} ${3:+-p "$3"} "$4" </dev/null \
    2>>"$WORK/sshlog"
}

# walk <name> <user> <port> — the key the host is known by on its
# way in (the hostname ssh -G prints for it), and the keys of every
# hop in front of it, read the same way for each hop in turn, five
# deep at most. Prints "self <key>", "hop <key>" and "bad" where the
# path cannot be read (rules/access-control.md → Server Blacklist).
walk() {
  if ! g=$(sshg - "$2" "$3" "$1"); then echo bad; return; fi
  printf '%s\n' "$g" | sed -n 's/^hostname /self /p'
  printf '%s\n' "$g" | hostwarden_hops "$1" - >"$WORK/q"
  depth=1
  while [ -s "$WORK/q" ]; do
    if [ "$depth" -gt 5 ]; then echo bad; return; fi
    : >"$WORK/next"
    while IFS= read -r e; do
      case $e in '!||') echo bad; continue ;; esac
      cfg=${e%%|*} rest=${e#*|}
      u=${rest%|*} h=${rest##*|}
      echo "hop $h"
      [ "$cfg" = = ] && continue
      # One lookup per hop, however many hosts share it.
      memo="$WORK/hop.$(printf '%s|%s|%s' "$cfg" "$u" "$h" | cksum)"
      if [ ! -f "$memo" ]; then
        if g=$(sshg "$cfg" "$u" '' "$h"); then
          { printf '%s\n' "$g" | sed -n 's/^hostname /hop /p'
            printf '%s\n' "$g" | hostwarden_hops "$h" "$cfg" | sed 's/^/next /'
          } >"$memo"
        else
          echo bad >"$memo"
        fi
      fi
      grep -v '^next ' "$memo"
      sed -n 's/^next //p' "$memo" >>"$WORK/next"
    done <"$WORK/q"
    mv "$WORK/next" "$WORK/q"
    depth=$((depth + 1))
  done
}

# facts <host> <how> <dest> — walk's output on stdin as index lines
# of <host>. <how> is self where the walk was for the host's own
# name, reached for its Reached as: destination <dest>, whose keys
# name the destination rather than the host, and alias for an alias
# that logs in as another user, whose hops count too.
facts() {
  awk -v h="$1" -v how="$2" -v d="$3" '
    BEGIN { if (how == "reached") print "A\t" h "\t" tolower(d) }
    { k = tolower($2) }
    $1 == "self" && how == "self" { print "K\t" h "\t" k }
    $1 == "self" && how == "reached" { print "A\t" h "\t" k }
    $1 == "hop" { print "J\t" h "\t" k }
    $1 == "bad" { print "U\t" h }'
}

# build — writes the index: one fact per line, tab-separated.
#   N <name> <host>        a name (the directory, an alias) of a host
#   K <host> <key>         a key a hop, a Depends on: or a Runs on:
#                          may name the host by
#   R <host> <target> <id> the host runs on <target>, cluster:<c> for
#                          a cluster
#   G <host> <target> <id> an inventory of <target> links the host
#                          as its guest
#   Q <target> <id>        a guest in that inventory with no memory
#   I <target> <date>      the date of that inventory
#   V <host>               Mode: via, reached through its host
#   C <host> <cluster>     a member of <cluster>
#   A <host> <key>         Reached as: a destination that is <key>
#   J <host> <key>         a hop on its way in
#   U <host>               a way in that cannot be read
#   D <host> <target> <word> <what>
#                          a Depends on: entry
build() {
  fields >"$WORK/fields"
  # A copy that exists even where user.md does not, for one awk.
  cat "$M/user.md" >"$WORK/user.md" 2>/dev/null
  for d in "$M"/machines/*; do
    n=${d##*/}
    if [ -L "$d" ]; then
      t=$(readlink "$d"); t=${t%/}
      printf '%s\t%s\n' "$n" "${t##*/}"
    elif [ -f "$d/memory.md" ]; then
      printf '%s\t%s\n' "$n" "$n"
    fi
  done | awk '{ print "N\t" tolower($0) }' >"$WORK/names"
  {
    cat "$WORK/names"
    # The lines of memory.md this needs.
    awk -F '\t' '
      function lc(s) { return tolower(s) }
      { h = lc($1); k = $2; v = $3 }
      k == "IP" || k == "FQDN" {
        n = split(v, a, /[ ,;()]+/)
        for (i = 1; i <= n; i++) if (a[i] ~ /^[A-Za-z0-9:.-]+$/) print "K\t" h "\t" lc(a[i])
      }
      k == "Runs on" {
        split(v, a, /[ \t]+/)
        id = v; sub(/^[^(]*\(?/, "", id); sub(/\).*/, "", id)
        if (lc(a[1]) == "cluster") print "R\t" h "\tcluster:" lc(a[2]) "\t" id
        else print "R\t" h "\t" lc(a[1]) "\t" id
      }
      k == "Mode" && lc(v) ~ /^via/ { print "V\t" h }
      k == "Cluster" { split(v, a, /[ \t,]+/); print "C\t" h "\t" lc(a[1]) }
      k == "Depends on" {
        # Entries split at the commas outside brackets.
        depth = 0; cur = ""
        for (i = 1; i <= length(v) + 1; i++) {
          c = i <= length(v) ? substr(v, i, 1) : ","
          if (c == "(") depth++
          if (c == ")") depth--
          if (c == "," && depth <= 0) {
            sub(/^[ \t]+/, "", cur); sub(/[ \t]+$/, "", cur)
            if (cur != "") {
              t = cur; sub(/[ \t(].*/, "", t)
              w = cur; if (!sub(/^[^(]*\(/, "", w)) w = "other"; sub(/\).*/, "", w)
              word = w; sub(/[ \t].*/, "", word)
              print "D\t" h "\t" lc(t) "\t" lc(word) "\t" w
            }
            cur = ""; depth = 0
          } else cur = cur c
        }
      }' "$WORK/fields"
    # Cluster members recorded in cluster.md, "name → directory", or
    # "name (no memory)" for one without, which counts by its name.
    set -- "$M"/clusters/*/cluster.md
    [ -f "$1" ] && awk '
      function flush(  n, i, e, m) {
        n = split(ms, a, ",")
        for (i = 1; i <= n; i++) {
          e = a[i]; sub(/^[ \t]+/, "", e)
          if (match(e, /→[ \t]*[A-Za-z0-9._-]+/)) {
            m = substr(e, RSTART, RLENGTH); sub(/^→[ \t]*/, "", m)
          } else { m = e; sub(/[ \t(].*/, "", m) }
          if (m != "") print "C\t" tolower(m) "\t" c
        }
        ms = ""; in_m = 0
      }
      FNR == 1 { flush(); c = FILENAME; sub(/\/cluster\.md$/, "", c); sub(/.*\//, "", c); c = tolower(c) }
      /^- Members:/ { flush(); in_m = 1; ms = $0; sub(/^- Members:/, "", ms); next }
      in_m && /^[ \t]+[^ \t]/ { ms = ms " " $0; next }
      { flush() }
      END { flush() }' "$@"
    # The guest inventories: each entry linked with "→ <directory>"
    # or "→ probably <directory>", in case a guest lacks its Runs on:,
    # each without memory of its own, and the inventory date.
    set --
    for g in "$M"/machines/*/guests.md "$M"/clusters/*/guests.md; do
      [ -f "$g" ] && set -- "$@" "$g"
    done
    [ $# -eq 0 ] || awk '
      function flush(  m, id) {
        if (e == "") return
        id = e; sub(/^- /, "", id); sub(/:.*/, "", id)
        if (match(e, /→[ \t]*(probably[ \t]+)?[A-Za-z0-9._-]+/)) {
          m = substr(e, RSTART, RLENGTH); sub(/^→[ \t]*(probably[ \t]+)?/, "", m)
          print "G\t" tolower(m) "\t" o "\t" id
        } else print "Q\t" o "\t" id
        e = ""
      }
      FNR == 1 {
        flush(); o = FILENAME; sub(/\/guests\.md$/, "", o)
        p = o; sub(/\/[^\/]*$/, "", p); sub(/.*\//, "", o)
        o = tolower(o); if (p ~ /clusters$/) o = "cluster:" o
      }
      /^- Inventoried:/ { flush(); print "I\t" o "\t" $3; next }
      /^- Checked:/ { flush(); next }
      /^- [0-9A-Za-z]/ { flush(); e = $0; next }
      /^[ \t]+[^ \t]/ && e != "" { e = e " " $0; next }
      { flush() }
      END { flush() }' "$@"
    # The way in of each host: the SSH user it logs in as, and its
    # Reached as: destination with its port where it has one; an
    # alias that logs in as another user takes its own way in too. A
    # via guest goes through its host, and the local machine through
    # nothing. One line each: <name> <host> <how> <port> <user>, - for
    # an empty field.
    awk -F '\t' '
      function user(k) { k = tolower(k); return (k in us) ? us[k] : def }
      FILENAME ~ /user\.md$/ {
        if ($0 ~ /^[-*[:space:]]*Default:/ && def == "") {
          def = $0; sub(/^[-*[:space:]]*Default:[[:space:]]*/, "", def); sub(/[[:space:]].*/, "", def)
        } else if (match($0, /^- [^ :]+:[ \t]*[^ \t]+/)) {
          k = substr($0, 3); sub(/:.*/, "", k)
          v = $0; sub(/^- [^:]*:[ \t]*/, "", v); sub(/[ \t].*/, "", v); us[tolower(k)] = v
        }
        next
      }
      FILENAME ~ /names$/ { if ($2 == $3) host[++nh] = $2; else { na++; an[na] = $2; ah[na] = $3 }; next }
      { h = tolower($1) }
      $2 == "Mode" && tolower($3) ~ /^(via|local)/ { skip[h] = 1 }
      $2 == "Reached as" { split($3, a, /[ \t]+/); dest[h] = a[1] }
      $2 == "SSH port" { split($3, a, /[ \t]+/); if (a[1] ~ /^[0-9]+$/) port[h] = a[1] }
      END {
        for (i = 1; i <= nh; i++) {
          h = host[i]
          if (skip[h]) continue
          if (h in dest) {
            d = dest[h]; u = user(d)
            if (d ~ /@/) { u = d; sub(/@.*/, "", u); sub(/^[^@]*@/, "", d) }
            print d "\t" h "\treached\t" ((h in port) ? port[h] : "-") "\t" (u == "" ? "-" : u)
          } else print h "\t" h "\tself\t-\t" (user(h) == "" ? "-" : user(h))
        }
        for (i = 1; i <= na; i++) {
          h = ah[i]
          if (skip[h] || (h in dest) || !(tolower(an[i]) in us) || user(an[i]) == user(h)) continue
          print an[i] "\t" h "\talias\t-\t" user(an[i])
        }
      }' "$WORK/user.md" "$WORK/names" "$WORK/fields" >"$WORK/ways"
    while IFS="$TAB" read -r name h how port u; do
      [ "$port" = - ] && port=''
      [ "$u" = - ] && u=''
      walk "$name" "$u" "$port" | facts "$h" "$how" "$name"
    done <"$WORK/ways"
  } | LC_ALL=C sort -u >"$WORK/idx"
  # The files read: the SSH configuration ssh -G named, with its
  # directories, where a file an Include pattern matches appears or
  # goes, and memory's own. One that is gone later makes the index
  # stale. ~/.ssh and /etc/ssh themselves are left out: sockets and
  # known hosts change them all day, and stale() reads their files.
  {
    sed -n 's/^debug1: Reading configuration data //p' "$WORK/sshlog" 2>/dev/null \
      | while IFS= read -r f; do
          case ${f%/*} in
            "$HOME/.ssh" | /etc/ssh) printf '%s\n' "$f" ;;
            *) printf '%s\n%s\n' "$f" "${f%/*}" ;;
          esac
        done
    [ ! -f "$M/user.md" ] || echo "$M/user.md"
    for f in "$M"/machines/*/memory.md "$M"/machines/*/guests.md \
        "$M"/clusters/*/cluster.md "$M"/clusters/*/guests.md; do
      [ -f "$f" ] && [ ! -L "${f%/*}" ] && echo "$f"
    done
  } | LC_ALL=C sort -u >"$WORK/files"
}

# stale — the index is missing, a file it was read from is gone, or
# anything it is read from is newer, this script, its stages and the
# parser included. A file added to or removed from a host's or a cluster's
# directory, or from one an Include reads, changes that directory; a
# journal line in changelog.log changes nothing here.
stale() {
  [ -f "$IDX" ] && [ -f "$SRC" ] || return 0
  while IFS= read -r f; do
    [ -e "$f" ] || return 0
  done <"$SRC"
  [ -n "$({
    find "$M/machines" "$M/clusters" -type d -newer "$IDX"
    find "$M/machines" "$M/clusters" \( -name memory.md -o -name guests.md \
      -o -name cluster.md \) -newer "$IDX"
    find "$M/machines" "$M/clusters" "$M/user.md" "$SSHCFG" \
      "$SCRIPT_DIR/hostwarden-impact" lib/hops.sh lib/hostwarden-impact/*.sh \
      -prune -newer "$IDX"
    # The configuration ssh_config includes, and what that includes in
    # turn, wherever under ~/.ssh it lives; keys and known hosts are
    # no configuration.
    find "$HOME/.ssh" -type f ! -name 'known_hosts*' ! -name '*.pub' \
      ! -name 'id_*' ! -name 'authorized_keys*' -newer "$IDX"
    find /etc/ssh -type f -path '/etc/ssh/ssh_config*' -newer "$IDX"
    [ -s "$SRC" ] || exit 0
    tr '\n' '\0' <"$SRC" | xargs -0 sh -c \
      'find "$@" -prune -newer "$0"' "$IDX"
  } 2>/dev/null | head -n 1)" ]
}

if stale; then
  # Dated before the reads, so a change made while they run leaves
  # the index older than it.
  : >"$WORK/stamp"
  build
  touch -r "$WORK/stamp" "$WORK/idx"
  mv "$WORK/files" "$SRC.$$" && mv "$SRC.$$" "$SRC" \
    && mv "$WORK/idx" "$IDX.$$" && mv "$IDX.$$" "$IDX" || die "cannot write $IDX"
fi
