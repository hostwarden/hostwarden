# lib/hostwarden-map/site.sh — step 6: one file per site. Sourced by
# bin/hostwarden-map, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- step 6: one file per site ---------------------------------------
render_site() {
  s=$1
  sflow="$WORK/site-flow.mmd"
  stable="$WORK/site-table.md"
  sdate=""

  {
    echo "flowchart TB"

    # One subgraph per range of this site, ordered by VLAN (numeric
    # VLANs first, then "untagged", then "not known"), gateway'"'"'s own
    # host drawn first inside it; a host whose IP matches none of
    # them falls into one trailing "Other hosts" group instead of
    # being left off the map.
    awk -F '\t' -v s="$s" '$2 == s { print }' "$RANGES" >"$WORK/site-ranges.tsv"
    us "$WORK/site-ranges.tsv"
    : >"$WORK/site-hosts-placed"
    awk -F '\t' -v s="$s" '$2 == s && $8 == "" { print }' "$HOSTS" \
      | LC_ALL=C sort -t '	' -k1,1 >"$WORK/site-hosts.tsv"
    us "$WORK/site-hosts.tsv"

    # rules/network-topology.md -> Range identity: two records of the
    # same prefix stay separate lines unless merged is confirmed, so
    # a site can genuinely have two range rows for one prefix. Giving
    # them the same subgraph ID would draw one merged box, and
    # placing a matching host by IP alone would guess which of the
    # two unconfirmed networks it is actually on -- a wrong merge
    # this rule specifically warns against. Duplicated prefixes get a
    # row counter in their ID and an honest label instead, and a host
    # inside one falls to "Other hosts" below rather than either.
    awk -F '\t' '{c[$1]++} END { for (p in c) if (c[p] > 1) print p }' \
      "$WORK/site-ranges.tsv" >"$WORK/site-range-dups.tsv"
    srow=0
    sort -t "$US" -k3,3n "$WORK/site-ranges.tsv.us" | while IFS="$US" read -r prefix rsite vlan gw rdate rraw; do
      [ -n "$prefix" ] || continue
      srow=$((srow + 1))
      rid="range_$(id_sh "$prefix")"
      dup=0
      grep -qxF "$prefix" "$WORK/site-range-dups.tsv" 2>/dev/null && dup=1
      vlbl=$vlan; [ "$vlan" = "not known" ] && vlbl="VLAN not known"
      [ "$vlan" != "not known" ] && [ "$vlan" != untagged ] && vlbl="VLAN $vlan"
      dupnote=""
      if [ "$dup" = 1 ]; then
        rid="${rid}_${srow}"
        dupnote="<br/>$(esc_sh "same prefix, not shown to be one network")"
      fi
      printf '  subgraph %s["%s<br/>%s%s"]\n' "$rid" "$(esc_sh "$prefix")" "$(esc_sh "$vlbl")" "$dupnote"
      echo "    direction TB"
      if [ "$dup" != 1 ]; then
        # shellcheck disable=SC2034 # hs is the row's own site; not needed once filtered to it
        while IFS="$US" read -r h hs c k a ip d ro hf st; do
          [ -n "$h" ] || continue
          [ -n "$ip" ] || continue
          in_cidr "$ip" "$prefix" || continue
          echo "$h" >>"$WORK/site-hosts-placed"
          host_node "    " "$h" "$k" "$a" "$st" "../../machines" "$hf"
        done <"$WORK/site-hosts.tsv.us"
      fi
      echo "  end"
    done

    cut -f1 "$WORK/site-hosts.tsv" >"$WORK/site-hosts-all"
    ohosts=$(unplaced_of "$WORK/site-hosts-all" "$WORK/site-hosts-placed")
    if [ -n "$ohosts" ]; then
      echo '  subgraph other["Other hosts, range not known"]'
      echo "    direction TB"
      printf '%s\n' "$ohosts" | while IFS= read -r h; do
        [ -n "$h" ] || continue
        row=$(awk -F '\t' -v h="$h" '$1 == h { print; exit }' "$WORK/site-hosts.tsv")
        k=$(printf '%s' "$row" | cut -f4); a=$(printf '%s' "$row" | cut -f5)
        hf=$(printf '%s' "$row" | cut -f9); st=$(printf '%s' "$row" | cut -f10)
        host_node "    " "$h" "$k" "$a" "$st" "../../machines" "$hf"
      done
      echo "  end"
    fi

    # LAN-hop Topology edges whose two ranges both belong to this
    # site, one drawn once per (range, range) pair. A prefix this
    # site records more than once -- kept apart above as "not shown
    # to be one network", each in its own row-suffixed subgraph --
    # has no single range_<prefix> node any more: an edge naming it
    # is left undrawn rather than pointing at a node id_sh never
    # gave a subgraph, which Mermaid would otherwise invent as a
    # bare, unstyled extra node.
    : >"$WORK/site-wired"
    awk -F '\t' -v s="$s" '$2 == s { print $1 }' "$RANGES" | LC_ALL=C sort -u >"$WORK/site-prefixes"
    # shellcheck disable=SC2034 # ehost/eraw are read to consume the row; only the tag and the two ranges matter here
    sort -t "$US" -k1,1 "$EDGES.us" | while IFS="$US" read -r efrom eto etag ehost edate eraw; do
      [ "$etag" = "LAN hop" ] || continue
      grep -qxF "$efrom" "$WORK/site-prefixes" || continue
      grep -qxF "$eto" "$WORK/site-prefixes" || continue
      grep -qxF "$efrom" "$WORK/site-range-dups.tsv" 2>/dev/null && continue
      grep -qxF "$eto" "$WORK/site-range-dups.tsv" 2>/dev/null && continue
      key="$efrom|$eto"; str_gt "$efrom" "$eto" && key="$eto|$efrom"
      grep -qxF "$key" "$WORK/site-wired" 2>/dev/null && continue
      echo "$key" >>"$WORK/site-wired"
      printf '  range_%s --- range_%s\n' "$(id_sh "$efrom")" "$(id_sh "$eto")"
    done

    cut -f1 "$WORK/site-ranges.tsv" | LC_ALL=C sort -u | while IFS='	' read -r prefix; do
      [ -n "$prefix" ] || continue
      printf '  class range_%s site\n' "$(id_sh "$prefix")"
    done
    [ -n "$ohosts" ] && echo '  class other site'
  } >"$sflow"

  {
    echo "### Ranges"
    echo
    echo "| Prefix | Site | VLAN | Gateway | Date | Sources |"
    echo "| :--- | :--- | :--- | :--- | :--- | :--- |"
    while IFS="$US" read -r prefix rsite vlan gw rdate rraw; do
      [ -n "$prefix" ] || continue
      printf '| %s | %s | %s | %s | %s | %s |\n' \
        "$prefix" "$rsite" "$vlan" "${gw:-not known}" "$rdate" "$(esc_sh "$rraw")"
      sdate=$(date_max "$sdate" "$rdate")
    done <"$WORK/site-ranges.tsv.us"
    echo
    echo "### Hosts"
    echo
    echo "| Host | Role | IP | Memory |"
    echo "| :--- | :--- | :--- | :--- |"
    # shellcheck disable=SC2034 # hs is the row's own site; not needed once filtered to it
    while IFS="$US" read -r h hs c k a ip d ro hf st; do
      [ -n "$h" ] || continue
      printf '| %s | %s | %s | [memory](../../machines/%s/memory.md) |\n' \
        "$h" "${a:-$k}" "${ip:-not known}" "$h"
      sdate=$(date_max "$sdate" "$d")
    done <"$WORK/site-hosts.tsv.us"
  } >"$stable"

  slug=$(slug_sh "$s")
  write_map_file "$MAPS/sites/$slug.md" \
    "memory/topology.md and this site's hosts' memory.md" \
    "Site: $s" "[Index](../README.md) · [WAN](../wan.md)" "$sflow" "$stable"
  SITE_DATE=$sdate
}

# guest_row <owner> -- GUESTS.tsv'"'"'s rows for <owner> (a hypervisor'"'"'s
# own directory name, or cluster:<name>), sorted by numeric ID where
# the ID is a number, then by name (rules/hypervisors.md: a jail is
# named, not numbered).
guest_rows() {
  awk -F '\t' -v o="$1" '$1 == o { print }' "$GUESTS" | LC_ALL=C sort -t '	' -k2,2n \
    -k3,3
}

# guest_node <indent> <id> <name> <kind> <state> <ip> <dir> -- one
# guest'"'"'s shape, class and click, shape_of/class_of'"'"'s VM/container
# split by <kind>, "not known" wearing the unknown class regardless
# of what shape its kind gives it.
# Every one of its own variables prefixed gn_, never the plain
# gid/gname/... its callers read a row into: sh has no true local,
# and is_stale'"'"'s d/n once clobbered a caller'"'"'s $d this same way.
guest_node() {
  gn_ind=$1 gn_id=$2 gn_name=$3 gn_kind=$4 gn_state=$5 gn_dir=$6
  gn_nid="g_$(id_sh "$gn_id")_$(id_sh "$gn_name")"
  gn_lbl="$(esc_sh "$gn_id $gn_name")<br/>$(esc_sh "$gn_state")"
  gn_shape=vm
  case $gn_kind in container | jail) gn_shape=container ;; esac
  printf '%s' "$gn_ind"
  shape_of "$gn_shape" "$gn_nid" "$gn_lbl"
  gn_cls=host
  case $gn_kind in "not known") gn_cls=unknown ;; esac
  printf '%sclass %s %s\n' "$gn_ind" "$gn_nid" "$gn_cls"
  [ -n "$gn_dir" ] && printf '%sclick %s "../../machines/%s/memory.md"\n' "$gn_ind" "$gn_nid" "$gn_dir"
}
