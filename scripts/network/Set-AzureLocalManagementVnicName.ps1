#requires -Version 5.1
<#
.SYNOPSIS
    Renames an Azure Local Management OS adapter with explicit operator approval.

.DESCRIPTION
    A guarded troubleshooting helper for cases where the expected Network ATC
    Management OS vNIC name is missing and a specific existing adapter has been
    identified as the intended management vNIC.

    IMPORTANT:
    - Use only after validating the adapter identity.
    - Confirm the expected name against your Azure Local / Network ATC design.
    - Prefer vendor or Microsoft-supported remediation where available.
    - This script supports -WhatIf and -Confirm and performs no automatic
      adapter discovery or guessing.

.PARAMETER CurrentName
    Current NetAdapter name to rename.

.PARAMETER ExpectedName
    Intended Management OS adapter name.

.EXAMPLE
    .\Set-AzureLocalManagementVnicName.ps1 -CurrentName '{GUID-LIKE-NAME}' -ExpectedName 'vManagement(management_compute)' -WhatIf

.EXAMPLE
    .\Set-AzureLocalManagementVnicName.ps1 -CurrentName '{GUID-LIKE-NAME}' -ExpectedName 'vManagement(management_compute)'
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$CurrentName,

    [Parameter(Mandatory)]
    [string]$ExpectedName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Rename-NetAdapter -ErrorAction SilentlyContinue)) {
    throw 'Rename-NetAdapter is not available on this system.'
}

$current = Get-NetAdapter -Name $CurrentName -ErrorAction Stop

if (Get-NetAdapter -Name $ExpectedName -ErrorAction SilentlyContinue) {
    throw "An adapter named '$ExpectedName' already exists. No change was made."
}

Write-Host ("Current adapter : {0}" -f $current.Name)
Write-Host ("Description     : {0}" -f $current.InterfaceDescription)
Write-Host ("Status          : {0}" -f $current.Status)
Write-Host ("Target name     : {0}" -f $ExpectedName)

if ($PSCmdlet.ShouldProcess(
    ("adapter '{0}'" -f $CurrentName),
    ("rename to '{0}'" -f $ExpectedName)
)) {
    Rename-NetAdapter -Name $CurrentName -NewName $ExpectedName -Confirm:$false
    Write-Host ("Adapter renamed to '{0}'." -f $ExpectedName)
}
