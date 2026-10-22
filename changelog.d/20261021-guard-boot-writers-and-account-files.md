### Changed

- **The guard blocks boot writers and direct writes to the account
  files.** `efibootmgr` with a write flag, `grub-install`,
  `update-grub`, `grub-mkconfig -o`, `bootctl install` and its
  siblings, `bless` beyond `--info`, `efivar -w` and writes under the
  EFI variables mount are taboos, lifted for OS installation the way
  disk writes are. So are `vipw`, `vigr` and a direct write to
  `/etc/passwd`, `shadow`, `group`, `gshadow` or `master.passwd`;
  `useradd`, `usermod`, `passwd` and `pw` stay the way to change
  accounts. Reading all of them is unchanged.
