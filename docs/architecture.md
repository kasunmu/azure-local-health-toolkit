# Architecture

## Purpose

The Azure Local Health Toolkit is intentionally small and modular. The first release collects local platform health signals that are commonly checked during Azure Local operations, troubleshooting, and pre-update validation.

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
        +--> Network ATC / Hyper-V cmdlets
        |      +--> Configured intents
        |      +--> Management intent detection
        |      +--> Expected vManagement(<intent>) validation
        |      +--> GUID-style virtual adapter warning detection
        |
        +--> Win32_DeviceGuard
        |      +--> Kernel-mode Code Integrity state
        |      +--> User-mode Code Integrity state
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

## Shared validation logic

Management OS vNIC validation is implemented once in:

`src/private/Test-AzureLocalManagementVnicState.ps1`

The main health collector and the standalone troubleshooting script both use this shared function so the public toolkit does not maintain two independent versions of the same detection logic.

WDAC / Code Integrity state is collected by:

`src/private/Get-AzureLocalWdacState.ps1`

The helper is read-only and maps the Windows Device Guard enforcement values into human-readable `Off`, `Audit`, or `Enforced` states.

## Design principles

1. **Environment-neutral**  
   No tenant, subscription, hostname, IP address, or organisation-specific value is hard-coded.

2. **Read-only by default**  
   The main health collector does not change cluster, storage, networking, Arc, WDAC, or Azure configuration.

3. **Graceful degradation**  
   If a required command or feature is unavailable, the toolkit records `NotAvailable`, `Unknown`, or a warning rather than failing the entire run.

4. **Simple output contract**  
   Every health result uses the same fields: `Category`, `Name`, `Status`, `Details`, and `Timestamp`.

5. **Extensible checks**  
   Future checks can be added without changing the result model.

6. **Operational lessons become preventive checks**  
   Troubleshooting patterns from real Azure Local incidents are sanitised and converted into reusable validation logic where they have wider operational value.

## Standalone remediation helpers

The `scripts/network` directory contains explicit troubleshooting helpers that are separate from the read-only collector.

State-changing helpers require operator-provided values and support PowerShell confirmation / `-WhatIf` semantics. They do not automatically guess which adapter or intent should be changed.

## Planned modules

Future releases will add:

- Azure Local solution update status and recent failures
- Windows Admin Center extension state
- Certificate expiry
- richer Azure Arc connectivity checks
- HTML reporting
- Pester tests
