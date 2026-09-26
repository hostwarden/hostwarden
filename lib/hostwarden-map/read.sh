# lib/hostwarden-map/read.sh — steps 1 to 3: memory.md, topology.md,
# guests.md and cluster.md read into tables. Sourced by
# bin/hostwarden-map, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- step 1: every host'"'"'s memory.md, folded into <host> TAB <key>
#     TAB <value>, continuation lines joined -- the same shape
#     bin/hostwarden-impact'"'"'s own fields() builds. --------------------
HOSTFIELDS="$WORK/hostfields"
: >"$HOSTFIELDS"
set --
for f in "$M"/machines/*/memory.md; do
  [ -f "$f" ] && [ ! -L "${f%/memory.md}" ] && set -- "$@" "$f"
done
if [ $# -gt 0 ]; then
  awk '
    function flush() { if (key != "") print h "\t" key "\t" val; key = "" }
    FNR == 1 { flush(); h = FILENAME; sub(/\/memory\.md$/, "", h); sub(/.*\//, "", h) }
    /^- [A-Za-z][A-Za-z0-9 _-]*:/ {
      flush(); key = substr($0, 3); sub(/:.*/, "", key)
      val = $0; sub(/^- [^:]*:[ \t]*/, "", val); next
    }
    /^[ \t]+[^ \t]/ && key != "" { v = $0; sub(/^[ \t]+/, "", v); val = val " " v; next }
    { flush() }
    END { flush() }' "$@" >"$HOSTFIELDS" || die "a host's memory.md could not be parsed"
fi

# --- step 2: memory/topology.md, three tables -----------------------
SITES="$WORK/sites.tsv"
RANGES="$WORK/ranges.tsv"
EDGES="$WORK/edges.tsv"
FINDINGS="$WORK/findings.tsv"
: >"$SITES"; : >"$RANGES"; : >"$EDGES"; : >"$FINDINGS"
# render_wan reads $SITES.us/$EDGES.us/$FINDINGS.us unconditionally,
# but the us() calls that write them run only inside the topology.md
# branch below -- with no topology.md at all (not the transient-read
# case prune_stale guards against, just a workspace that never had
# one) those siblings would otherwise never exist, and every reader
# would fail on a plain "No such file" instead of seeing empty input.
: >"$SITES.us"; : >"$EDGES.us"; : >"$FINDINGS.us"

if [ -f "$M/topology.md" ]; then
  awk '
    function flush(   name, rest, date) {
      if (raw == "" || section != "sites") return
      name = raw; sub(/ —.*/, "", name)
      rest = raw; sub(/^[^—]*— */, "", rest)
      date = "not known"
      if (match(raw, /, [0-9]{4}-[0-9]{2}-[0-9]{2}\)$/)) {
        date = substr(raw, RSTART + 2, RLENGTH - 3)
      }
      print name "\t" rest "\t" date
      raw = ""
    }
    /^## Sites/ { flush(); section = "sites"; next }
    /^## / { flush(); section = ""; next }
    section == "sites" && /^- / { flush(); raw = $0; sub(/^- /, "", raw); next }
    section == "sites" && /^[ \t]+[^ \t]/ { v = $0; sub(/^[ \t]+/, "", v); raw = raw " " v; next }
    { flush() }
    END { flush() }
  ' "$M/topology.md" >"$WORK/sites-raw.tsv" \
    || die "memory/topology.md: the ## Sites section could not be parsed"
  LC_ALL=C sort "$WORK/sites-raw.tsv" >"$SITES"
  us "$SITES"

  awk '
    function flush(   line, prefix, site, vlan, gw, date, m) {
      if (raw == "" || section != "ranges") return
      line = raw
      prefix = line; sub(/ .*/, "", prefix)
      site = "not known"
      if (match(line, /site [A-Za-z0-9._-]+/)) {
        site = substr(line, RSTART + 5, RLENGTH - 5)
      } else if (match(line, /host-internal on [A-Za-z0-9._-]+/)) {
        m = substr(line, RSTART, RLENGTH); sub(/^host-internal on /, "", m)
        site = "host:" m
      }
      vlan = "not known"
      if (match(line, /VLAN [0-9]+/)) vlan = substr(line, RSTART + 5, RLENGTH - 5)
      else if (line ~ /untagged/) vlan = "untagged"
      gw = ""
      if (match(line, /gateway [0-9A-Za-z.:]+ \([^)]+\)/)) {
        m = substr(line, RSTART, RLENGTH)
        if (match(m, /\([^)]+\)/)) gw = substr(m, RSTART + 1, RLENGTH - 2)
      }
      date = "not known"
      if (match(line, /; [0-9]{4}-[0-9]{2}-[0-9]{2}$/)) date = substr(line, RSTART + 2, RLENGTH - 2)
      print prefix "\t" site "\t" vlan "\t" gw "\t" date "\t" line
      raw = ""
    }
    /^## Ranges/ { flush(); section = "ranges"; next }
    /^## / { flush(); section = ""; next }
    section == "ranges" && /^- / { flush(); raw = $0; sub(/^- /, "", raw); next }
    section == "ranges" && /^[ \t]+[^ \t]/ { v = $0; sub(/^[ \t]+/, "", v); raw = raw " " v; next }
    { flush() }
    END { flush() }
  ' "$M/topology.md" >"$WORK/ranges-raw.tsv" \
    || die "memory/topology.md: the ## Ranges section could not be parsed"
  LC_ALL=C sort "$WORK/ranges-raw.tsv" >"$RANGES"

  awk '
    function flush(   line, from, to, tag, host, date, m) {
      if (raw == "" || section != "topology") return
      line = raw
      # The from-range can carry its own policy-routing source
      # address, ", from <address>" ahead of the arrow
      # (rules/network-topology.md: "192.0.2.0/24, from 192.0.2.10
      # → ..."); stripped here so the prefix alone is what a
      # RANGES lookup gets, never a string no range record equals.
      from = line; sub(/ →.*/, "", from); sub(/, from .*/, "", from)
      to = line; sub(/^[^→]*→ */, "", to); sub(/ via .*/, "", to); sub(/ on .*/, "", to)
      tag = "not known"
      if (line ~ /, LAN hop/) tag = "LAN hop"
      else if (line ~ /, WAN/) tag = "WAN"
      host = "not known"
      if (match(line, /from [A-Za-z0-9._-]+;/)) host = substr(line, RSTART + 5, RLENGTH - 6)
      date = "not known"
      if (match(line, /; [0-9]{4}-[0-9]{2}-[0-9]{2}$/)) date = substr(line, RSTART + 2, RLENGTH - 2)
      print from "\t" to "\t" tag "\t" host "\t" date "\t" line
      raw = ""
    }
    /^## Topology$/ { flush(); section = "topology"; next }
    /^## / { flush(); section = ""; next }
    section == "topology" && /^- / { flush(); raw = $0; sub(/^- /, "", raw); next }
    section == "topology" && /^[ \t]+[^ \t]/ { v = $0; sub(/^[ \t]+/, "", v); raw = raw " " v; next }
    { flush() }
    END { flush() }
  ' "$M/topology.md" >"$WORK/edges-raw.tsv" \
    || die "memory/topology.md: the ## Topology section could not be parsed"
  LC_ALL=C sort "$WORK/edges-raw.tsv" >"$EDGES"
  us "$EDGES"

  awk '
    function flush(   line, sev, text, date) {
      if (raw == "" || section != "findings") return
      line = raw
      sev = "INFO"; if (line ~ /^WARN:/) sev = "WARN"
      text = line; sub(/^(WARN|INFO): */, "", text)
      date = "not known"
      if (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) date = substr(line, RSTART, RLENGTH)
      print sev "\t" text "\t" date "\t" line
      raw = ""
    }
    /^## Topology findings/ { flush(); section = "findings"; next }
    /^## / { flush(); section = ""; next }
    section == "findings" && /^- / { flush(); raw = $0; sub(/^- /, "", raw); next }
    section == "findings" && /^[ \t]+[^ \t]/ { v = $0; sub(/^[ \t]+/, "", v); raw = raw " " v; next }
    { flush() }
    END { flush() }
  ' "$M/topology.md" >"$WORK/findings-raw.tsv" \
    || die "memory/topology.md: the ## Topology findings section could not be parsed"
  LC_ALL=C sort "$WORK/findings-raw.tsv" >"$FINDINGS"
  us "$FINDINGS"
fi

# --- step 3: every guests.md and cluster.md -------------------------
#
# GUESTS: <owner> TAB <id> TAB <name> TAB <kind> TAB <state> TAB <ip>
#         TAB <memdir> TAB <raw line>
# owner is a hypervisor'"'"'s directory name, or cluster:<name> for a
# cluster'"'"'s own guests.md.
GUESTS="$WORK/guests.tsv"
: >"$GUESTS"
set --
for g in "$M"/machines/*/guests.md "$M"/clusters/*/guests.md; do
  [ -f "$g" ] && set -- "$@" "$g"
done
if [ $# -gt 0 ]; then
  awk '
    function flush(   id, name, kind, state, ip, dir, m, rest) {
      if (e == "") return
      id = e; sub(/ .*/, "", id)
      rest = e; sub(/^[^ ]+ /, "", rest)
      # A jail is named, not numbered (rules/hypervisors.md): its
      # one token is already both id and name, and rest starts
      # straight at "(jail):", with no second name token before it.
      if (rest ~ /^\(/) name = id
      else { name = rest; sub(/ \(.*/, "", name) }
      kind = "not known"
      if (match(rest, /\([A-Za-z]+\):/)) kind = substr(rest, RSTART + 1, RLENGTH - 3)
      state = "not known"
      if (match(rest, /: [A-Za-z]+/)) state = substr(rest, RSTART + 2, RLENGTH - 2)
      # An IPv6 token never collides with the MAC that follows it:
      # a MAC is always six groups of exactly two hex digits and
      # never compresses with "::", the shape this looks for first.
      ip = ""
      if (match(rest, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) ip = substr(rest, RSTART, RLENGTH)
      else if (match(rest, /[0-9A-Fa-f:]*::[0-9A-Fa-f:]*[0-9A-Fa-f]/)) ip = substr(rest, RSTART, RLENGTH)
      else if (match(rest, /([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}/)) ip = substr(rest, RSTART, RLENGTH)
      dir = ""
      if (match(rest, /→[ \t]*(probably[ \t]+)?[A-Za-z0-9._-]+/)) {
        m = substr(rest, RSTART, RLENGTH); sub(/^→[ \t]*(probably[ \t]+)?/, "", m); dir = m
      }
      print o "\t" id "\t" name "\t" kind "\t" state "\t" ip "\t" dir "\t" e
      e = ""
    }
    FNR == 1 {
      flush(); o = FILENAME; sub(/\/guests\.md$/, "", o)
      p = o; sub(/\/[^\/]*$/, "", p); sub(/.*\//, "", o)
      if (p ~ /clusters$/) o = "cluster:" o
    }
    /^- Inventoried:/ { flush(); next }
    /^- Checked:/ { flush(); next }
    /^- [0-9A-Za-z]/ { flush(); e = $0; sub(/^- /, "", e); next }
    /^[ \t]+[^ \t]/ && e != "" { v = $0; sub(/^[ \t]+/, "", v); e = e " " v; next }
    { flush() }
    END { flush() }
  ' "$@" >"$WORK/guests-raw.tsv" || die "a guests.md could not be parsed"
  LC_ALL=C sort "$WORK/guests-raw.tsv" >"$GUESTS"
fi

# CLUSTERMEMBERS: <cluster> TAB <short name> TAB <memory dir, or
# empty for "no memory"> -- the short name is what a cluster
# guests.md'"'"'s own "running on <name>" names the member by
# (rules/hypervisors.md), the directory what memory.md links to.
# CLUSTERKIND: <cluster> TAB <the heading's own "(<appliance>)">,
# where it names one -- its own tag and file, never mixed with any
# other "- " line before the row for a given cluster is picked
# (LC_ALL=C sorts "- " before a capital letter, so a shared bag
# sorted and picked by "first match" could return either).
CLUSTERMEMBERS="$WORK/clustermembers.tsv"
CLUSTERKIND="$WORK/clusterkind.tsv"
: >"$CLUSTERMEMBERS"; : >"$CLUSTERKIND"
set -- "$M"/clusters/*/cluster.md
if [ -f "$1" ]; then
  awk '
    function flushm(   n, i, e, short, dir) {
      n = split(ms, a, ",")
      for (i = 1; i <= n; i++) {
        e = a[i]; sub(/^[ \t]+/, "", e)
        short = e; sub(/[ \t(].*/, "", short)
        dir = ""
        if (match(e, /→[ \t]*[A-Za-z0-9._-]+/)) {
          dir = substr(e, RSTART, RLENGTH); sub(/^→[ \t]*/, "", dir)
        }
        if (short != "") print "M\t" c "\t" short "\t" dir
      }
      ms = ""
    }
    FNR == 1 {
      flushm(); c = FILENAME; sub(/\/cluster\.md$/, "", c); sub(/.*\//, "", c)
      if (match($0, /\([^)]+\)[ \t]*$/)) {
        print "K\t" c "\t" substr($0, RSTART + 1, RLENGTH - 2)
      }
      next
    }
    /^- Members:/ { flushm(); ms = $0; sub(/^- Members:/, "", ms); next }
    /^[ \t]+[^ \t]/ && ms != "" { ms = ms " " $0; next }
    /^- / { flushm(); next }
    { flushm() }
    END { flushm() }
  ' "$@" >"$WORK/cluster-raw.tsv" || die "a cluster.md could not be parsed"
  LC_ALL=C sort "$WORK/cluster-raw.tsv" >"$WORK/clusterraw.tsv"
  awk -F'\t' '$1 == "M" { print $2 "\t" $3 "\t" $4 }' "$WORK/clusterraw.tsv" >"$CLUSTERMEMBERS"
  awk -F'\t' '$1 == "K" { print $2 "\t" $3 }' "$WORK/clusterraw.tsv" >"$CLUSTERKIND"
fi
