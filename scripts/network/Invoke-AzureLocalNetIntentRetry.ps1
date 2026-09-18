#requires -Version 5.1
<#
.SYNOPSIS
    Requests a Network ATC intent retry.

.DESCRIPTION
    Wrapper around Set-NetIntentRetryState for controlled troubleshooting.

    This changes Network ATC remediation state. Review the selected intent and
    use -WhatIf before running it in a production environment.

.PARAMETER IntentName
    Name of the Network ATC intent to retry.

.EXAMPLE
    .\Invoke-AzureLocalNetIntentRetry.ps1 -IntentName 'management_compute' -WhatIf

.EXAMPLE
    .\Invoke-AzureLocalNetIntentRetry.ps1 -IntentName 'management_compute'
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$IntentName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Set-NetIntentRetryState -ErrorAction SilentlyContinue)) {
    throw 'Set-NetIntentRetryState is not available on this system.'
}

if (Get-Command Get-NetIntent -ErrorAction SilentlyContinue) {
    $intent = Get-NetIntent | Where-Object IntentName -eq $IntentName
    if (-not $intent) {
        throw "Network ATC intent '$IntentName' was not found."
    }
}

if ($PSCmdlet.ShouldProcess(
    ("Network ATC intent '{0}'" -f $IntentName),
    'request remediation retry'
)) {
    Set-NetIntentRetryState -Name $IntentName
    Write-Host ("Retry state requested for intent '{0}'." -f $IntentName)
}
