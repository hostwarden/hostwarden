### Fixed

- **A Proxmox VE VM's guest agent gets small calls with a
  timeout.** Every `qm guest exec` names its timeout and carries at
  most 2 KiB of script, so a large bundle is split rather than sent
  in one call that could leave the agent answering nothing. A call
  whose timeout ran out is read back instead of sent again, and a VM
  whose agent stops answering is reported, never restarted without
  asking.
