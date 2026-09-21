# Email transport: sending from the workstation

Step 5L of the `hostwarden-email` skill, reached when gate 0
decided this workstation sends. Nothing here touches the managed
host.

**5L.1 Probe for a local transport:**
`command -v sendmail || test -x /usr/sbin/sendmail ||
command -v msmtp`. Those are the two
step 7 pipes into; `mail` or `mailx` alone does not count,
because it cannot take the headers step 7 writes. On
macOS, also confirm Postfix is loaded:
`launchctl print system/com.apple.postfix.master` exits 0.

**5L.2 No install fallback.** If nothing is there, refuse
cleanly: "no mail tooling on this workstation — install msmtp
locally and rerun, or pick remote next time by deleting
`Email source: local` from `memory.md`." Never auto-install on
the user's own machine: a workstation is not a host Hostwarden
administers, and the consent gates that make a remote install
safe do not cover it.

**5L.3 The sender is the current shell user.** There is no
identity to choose and no privilege to drop.

**5L.4** Continue at the shared step **6 (Compose)**. At steps
**7 (Send)** and **8 (Verify)** the commands run locally;
`references/send-verify.md` carries the local branch of both,
including which log to read.
