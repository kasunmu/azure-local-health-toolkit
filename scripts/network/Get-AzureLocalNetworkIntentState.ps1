#requires -Version 5.1
<#
.SYNOPSIS
    Collects Network ATC intent and Management OS adapter state.

.DESCRIPTION
    Read-only helper for Azure Local troubleshooting. It reports Network ATC
    intents, Management OS virtual NICs, and matching NetAdapter objects.

    The script does not change networking configuration.

.EXAMPLE
    .\Get-AzureLocalNetworkIntentState.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ""
    Write-Host ("=== {0} ===" -f $Title)
}

Write-Section -Title 'Network ATC intents'

if (Get-Command Get-NetIntent -ErrorAction SilentlyContinue) {
    try {
        Get-NetIntent |
            Select-Object IntentName, Scope, AdapterPropertyOverrides, StorageOverrides, QoSPolicyOverrides |
            Format-List
    }
    catch {
        Write-Warning ("Unable to query Network ATC intents: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-Warning 'Get-NetIntent is not available on this system.'
}

Write-Section -Title 'Management OS VM network adapters'

if (Get-Command Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
    try {
        Get-VMNetworkAdapter -ManagementOS |
            Select-Object Name, SwitchName, Status, MacAddress, DeviceNaming, IsManagementOs |
            Format-Table -AutoSize
    }
    catch {
        Write-Warning ("Unable to query Management OS VM network adapters: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-Warning 'Get-VMNetworkAdapter is not available on this system.'
}

Write-Section -Title 'Matching operating-system adapters'

if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
    try {
        Get-NetAdapter |
            Where-Object {
                $_.Name -like 'vManagement*' -or
                $_.InterfaceDescription -like '*Hyper-V Virtual Ethernet Adapter*'
            } |
            Select-Object Name, InterfaceDescription, Status, MacAddress, ifIndex |
            Format-Table -AutoSize
    }
    catch {
        Write-Warning ("Unable to query operating-system adapters: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-Warning 'Get-NetAdapter is not available on this system.'
}
