# Azure Local Health Toolkit

A reusable PowerShell toolkit for checking the operational health of Azure Local environments.

The project is based on practical Azure Local administration and troubleshooting patterns, but all code in this repository is written to be environment-neutral. It does not contain organisation-specific names, IP addresses, tenant IDs, subscription IDs, credentials, or other sensitive configuration.

## Current scope

Version 0.1 focuses on core platform checks:

- Cluster health
- Cluster node state
- Cluster Shared Volume state
- Storage pool health
- Virtual disk health
- Physical disk health
- Azure Connected Machine agent presence and local status
- Export of collected results to JSON or CSV

## Repository structure

```text
.
├── src/
│   └── Get-AzureLocalHealth.ps1
├── docs/
│   └── architecture.md
├── examples/
│   └── sample-output.md
├── .github/
│   └── workflows/
│       └── powershell-lint.yml
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
└── README.md
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Run from a system with the FailoverClusters and Storage modules available for full cluster checks
- Administrative permissions may be required for some local health checks
- Azure Connected Machine Agent is optional. The script will report when it is not installed

## Quick start

Clone the repository and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\src\Get-AzureLocalHealth.ps1
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
Category       Name                   Status   Details
--------       ----                   ------   -------
Cluster        Cluster service        Healthy  Cluster AZLOCAL-DEMO is reachable
ClusterNode    NODE-01                Healthy  State: Up
CSV            Cluster Virtual Disk   Healthy  State: Online
StoragePool    S2D on Cluster         Healthy  HealthStatus: Healthy
```

The names above are illustrative only.

## Roadmap

Planned additions include:

- Azure Local update status and recent update failures
- Windows Admin Center extension status
- Certificate expiry checks
- Arc connectivity validation
- HTML reporting
- Threshold-based warning and critical states
- Pester tests
- Additional documentation and troubleshooting guidance

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
