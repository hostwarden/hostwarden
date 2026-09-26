# lib/hostwarden-map/classify.sh — step 4: every host classified,
# and the shared node and table writers. Sourced by
# bin/hostwarden-map, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- step 4: classify every host ------------------------------------
#
# HOSTS: <host> TAB <site> TAB <cluster> TAB <kind> TAB <appliance>
#        TAB <ip> TAB <date> TAB <runson> TAB <hasfinding 0|1>
#        TAB <stale 0|1>
# <kind> is router, hypervisor, storage or host (a plain server or a
# VM, told apart only by <runson>, which is empty for anything that
# is not itself a guest). <date> is the later of Onboarded: and
# Housekeeping:, the freshness rules/machine-memory.md → Onboarded and
# stale lines gives a host'"'"'s own record. <hasfinding> is set when
# a memory/topology.md Topology findings entry names this host as a
# whole word -- the only link this script draws between free prose
# and a specific node, so it is a heuristic, not a parse.
HOSTS="$WORK/hosts.tsv"
: >"$HOSTS"
HVSET="$WORK/hvset"
: >"$HVSET"
for g in "$M"/machines/*/guests.md; do
  [ -f "$g" ] || continue
  h=${g%/guests.md}; h=${h##*/}
  echo "$h" >>"$HVSET"
done

if [ -s "$HOSTFIELDS" ]; then
  awk -F '\t' -v hvfile="$HVSET" -v findingsfile="$FINDINGS" '
    BEGIN {
      while ((getline h < hvfile) > 0) hv[h] = 1
      while ((getline fl < findingsfile) > 0) {
        split(fl, ff, "\t")
        findingtext = findingtext " " ff[2]
      }
    }
    { host[$1] = 1 }
    $2 == "Site" { s = $3; sub(/ \(.*/, "", s); site[$1] = s }
    $2 == "Cluster" { c = $3; sub(/[ \t,].*/, "", c); cluster[$1] = c }
    $2 == "Appliance" { appl[$1] = $3 }
    $2 == "Role" { role[$1] = $3 }
    $2 == "Mode" { mode[$1] = $3 }
    $2 == "IP" { v = $3; sub(/[ \t,;()].*/, "", v); ip[$1] = v }
    $2 == "Onboarded" { v = $3; sub(/[ \t].*/, "", v); onb[$1] = v }
    $2 == "Housekeeping" { v = $3; sub(/[ \t].*/, "", v); hk[$1] = v }
    $2 == "Runs on" { v = $3; sub(/[ \t].*/, "", v); ro[$1] = v }
    END {
      for (h in host) {
        a = appl[h]; r = role[h]; m = mode[h]; kind = "host"
        # The local machine itself -- Mode: local, whatever its
        # Role: is (a Mac mini a team builds on is a server, still
        # the local workstation) -- or the two names its own
        # .gitignore falls back to for a workspace from before that
        # field was resolved, is personal and never shared
        # (rules/machine-memory.md → Personal versus shared;
        # rules/network-topology.md → Excluded from the store) --
        # so it never reaches a map.
        if (tolower(m) ~ /^local/ || r ~ /^workstation/ \
            || h == "localhost" || h == "127.0.0.1") continue
        # UniFi OS runs on gateways, on NAS consoles and on Cloud
        # Keys alike (rules/appliance/unifi-os.md); the model name
        # after the comma is the only thing that tells them apart,
        # and a Cloud Key alone does not say whether it runs UniFi
        # Network (router) or only Protect (host) -- the Apps: line
        # would, but this script does not read it, so it is left at
        # the "host" default rather than guessed either way.
        if (a ~ /UniFi OS/ && a ~ /NAS/) kind = "storage"
        else if (a ~ /UniFi OS/ && a ~ /Cloud Key/) kind = "host"
        else if (a ~ /OPNsense|pfSense|OpenWrt|UniFi OS|RouterOS|VyOS|MikroTik/ \
          || r ~ /router|firewall|gateway/) kind = "router"
        else if ((h in hv) || a ~ /Proxmox VE|Proxmox Backup|libvirt|Incus|LXD|XCP-ng|ESXi/) kind = "hypervisor"
        else if (a ~ /TrueNAS|Synology|QTS|QuTS hero|Unraid|OpenMediaVault|UGOS Pro|ZimaOS|storage appliance/) kind = "storage"
        d = (onb[h] > hk[h]) ? onb[h] : hk[h]
        if (d == "") d = "not known"
        # A finding'"'"'s own prose names a host the short way (a
        # routing table does not print the FQDN), so both forms are
        # tried, and a name in parentheses -- "via 192.0.2.5
        # (nas2) is dead" -- counts too, the same as one that
        # trails the name.
        hshort = h; sub(/\..*/, "", hshort)
        hf = 0
        if (match(findingtext, "(^| |\\()" h "([ .,:;)'"'"']|$)")) hf = 1
        else if (match(findingtext, "(^| |\\()" hshort "([ .,:;)'"'"']|$)")) hf = 1
        print h "\t" (site[h] == "" ? "not known" : site[h]) "\t" cluster[h] \
          "\t" kind "\t" a "\t" ip[h] "\t" d "\t" ro[h] "\t" hf
      }
    }
  ' "$HOSTFIELDS" >"$WORK/hosts-raw.tsv" || die "host classification failed"
  LC_ALL=C sort "$WORK/hosts-raw.tsv" >"$WORK/hosts-unstaled.tsv"
fi
: >"$HOSTS"
if [ -s "$WORK/hosts-unstaled.tsv" ]; then
  us "$WORK/hosts-unstaled.tsv"
  while IFS="$US" read -r h s c k a ip d ro hf; do
    st=0
    is_stale "$d" && st=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$h" "$s" "$c" "$k" "$a" "$ip" "$d" "$ro" "$hf" "$st"
  done <"$WORK/hosts-unstaled.tsv.us" >"$HOSTS"
fi
us "$HOSTS"

# class_of <kind> <stale> -- the classDef name a node with this kind
# and staleness gets. <kind> is router, hypervisor, host or storage;
# hypervisor has no fill of its own, and takes host'"'"'s.
# class_of <kind> <stale 0|1> <hasfinding 0|1> -- a topology finding
# is the more actionable of the two states, so it wins when a host
# is somehow both stale and named in a finding.
class_of() {
  co_k=$1
  case $co_k in router | storage) ;; *) co_k=host ;; esac
  if [ "${3:-0}" = 1 ]; then co_k="$co_k-finding"
  elif [ "$2" = 1 ]; then co_k="$co_k-stale"
  fi
  printf '%s' "$co_k"
}

# shape_of <kind> <nid> <label> -- one Mermaid node line, the shape
# rules/network-topology.md'"'"'s design gives each kind.
shape_of() {
  case $1 in
    router) printf '  %s{{"%s"}}\n' "$2" "$3" ;;
    hypervisor) printf '  %s["%s"]\n' "$2" "$3" ;;
    storage) printf '  %s[("%s")]\n' "$2" "$3" ;;
    container) printf '  %s[["%s"]]\n' "$2" "$3" ;;
    uplink) printf '  %s(["%s"])\n' "$2" "$3" ;;
    *) printf '  %s("%s")\n' "$2" "$3" ;;
  esac
}

# host_node <indent> <host> <kind> <appliance> <stale 0|1> <prefix> --
# one host'"'"'s shape, class and click line: shared by the WAN level
# and a site'"'"'s ranges, which differ only in how many "../" reach
# back to machines/ (<prefix>, "../machines" or "../../machines").
host_node() {
  hn_ind=$1 hn_h=$2 hn_k=$3 hn_a=$4 hn_st=$5 hn_prefix=$6 hn_fnd=${7:-0}
  hn_nid="h_$(id_sh "$hn_h")"
  hn_fact=${hn_a:-$hn_k}
  printf '%s' "$hn_ind"
  shape_of "$hn_k" "$hn_nid" "$(esc_sh "$hn_h")<br/>$(esc_sh "$hn_fact" | cut -c1-26)"
  printf '%sclass %s %s\n' "$hn_ind" "$hn_nid" "$(class_of "$hn_k" "$hn_st" "$hn_fnd")"
  printf '%sclick %s "%s/%s/memory.md"\n' "$hn_ind" "$hn_nid" "$hn_prefix" "$hn_h"
}

# unplaced_of <candidates-file> <placed-file> -- every line of
# <candidates-file>, sorted and uniqued, that never appeared in
# <placed-file> (which may not exist yet: nothing has been placed).
# The caller reduces its own table to the one key column, or the
# composite key, this compares on before calling it.
unplaced_of() {
  LC_ALL=C sort -u "$1" >"$WORK/unplaced-c"
  LC_ALL=C sort -u "$2" >"$WORK/unplaced-p" 2>/dev/null || : >"$WORK/unplaced-p"
  comm -23 "$WORK/unplaced-c" "$WORK/unplaced-p"
}

# fence_diagram <bodyfile> -- wraps a Mermaid body (already indented
# two spaces, no fences, no classDef) with its opening fence, the
# shared CLASSDEFS and its closing fence, on stdout.
fence_diagram() {
  printf '```mermaid\n'
  cat "$1"
  printf '%s\n' "$CLASSDEFS"
  printf '```\n'
}

# guest_table <guests.tsv.us> -- the "### Guests" table, heading
# included: every level that lists guests (cluster, hypervisor)
# shares this shape.
guest_table() {
  echo "### Guests"
  echo
  echo "| ID | Name | Kind | State | IP | Memory |"
  echo "| :--- | :--- | :--- | :--- | :--- | :--- |"
  while IFS="$US" read -r owner gid gname gkind gstate gip gdir graw; do
    [ -n "$owner" ] || continue
    if [ -n "$gdir" ]; then
      printf '| %s | %s | %s | %s | %s | [memory](../../machines/%s/memory.md) |\n' \
        "$gid" "$gname" "$gkind" "$gstate" "${gip:-not known}" "$gdir"
    else
      printf '| %s | %s | %s | %s | %s | none |\n' \
        "$gid" "$gname" "$gkind" "$gstate" "${gip:-not known}"
    fi
  done <"$1"
}

# write_map_file <outfile> <comment> <heading> <breadcrumb> <flowfile>
# <tablefile> -- the shape every level's own file takes: the
# skip-wrap marker (bin/hostwarden-wrap → GENRE), the heading, the
# breadcrumb back to the index (and WAN, for everything but WAN
# itself), the diagram, the legend, the table, the footer.
write_map_file() {
  wmf_out=$1 wmf_comment=$2 wmf_heading=$3 wmf_breadcrumb=$4 wmf_flow=$5 wmf_table=$6
  {
    printf '<!-- Generated by bin/hostwarden-map from %s. Do not edit by hand. -->\n' "$wmf_comment"
    echo
    echo "# $wmf_heading"
    echo
    echo "$wmf_breadcrumb"
    echo
    fence_diagram "$wmf_flow"
    echo
    legend
    echo
    cat "$wmf_table"
    echo
    echo "Generated by Hostwarden $HWVERSION."
  } >"$wmf_out"
}
