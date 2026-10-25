### Fixed

- **Windows file names with umlauts arrive intact.** The PowerShell
  bundle for Windows hosts now starts with a line that sets the
  console output to UTF-8 wherever it prints names. Without it, `ü`, `ö` and `ß`
  in a file name came back in the OEM code page and read as garbage.
