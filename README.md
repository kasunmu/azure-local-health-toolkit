# Azure Local Health Toolkit

[![PowerShell CI](https://github.com/kasunmu/azure-local-health-toolkit/actions/workflows/powershell-lint.yml/badge.svg)](https://github.com/kasunmu/azure-local-health-toolkit/actions/workflows/powershell-lint.yml)

A reusable PowerShell toolkit for checking the operational health of Azure Local environments.

The project is based on practical Azure Local administration and troubleshooting patterns, but all code in this repository is written to be environment-neutral. It does not contain organisation-specific names, IP addresses, tenant IDs, subscription IDs, credentials, or other sensitive configuration.

## Current scope

Version 0.1 focuses on core platform and pre-update checks:

- Cluster health
- Cluster node state
- Cluster Shared Volume state
- Storage pool health
- Virtual disk health
- Physical disk health
- Network ATC intent discovery
- Management OS vNIC name validation
- GUID-style virtual adapter warning detection
- WDAC / Code Integrity enforcement-mode reporting (anything other than enforced is flagged as a warning)
- Azure Connected Machine agent connectivity, based on the agent's reported status rather than the command's exit code
- Solution update readiness: overall update state, readiness check results and age, pending or failed updates, and detection of incomplete deployments where Lifecycle Manager is missing ([details](docs/update-readiness.md))
- Export of collected results to JSON or CSV

The Network ATC and Management OS vNIC checks were added from a real Azure Local update troubleshooting pattern and converted into a reusable, read-only pre-update validation.

## Repository structure

```text
.
├── src/
│   ├── Get-AzureLocalHealth.ps1
│   └── private/
│       ├── Get-AzureLocalArcAgentState.ps1
│       ├── Get-AzureLocalUpdateReadiness.ps1
│       ├── Get-AzureLocalWdacState.ps1
│       └── Test-AzureLocalManagementVnicState.ps1
├── tests/
├── scripts/
│   └── network/
├── docs/
│   ├── architecture.md
│   └── case-studies/
├── examples/
│   └── sample-output.md
├── .github/
│   └── workflows/
│       └── powershell-lint.yml
├── PSScriptAnalyzerSettings.psd1
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
└── README.md
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Run from a system with the FailoverClusters and Storage modules available for full cluster checks
- Network ATC and Hyper-V cmdlets are required for the related networking checks
- Administrative permissions may be required for some local health checks
- Azure Connected Machine Agent is optional. The script will report when it is not installed
- If a required feature or cmdlet is unavailable, the toolkit reports `NotAvailable` or a warning instead of stopping the full health run

## Quick start

Clone the repository and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\src\Get-AzureLocalHealth.ps1
```

The script returns one object per check, so you can filter and pipe the results:

```powershell
# Only the checks that need attention
.\src\Get-AzureLocalHealth.ps1 | Where-Object Status -ne 'Healthy'

# Pre-maintenance: only the update readiness results
.\src\Get-AzureLocalHealth.ps1 | Where-Object Category -eq 'Update'
```

To export the results:

```powershell
.\src\Get-AzureLocalHealth.ps1 -OutputPath .\output\health.json -Format Json
```

or:

```powershell
.\src\Get-AzureLocalHealth.ps1 -OutputPath .\output\health.csv -Format Csv
```

## Example result

Each check returns a simple object with:

- `Category`
- `Name`
- `Status`
- `Details`
- `Timestamp`

Example:

```text
Category        Name                              Status   Details
--------        ----                              ------   -------
Cluster         Cluster service                   Healthy  Cluster AZLOCAL-DEMO is reachable
ClusterNode     NODE-01                           Healthy  State: Up
CSV             Cluster Virtual Disk              Healthy  State: Online
StoragePool     S2D on Cluster                    Healthy  HealthStatus: Healthy
NetworkATC      Intent management_compute         Healthy  Detected intent roles: Management, Compute
ManagementVnic  vManagement(management_compute)   Healthy  Expected Management OS vNIC name is present.
WDAC            Application Control mode          Healthy  Kernel-mode CI: Enforced; User-mode CI: Enforced
Arc             Azure Connected Machine Agent     Healthy  Agent status: Connected; Version: 1.47.0
Update          Update state                      Healthy  State: UpdateAvailable; Solution version: 12.2608.1001.4
Update          Update readiness checks           Healthy  Readiness checks: Success; Last run: 2026-10-23 22:00 (0 day(s) ago)
Update          Azure Local 2609                  Healthy  State: Ready; Version: 12.2609.1002.18
```

The names and values above are synthetic and are not copied from a production environment.

## Network troubleshooting helpers

The `scripts/network` directory also contains standalone inspection and guarded remediation helpers for:

- Network ATC state inspection
- Management OS vNIC name validation
- explicit Management OS adapter rename with `-WhatIf` / confirmation
- Network ATC retry-state requests with `-WhatIf`

The main health collector remains read-only.

## Testing

Tests use [Pester](https://pester.dev) 5 and mock the Azure Local cmdlets, so they run on any machine, including Linux, without a cluster.

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser
Invoke-Pester -Path .\tests -Output Detailed
```

Every push and pull request to `main` runs PSScriptAnalyzer and the Pester suite on Ubuntu and Windows. Analyzer warnings fail the build.

## Roadmap

Planned additions include:

- Windows Admin Center extension status
- Certificate expiry checks
- Arc extension and resource bridge validation
- HTML reporting
- threshold-based warning and critical states
- additional documentation and troubleshooting guidance

## Security and privacy

Do not commit:

- Tenant IDs
- Subscription IDs
- Resource IDs from private environments
- IP addresses that identify internal networks
- Credentials, tokens, certificates, or secrets
- Organisation-specific hostnames or logs containing sensitive information

See [SECURITY.md](SECURITY.md) for more information.

## Contributing

Suggestions and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
