# Memory

User preferences and SSH usernames (default and
per-server overrides) are stored in
`memory/user.md`.
Server details are stored in
`memory/servers/<hostname>/memory.md`.
Local changelogs are stored in
`memory/servers/<hostname>/changelog.log`.
Session to-do lists are stored in
`memory/servers/<hostname>/todo.md` (only present
while multi-step work is unfinished). Plans that
span sessions are in `memory/plans/`, masters of
deployed files under each host's `files/` and in
`memory/fleet/`, workstation scripts in `memory/tools/`.
A hypervisor cluster or pool, its members and its
guest inventory, is stored in
`memory/clusters/<name>/`.
Cross-server network facts (topology, VPN
connectivity, reachability) are stored in
`memory/network.md`.
Read the relevant files before connecting to a known
server.
