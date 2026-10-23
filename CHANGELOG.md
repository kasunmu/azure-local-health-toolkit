# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed

- WDAC is now reported as Healthy only when kernel-mode and user-mode Code Integrity are both enforced; audit or off is a Warning
- The Arc check now reads the agent status from `azcmagent show -j` and also looks in the default install location; Disconnected, Expired and Error are Critical
- The health script emits its result objects once instead of printing a table and then returning the objects, and shows Category, Name, Status and Details by default
- Private helper paths are built with `Join-Path`, so the script loads on non-Windows PowerShell
- CI now fails on PSScriptAnalyzer warnings and errors, and also lints `scripts/` and `tests/`

### Added

- Pester test suite with mocked cmdlets, run on Ubuntu and Windows in CI
- `PSScriptAnalyzerSettings.psd1` with documented rule exclusions

### Added

- Initial repository structure
- Core Azure Local health-check script
- Cluster state check
- Cluster node state check
- Cluster Shared Volume check
- Storage pool check
- Virtual disk check
- Physical disk check
- Local Azure Connected Machine Agent check
- JSON and CSV export
- Initial architecture documentation
- Sample output documentation
- PowerShell lint workflow
- Network ATC intent discovery in the main health collector
- Management OS vNIC validation using the expected `vManagement(<intent>)` naming pattern
- Warning detection for GUID-style virtual adapter names
- Read-only WDAC / Code Integrity enforcement-mode reporting
- Shared Management OS vNIC validation used by both the main collector and standalone troubleshooting script
- Synthetic pre-update warning example
