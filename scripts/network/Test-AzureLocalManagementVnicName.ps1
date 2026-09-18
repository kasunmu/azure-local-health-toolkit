#requires -Version 5.1
<#
.SYNOPSIS
    Validates the expected Azure Local Management OS vNIC name.

.DESCRIPTION
    Compares the expected Network ATC Management OS adapter name with the
    adapters currently visible to Windows and Hyper-V.

    This script is read-only.

.PARAMETER IntentName
    Network ATC intent name used to derive the expected vNIC name.

.PARAMETER ExpectedName
    Optional explicit expected adapter name. When omitted the script expects
    vManagement(<IntentName>).

.EXAMPLE
    .\Test-AzureLocalManagementVnicName.ps1 -IntentName 'management_compute'

.EXAMPLE
    .\Test-AzureLocalManagementVnicName.ps1 -IntentName 'management_compute' -ExpectedName 'vManagement(management_compute)'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$IntentName,

    [Parameter()]
    [string]$ExpectedName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ExpectedName) {
    $ExpectedName = "vManagement($IntentName)"
}

$result = [ordered]@{
    IntentName               = $IntentName
    ExpectedName             = $ExpectedName
    ExpectedNetAdapterFound  = $false
    ExpectedVMAdapterFound   = $false
    GuidStyleAdapterDetected = $false
    GuidStyleAdapters        = @()
    Status                   = 'Unknown'
    Details                  = ''
}

if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
    $netAdapters = @(Get-NetAdapter)

    $result.ExpectedNetAdapterFound = [bool](
        $netAdapters | Where-Object Name -eq $ExpectedName
    )

    $guidLike = @(
        $netAdapters | Where-Object {
            $_.Name -match '^[{(]?[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}[)}]?$'
        }
    )

    if ($guidLike.Count -gt 0) {
        $result.GuidStyleAdapterDetected = $true
        $result.GuidStyleAdapters = @($guidLike | Select-Object -ExpandProperty Name)
    }
}

if (Get-Command Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
    $vmAdapters = @(Get-VMNetworkAdapter -ManagementOS)
    $result.ExpectedVMAdapterFound = [bool](
        $vmAdapters | Where-Object Name -eq $ExpectedName
    )
}

if ($result.ExpectedNetAdapterFound -or $result.ExpectedVMAdapterFound) {
    $result.Status = 'Healthy'
    $result.Details = "Expected Management OS vNIC name '$ExpectedName' is present."
}
elseif ($result.GuidStyleAdapterDetected) {
    $result.Status = 'Warning'
    $result.Details = "Expected Management OS vNIC name '$ExpectedName' was not found and one or more GUID-style adapter names were detected."
}
else {
    $result.Status = 'Warning'
    $result.Details = "Expected Management OS vNIC name '$ExpectedName' was not found."
}

[pscustomobject]$result
