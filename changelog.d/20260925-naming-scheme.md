### Added

- **Hostwarden can detect, propose and remember a fleet naming
  scheme.** After a few hosts are onboarded it recognises a shared
  hostname pattern and asks you to confirm it, or proposes a
  best-practice scheme on request — a site's code in that proposal
  comes from an IATA or UN/LOCODE code where you haven't set your
  own. New hosts — created as a guest or installed fresh — follow
  the confirmed scheme right away; existing ones are never renamed
  on their own — the fleet audit's new Naming row just flags a name
  that no longer fits.
