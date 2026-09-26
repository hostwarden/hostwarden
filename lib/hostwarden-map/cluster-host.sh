# lib/hostwarden-map/cluster-host.sh — steps 7 and 8: one file per
# cluster and per hypervisor outside one, and the pruning of stale
# maps. Sourced by bin/hostwarden-map, in the order its PARTS lists,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- step 7: one file per cluster ------------------------------------
render_cluster() {
  cl=$1
  cflow="$WORK/cluster-flow.mmd"
  ctable="$WORK/cluster-table.md"
  cdate=""

  awk -F '\t' -v c="$cl" '$1 == c { print }' "$CLUSTERMEMBERS" \
    | LC_ALL=C sort -t '	' -k2,2 >"$WORK/cluster-members.tsv"
  us "$WORK/cluster-members.tsv"
  guest_rows "cluster:$cl" >"$WORK/cluster-guests.tsv"
  us "$WORK/cluster-guests.tsv"

  {
    echo "flowchart TB"
    : >"$WORK/cluster-placed"
    # shellcheck disable=SC2034 # c2 is the cluster column, already known as $cl
    while IFS="$US" read -r c2 member mdir; do
      [ -n "$member" ] || continue
      mid="m_$(id_sh "$member")"
      printf '  subgraph %s["%s"]\n' "$mid" "$(esc_sh "$member")"
      echo "    direction TB"
      while IFS="$US" read -r owner gid gname gkind gstate gip gdir graw; do
        [ -n "$owner" ] || continue
        # A bare `*" on $member"*` would also match "pve10" for
        # member "pve1" -- glob wildcards have no word boundary, so
        # the character right after the name is checked by hand:
        # only a comma, a period or a space ever follows it there.
        case " $graw " in
          *" on $member,"* | *" on $member."* | *" on $member "*) ;;
          *) continue ;;
        esac
        echo "$gid|$gname" >>"$WORK/cluster-placed"
        guest_node "    " "$gid" "$gname" "$gkind" "$gstate" "$gdir"
      done <"$WORK/cluster-guests.tsv.us"
      echo "  end"
    done <"$WORK/cluster-members.tsv.us"

    cut -f2,3 "$WORK/cluster-guests.tsv" | tr '\t' '|' >"$WORK/cluster-guests-all"
    ughosts=$(unplaced_of "$WORK/cluster-guests-all" "$WORK/cluster-placed")
    if [ -n "$ughosts" ]; then
      echo '  subgraph unplaced["Guests not placed on a member"]'
      echo "    direction TB"
      printf '%s\n' "$ughosts" | while IFS='|' read -r gid gname; do
        [ -n "$gid" ] || continue
        row=$(awk -F '\t' -v i="$gid" -v n="$gname" '$2 == i && $3 == n { print; exit }' \
          "$WORK/cluster-guests.tsv")
        gkind=$(printf '%s' "$row" | cut -f4); gstate=$(printf '%s' "$row" | cut -f5)
        gdir=$(printf '%s' "$row" | cut -f7)
        guest_node "    " "$gid" "$gname" "$gkind" "$gstate" "$gdir"
      done
      echo "  end"
    fi

    # shellcheck disable=SC2034 # c2 is the cluster column, already known as $cl
    while IFS="$US" read -r c2 member mdir; do
      [ -n "$member" ] || continue
      printf '  class m_%s site\n' "$(id_sh "$member")"
    done <"$WORK/cluster-members.tsv.us"
    [ -n "$ughosts" ] && echo '  class unplaced site'
  } >"$cflow"

  {
    echo "### Members"
    echo
    echo "| Host | Memory |"
    echo "| :--- | :--- |"
    # shellcheck disable=SC2034 # c2 is the cluster column, already known as $cl
    while IFS="$US" read -r c2 member mdir; do
      [ -n "$member" ] || continue
      if [ -n "$mdir" ]; then
        printf '| %s | [memory](../../machines/%s/memory.md) |\n' "$member" "$mdir"
        md=$(awk -F '\t' -v h="$mdir" '$1 == h { print $7; exit }' "$HOSTS")
        cdate=$(date_max "$cdate" "$md")
      else
        printf '| %s | not known |\n' "$member"
      fi
    done <"$WORK/cluster-members.tsv.us"
    echo
    guest_table "$WORK/cluster-guests.tsv.us"
  } >"$ctable"

  cslug=$(slug_sh "$cl")
  ci=$(awk -F '\t' -v c="$cl" '$1 == c { print $2; exit }' "$CLUSTERKIND")
  write_map_file "$MAPS/clusters/$cslug.md" \
    "memory/clusters/$cl/cluster.md, its guests.md and its members' memory.md" \
    "Cluster: $cl${ci:+ ($ci)}" "[Index](../README.md) · [WAN](../wan.md)" \
    "$cflow" "$ctable"
  CLUSTER_DATE=$cdate
}

# --- step 8: one file per hypervisor outside a cluster ----------------
render_host() {
  hv=$1
  hflow="$WORK/host-flow.mmd"
  htable="$WORK/host-table.md"

  guest_rows "$hv" >"$WORK/host-guests.tsv"
  us "$WORK/host-guests.tsv"

  {
    echo "flowchart TB"
    hnid="h_$(id_sh "$hv")"
    printf '  subgraph %s["%s"]\n' "$hnid" "$(esc_sh "$hv")"
    echo "    direction TB"
    while IFS="$US" read -r owner gid gname gkind gstate gip gdir graw; do
      [ -n "$owner" ] || continue
      guest_node "    " "$gid" "$gname" "$gkind" "$gstate" "$gdir"
    done <"$WORK/host-guests.tsv.us"
    echo "  end"
    # No edge leaves this level today, so nothing has to come first --
    # but the moment one does (a link out to the site, say), it goes
    # above this line, never below it (docs/adr/20260925-mermaid-class-order.md).
    printf '  class %s site\n' "$hnid"
  } >"$hflow"

  guest_table "$WORK/host-guests.tsv.us" >"$htable"

  hslug=$(slug_sh "$hv")
  write_map_file "$MAPS/hosts/$hslug.md" \
    "memory/machines/$hv/memory.md and its guests.md" \
    "Hypervisor: $hv" "[Index](../README.md) · [WAN](../wan.md)" \
    "$hflow" "$htable"
  HOST_DATE=$(awk -F '\t' -v h="$hv" '$1 == h { print $7; exit }' "$HOSTS")
}

render_wan
: >"$WORK/site-dates.tsv"
cut -f1 "$SITES" | LC_ALL=C sort -u | while IFS='	' read -r s; do
  [ -n "$s" ] || continue
  render_site "$s"
  printf '%s\t%s\n' "$s" "$SITE_DATE" >>"$WORK/site-dates.tsv"
done

: >"$WORK/cluster-dates.tsv"
cut -f1 "$CLUSTERMEMBERS" | LC_ALL=C sort -u | while IFS='	' read -r cl; do
  [ -n "$cl" ] || continue
  render_cluster "$cl"
  printf '%s\t%s\n' "$cl" "$CLUSTER_DATE" >>"$WORK/cluster-dates.tsv"
done

: >"$WORK/host-dates.tsv"
awk -F '\t' '$4 == "hypervisor" && $3 == "" && $8 == "" { print $1 }' "$HOSTS" \
  | LC_ALL=C sort -u | while IFS='	' read -r hv; do
  [ -n "$hv" ] || continue
  render_host "$hv"
  printf '%s\t%s\n' "$hv" "$HOST_DATE" >>"$WORK/host-dates.tsv"
done

# prune_stale <dir> <names-file> -- every "*.md" under <dir> whose
# slug is not the slug of a name <names-file> lists, removed: a
# site, cluster or hypervisor renamed or gone from memory leaves no
# map claiming to still be current (Codex round 1, #330).
prune_stale() {
  ps_dir=$1 ps_names=$2
  : >"$WORK/prune-keep"
  if [ -f "$ps_names" ]; then
    cut -f1 "$ps_names" | while IFS= read -r ps_n; do
      [ -n "$ps_n" ] && printf '%s\n' "$(slug_sh "$ps_n")"
    done >"$WORK/prune-keep"
  fi
  for ps_f in "$ps_dir"/*.md; do
    [ -f "$ps_f" ] || continue
    ps_slug=${ps_f##*/}; ps_slug=${ps_slug%.md}
    grep -qxF "$ps_slug" "$WORK/prune-keep" || rm -f "$ps_f"
  done
}
# An empty keep-list from a workspace that plainly has the memory
# behind it is not an empty fleet, it is a read that came back short
# -- topology.md or a memory.md caught mid-write by another session,
# say. Pruning on that reading would delete every current map on the
# strength of a transient miss, so each level only prunes once its
# own source actually produced something this run -- $HOSTS alone
# would not catch topology.md coming back empty while every host's
# own memory.md still reads fine, since the sites and clusters
# prune-lists come from $SITES and $CLUSTERMEMBERS, not $HOSTS.
[ -s "$SITES" ] && prune_stale "$MAPS/sites" "$WORK/site-dates.tsv"
[ -s "$CLUSTERMEMBERS" ] && prune_stale "$MAPS/clusters" "$WORK/cluster-dates.tsv"
[ -s "$HOSTS" ] && prune_stale "$MAPS/hosts" "$WORK/host-dates.tsv"
