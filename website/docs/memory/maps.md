---
sidebar_position: 7
title: Infrastructure maps
description: Mermaid maps of your sites, hypervisors and clusters, drawn
  from the workspace and never by hand — with real examples.
---

# Infrastructure maps

Out of what the workspace records, `bin/hostwarden-map` draws Mermaid
maps: the sites and the links between them, the ranges and hosts of each
site, and the guests of each hypervisor and cluster. The maps are
computed from memory alone, never drawn or edited by hand, so they
cannot drift from what Hostwarden knows. `bin/hostwarden-sync commit`
redraws them before every workspace commit, so a map is always committed
together with the memory it came from.

They are plain Markdown files with a Mermaid diagram first and a table
of the full fields after it, under `memory/maps/`. GitHub and Forgejo
render them with no build step; any Mermaid viewer does too.

## The levels

| File                       | Shows                                     |
| -------------------------- | ----------------------------------------- |
| `maps/README.md`           | the index, one line per map               |
| `maps/wan.md`              | sites, their gateways, the links between  |
| `maps/sites/<site>.md`     | a site's ranges and hosts                 |
| `maps/clusters/<name>.md`  | a cluster's members and guests            |
| `maps/hosts/<host>.md`     | a hypervisor outside a cluster, its guests|

Every node links back to the host's `memory.md` in the workspace. The
examples below are the real output for a small fictional workspace —
two sites, a firewall, a NAS, a standalone Proxmox VE host and a
two-node cluster — with those links left out, since the memory they
point to is not part of this site.

## WAN

Two sites, joined over the WAN. `nas1` and `pve1` carry a thick amber
border: a topology finding names them — here, `nas1` routes a range via
`pve1`, whose IPv4 forwarding is off. `pve3` has a dashed border: its
record is older than 90 days. The two sites are joined by the one
WAN link `memory/topology.md` records between them, a tunnel from
`home` to `colo-fra`. A site with no WAN link on record hangs off the
Internet node with a dashed grey line instead; here both have one, so
the Internet node stands alone.

```mermaid
flowchart LR
  inet(("Internet"))
  class inet internet
  subgraph site_colo_fra["colo-fra"]
    direction TB
      h_pve2_example_com["pve2.example.com<br/>Proxmox VE 9.0.3"]
    class h_pve2_example_com host
      h_pve3_example_com["pve3.example.com<br/>Proxmox VE 9.0.3"]
    class h_pve3_example_com host-stale
  end
  subgraph site_home["home"]
    direction TB
      h_fw1_example_com{{"fw1.example.com<br/>OPNsense 25.7"}}
    class h_fw1_example_com router
      h_nas1_example_com[("nas1.example.com<br/>TrueNAS SCALE 25.04")]
    class h_nas1_example_com storage-finding
      h_pve1_example_com["pve1.example.com<br/>Proxmox VE 9.0.3"]
    class h_pve1_example_com host-finding
  end
  site_home === site_colo_fra
  class site_colo_fra site
  class site_home site
  classDef site fill:none,stroke:#8a8a8a,stroke-width:2px
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
  classDef unknown fill:#f4f4f4,stroke:#8a8a8a,color:#333333,stroke-dasharray:4 3
```

Below the diagram, the file lists the sites, the site-to-site links and
the finding in full:

- **WARN** — nas1 routes 10.8.0.0/24 via 192.0.2.5 (pve1), and pve1's
  IPv4 forwarding is off (profile of 2026-09-20).

## A site

The site `home`, by range. The firewall is a hexagon, storage and
appliances are cylinders. The IPv6 range has no host drawn in it,
because the hosts' memory records IPv4 addresses.

```mermaid
flowchart TB
  subgraph range_192_0_2_0_24["192.0.2.0/24<br/>VLAN 10"]
    direction TB
      h_fw1_example_com{{"fw1.example.com<br/>OPNsense 25.7"}}
    class h_fw1_example_com router
      h_nas1_example_com[("nas1.example.com<br/>TrueNAS SCALE 25.04")]
    class h_nas1_example_com storage-finding
      h_pve1_example_com["pve1.example.com<br/>Proxmox VE 9.0.3"]
    class h_pve1_example_com host-finding
  end
  subgraph range_2001_db8___64["2001:db8::/64<br/>VLAN 10"]
    direction TB
  end
  class range_192_0_2_0_24 site
  class range_2001_db8___64 site
  classDef site fill:none,stroke:#8a8a8a,stroke-width:2px
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
  classDef unknown fill:#f4f4f4,stroke:#8a8a8a,color:#333333,stroke-dasharray:4 3
```

## A hypervisor

`pve1` and its guests: VMs are rounded, containers have double edges. A
stopped guest is drawn as well — the guest list holds every guest,
running or not.

```mermaid
flowchart TB
  subgraph h_pve1_example_com["pve1.example.com"]
    direction TB
      g_101_web1("101 web1<br/>running")
    class g_101_web1 host
      g_102_db1[["102 db1<br/>running"]]
    class g_102_db1 host
      g_110_mail_old("110 mail-old<br/>stopped")
    class g_110_mail_old host
  end
  class h_pve1_example_com site
  classDef site fill:none,stroke:#8a8a8a,stroke-width:2px
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
  classDef unknown fill:#f4f4f4,stroke:#8a8a8a,color:#333333,stroke-dasharray:4 3
```

| ID  | Name     | Kind      | State   | IP         | Memory |
| --- | -------- | --------- | ------- | ---------- | ------ |
| 101 | web1     | VM        | running | 192.0.2.21 | memory |
| 102 | db1      | container | running | 192.0.2.22 | memory |
| 110 | mail-old | VM        | stopped | not known  | none   |

## A cluster

The cluster `prod`, each guest under the member it runs on right now.
After a live migration or an HA failover, the next inventory moves it.

```mermaid
flowchart TB
  subgraph m_pve2["pve2"]
    direction TB
      g_201_shop1("201 shop1<br/>running")
    class g_201_shop1 host
  end
  subgraph m_pve3["pve3"]
    direction TB
      g_202_shopdb1("202 shopdb1<br/>running")
    class g_202_shopdb1 host
  end
  class m_pve2 site
  class m_pve3 site
  classDef site fill:none,stroke:#8a8a8a,stroke-width:2px
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
  classDef unknown fill:#f4f4f4,stroke:#8a8a8a,color:#333333,stroke-dasharray:4 3
```

## Reading a map

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

- **A gap is drawn as a gap.** A host with no site on record, a range
  no site claims, a field memory does not have: "not known", never a
  guess.
- **The date is the newest source.** The index names, per map, the
  newest memory it was drawn from.
- **Personal files stay out.** The maps never read `user.md`, the
  access lists or `ssh_config`, and never draw your own workstation, so
  a shared workspace can share its maps.

## Drawing them

```
bin/hostwarden-map
```

It runs locally, reads only the workspace, and writes only under
`memory/maps/`. Run twice over the same memory on the same day, it
writes the same bytes, so a map only changes in git when the
infrastructure did. Across days, a host crossing the 90-day line turns
dashed — a map that never showed staleness would not be telling the
truth either.
