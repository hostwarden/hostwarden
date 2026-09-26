# lib/hostwarden-impact/report.sh — radius: the report. Sourced by
# bin/hostwarden-impact, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the report ---------------------------------------------------

fields >"$WORK/fields"
awk -v kind="$KIND" -v T="$HOSTS" -v fields="$WORK/fields" -v idx="$IDX" '
  BEGIN {
    while ((getline l < fields) > 0) {
      split(l, a, "\t"); h = tolower(a[1]); k = a[2]
      if (k == "Role" || k == "Appliance" || k == "Web server" || k == "Database" \
          || k == "MTA" || k == "DNS resolver" || k == "Container runtime")
        info[h] = info[h] (info[h] == "" ? "" : "; ") k ": " a[3]
      if (k == "Last connected") { split(a[3], d, /[ \t]/); last[h] = d[1] }
      if (k == "SSH" && a[3] ~ /^untested/) reg[h] = 1
    }
    # The inventories of the origins and of their clusters.
    n = split(T, t, " ")
    for (i = 1; i <= n; i++) inv[t[i]] = ++ninv
    while ((getline l < idx) > 0) {
      split(l, a, "\t")
      if (a[1] == "C" && (a[2] in inv) && !(("cluster:" a[3]) in inv)) inv["cluster:" a[3]] = ++ninv
      if (a[1] == "Q") nm[a[2]] = nm[a[2]] (nm[a[2]] == "" ? "" : ", ") a[3]
      if (a[1] == "I") invd[a[2]] = a[3]
    }
    for (o in inv) owner[inv[o]] = o
    title["guest"] = "Guests, out with it"
    title["via"] = "Guests reached through their host, out with it"
    title["behind"] = "Behind it as a jump host, out with it"
    title["reached"] = "Reached through it, out with it"
    title["depends"] = "Depending on it, hit"
    title["cluster"] = "Cluster peers, hit"
    title["unreadable"] = "Way in not readable, counted in on the safe side"
    nr = split("guest via behind reached depends cluster unreadable", rels, " ")
  }
  function name(o) { return o ~ /^cluster:/ ? "cluster " substr(o, 9) : o }
  {
    h = $1; r = $2; th = $3; det = ""
    if (NF > 3) { det = $0; sub(/^[^ ]+ [^ ]+ [^ ]+ /, "", det) }
    hosts[++nh] = h
    if (r == "origin") { origins = origins (origins == "" ? "" : ", ") h; no++; next }
    line = "  " h
    if (r == "depends") line = line " — " det ", on " th
    else if (r == "cluster") line = line " — cluster " det ", with " th
    else if (r == "behind") line = line " — through " th " (" det ")"
    else if (r != "unreadable") line = line " — on " th (det != "" ? " (" det ")" : "")
    if (info[h] != "") line = line "\n      " info[h]
    body[r] = body[r] line "\n"; cnt[r]++; total++
  }
  END {
    s = total == 1 ? "" : "s"
    who = no == 1 ? "it" : "them"
    printf "What %s of %s would reach: %d host%s besides %s\n", kind, origins, \
      total, s, who
    for (i = 1; i <= nr; i++) if (cnt[rels[i]]) printf "%s:\n%s", title[rels[i]], body[rels[i]]
    for (i = 1; i <= ninv; i++) if (owner[i] in nm)
      printf "Guests of %s with no memory of their own: %s\n", name(owner[i]), nm[owner[i]]
    for (i = 1; i <= nh; i++) if (hosts[i] in reg)
      printf "Only registered, never onboarded: %s; onboarding it records what depends on it\n", hosts[i]
    # The oldest record the radius relied on, and what refreshes it.
    od = ""
    for (i = 1; i <= nh; i++) {
      h = hosts[i]
      if (h in last) {
        if (od == "" || last[h] < od) { od = last[h]; ow = "the memory of " h "; housekeeping on it refreshes it" }
      } else if (!(h in reg)) nodate = nodate " " h
    }
    for (i = 1; i <= ninv; i++) {
      o = owner[i]
      if ((o in invd) && (od == "" || invd[o] < od)) {
        od = invd[o]; ow = "the guest inventory of " name(o) "; the next connection to " (o ~ /^cluster:/ ? "a member" : "it") " refreshes it"
      }
    }
    if (od != "") printf "Oldest record relied on: %s, %s\n", od, ow
    if (nodate != "") printf "No Last connected: in memory:%s\n", nodate
  }' "$WORK/radius"
