# Project notes

- **System of interest:** `FdmPrinter::FdmPrinterSpecification`; the lead candidate is
  `FdmPrinter::candidateCoreXYClosedShaped` (ADR-001).
- **Tools:** Spec42 (pinned in `.spec42-version`) for model checks; Run42 and Doc42 for verification and documents
  in later increments.
- **Units:** Celsius temperatures are written in kelvin (`573.15 [K]`) with the Celsius value in a comment, because
  the SysML standard library defines `°C` only as a temperature difference.
- **Open questions:** sourced belt and frame stiffness and moving masses (A-MECH-1); a measured thermal growth of the
  frame (A-ACC-1); the standards that apply to a mains-powered heated device, to be checked before any is named in a
  requirement (A-SAFE-1).
