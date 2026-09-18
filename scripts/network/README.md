# Network ATC and Management OS vNIC troubleshooting helpers

These scripts support diagnosis of Azure Local update failures involving Network ATC and Management OS virtual adapter naming.

## Scripts

### Get-AzureLocalNetworkIntentState.ps1

Read-only inventory of:

- Network ATC intents
- Management OS VM network adapters
- matching Windows NetAdapter objects

### Test-AzureLocalManagementVnicName.ps1

Checks whether the expected Management OS vNIC name exists and flags GUID-style adapter names.

### Set-AzureLocalManagementVnicName.ps1

Guarded rename helper.

This script intentionally requires both the current adapter name and the expected name. It does not guess which adapter should be renamed.

Always run with `-WhatIf` first.

### Invoke-AzureLocalNetIntentRetry.ps1

Controlled wrapper around `Set-NetIntentRetryState`.

Always run with `-WhatIf` first in a production environment.

## Safety note

Azure Local networking is configuration-sensitive. These scripts are troubleshooting helpers, not a replacement for Microsoft or hardware-vendor guidance.

The read-only scripts are safe to use for inspection. The rename and retry helpers modify system state and should only be used after the operator has positively identified the affected intent and adapter.

## Related case study

See:

`docs/case-studies/azure-local-management-vnic-wdac-update-failure.md`
