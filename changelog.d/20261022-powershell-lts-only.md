### Changed

- **PowerShell 7 on Windows Server is installed from the newest LTS
  line.** The install used the newest stable release that still ships
  an MSI, which could be a release that stops getting fixes a few
  months after the next LTS ships. It now takes the newest LTS line
  still in support, read from Microsoft's lifecycle page. A host that
  already runs a non-LTS 7.x is reported, never downgraded, and an
  LTS line within 90 days of its end of support is a warning
  (`rules/os/windows.md` → Install PowerShell 7, The installed
  PowerShell 7).
- **Windows file reads name their encoding.** A file without a byte
  order mark is read as ANSI by Windows PowerShell 5.1 and as UTF-8
  by PowerShell 7; the rule now asks for an explicit `-Encoding` and
  rules out the system-wide UTF-8 switch (`rules/os/windows.md` →
  Common Pitfalls).
