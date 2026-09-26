# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
