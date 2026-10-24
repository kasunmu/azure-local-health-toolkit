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
        +--> azcmagent show -j
        |      +--> Arc agent connection status
        |
        +--> Lifecycle Manager cmdlets
               +--> Overall update state and versions
               +--> Readiness check results and age
               +--> Pending and failed solution updates
               +--> Latest failed update run
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

The helper is read-only and maps the Windows Device Guard enforcement values into human-readable `Off`, `Audit`, or `Enforced` states. The check is Healthy only when kernel-mode and user-mode Code Integrity are both enforced. Audit or off is a Warning, because Azure Local applies WDAC in enforced mode by default and audit mode is meant as a temporary diagnostic step (see the vNIC/WDAC case study), not a resting state.

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

## Update readiness

`Get-AzureLocalUpdateReadiness.ps1` is split into two pure classification functions (`ConvertTo-AzureLocalUpdateEnvironmentResult` and `ConvertTo-AzureLocalSolutionUpdateResult`) and a thin collector that calls the Lifecycle Manager cmdlets. The classification functions take plain objects, so the status mapping is covered by Pester tests without a cluster.

See [update-readiness.md](update-readiness.md) for the status mapping and how to act on each result.

## Planned modules

Future releases will add:

- Windows Admin Center extension state
- Certificate expiry
- Arc extension and resource bridge checks
- HTML reporting
