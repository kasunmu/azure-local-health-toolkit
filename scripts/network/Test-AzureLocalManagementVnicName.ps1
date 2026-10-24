#requires -Version 5.1
<#
.SYNOPSIS
    Validates the expected Azure Local Management OS vNIC name.

.DESCRIPTION
    Compares the expected Network ATC Management OS adapter name with the
    adapters currently visible to Windows and Hyper-V.

    This script is read-only and uses the same validation function as the
    main Azure Local health collector.

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

$helperPath = Join-Path $PSScriptRoot '..\..\src\private\Test-AzureLocalManagementVnicState.ps1'

if (-not (Test-Path -LiteralPath $helperPath)) {
    throw "Shared Management OS vNIC validation helper was not found at '$helperPath'."
}

. $helperPath

Test-AzureLocalManagementVnicState -IntentName $IntentName -ExpectedName $ExpectedName
