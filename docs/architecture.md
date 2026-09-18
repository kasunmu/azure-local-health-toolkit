# Architecture

## Purpose

The Azure Local Health Toolkit is intentionally small and modular. The first release collects local platform health signals that are commonly checked during Azure Local operations and troubleshooting.

## Data flow

```text
Azure Local host or management system
        |
        v
Get-AzureLocalHealth.ps1
        |
        +--> FailoverClusters cmdlets
        |      +--> Cluster state
        |      +--> Node state
        |      +--> Cluster Shared Volumes
        |
        +--> Storage cmdlets
        |      +--> Storage pools
        |      +--> Virtual disks
        |      +--> Physical disks
        |
        +--> azcmagent
               +--> Local Azure Arc agent check
        |
        v
Normalised health objects
        |
        +--> Console table
        +--> JSON export
        +--> CSV export
```

## Design principles

1. **Environment-neutral**  
   No tenant, subscription, hostname, IP address, or organisation-specific value is hard-coded.

2. **Read-only by default**  
   Health checks do not change cluster, storage, Arc, or Azure configuration.

3. **Graceful degradation**  
   If a required command is unavailable, the toolkit records `NotAvailable` instead of failing the entire run.

4. **Simple output contract**  
   Every result uses the same fields: `Category`, `Name`, `Status`, `Details`, and `Timestamp`.

5. **Extensible checks**  
   Future checks can be added without changing the result model.

## Planned modules

Future releases will separate checks into dedicated functions or modules for:

- Azure Local solution updates
- Windows Admin Center extension state
- Certificate expiry
- Azure Arc connectivity
- HTML reporting
- Pester tests
