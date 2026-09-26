#requires -Version 5.1
<#
.SYNOPSIS
    Collects a lightweight Azure Local health summary.

.DESCRIPTION
    Runs read-only cluster, node, CSV, storage, Network ATC, Management OS
    vNIC, WDAC, and Azure Connected Machine Agent checks. The script is
    designed to be reusable and does not rely on organisation-specific values.

.PARAMETER OutputPath
    Optional path to export the collected results.

.PARAMETER Format
    Export format when OutputPath is specified. Supported values: Json, Csv.

.EXAMPLE
    .\Get-AzureLocalHealth.ps1

.EXAMPLE
    .\Get-AzureLocalHealth.ps1 -OutputPath .\output\health.json -Format Json
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('Json', 'Csv')]
    [string]$Format = 'Json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$results = [System.Collections.Generic.List[object]]::new()

$privateHelpers = @(
    'Test-AzureLocalManagementVnicState.ps1',
    'Get-AzureLocalWdacState.ps1'
)

foreach ($helper in $privateHelpers) {
    $helperPath = Join-Path $PSScriptRoot "private\$helper"
    if (Test-Path -LiteralPath $helperPath) {
        . $helperPath
    }
}

function Add-HealthResult {
    param(
        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('Healthy', 'Warning', 'Critical', 'Unknown', 'NotAvailable')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Details
    )

    $results.Add([pscustomobject]@{
        Category  = $Category
        Name      = $Name
        Status    = $Status
        Details   = $Details
        Timestamp = (Get-Date).ToString('o')
    })
}

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-ClusterHealth {
    if (-not (Test-CommandAvailable -Name 'Get-Cluster')) {
        Add-HealthResult -Category 'Cluster' -Name 'FailoverClusters module' -Status 'NotAvailable' -Details 'Get-Cluster is not available on this system.'
        return
    }

    try {
        $cluster = Get-Cluster
        Add-HealthResult -Category 'Cluster' -Name 'Cluster service' -Status 'Healthy' -Details ("Cluster {0} is reachable" -f $cluster.Name)
    }
    catch {
        Add-HealthResult -Category 'Cluster' -Name 'Cluster service' -Status 'Critical' -Details $_.Exception.Message
        return
    }

    try {
        foreach ($node in Get-ClusterNode) {
            $status = if ($node.State -eq 'Up') { 'Healthy' } else { 'Critical' }
            Add-HealthResult -Category 'ClusterNode' -Name $node.Name -Status $status -Details ("State: {0}" -f $node.State)
        }
    }
    catch {
        Add-HealthResult -Category 'ClusterNode' -Name 'Node enumeration' -Status 'Unknown' -Details $_.Exception.Message
    }

    try {
        foreach ($csv in Get-ClusterSharedVolume) {
            $state = $csv.State
            $status = if ($state -eq 'Online') { 'Healthy' } else { 'Critical' }
            Add-HealthResult -Category 'CSV' -Name $csv.Name -Status $status -Details ("State: {0}" -f $state)
        }
    }
    catch {
        Add-HealthResult -Category 'CSV' -Name 'CSV enumeration' -Status 'Unknown' -Details $_.Exception.Message
    }
}

function Get-StorageHealth {
    if (-not (Test-CommandAvailable -Name 'Get-StoragePool')) {
        Add-HealthResult -Category 'Storage' -Name 'Storage module' -Status 'NotAvailable' -Details 'Get-StoragePool is not available on this system.'
        return
    }

    try {
        foreach ($pool in Get-StoragePool | Where-Object { -not $_.IsPrimordial }) {
            $status = if ($pool.HealthStatus -eq 'Healthy' -and $pool.OperationalStatus -contains 'OK') {
                'Healthy'
            }
            elseif ($pool.HealthStatus -eq 'Healthy') {
                'Warning'
            }
            else {
                'Critical'
            }

            Add-HealthResult -Category 'StoragePool' -Name $pool.FriendlyName -Status $status -Details ("HealthStatus: {0}; OperationalStatus: {1}" -f $pool.HealthStatus, ($pool.OperationalStatus -join ', '))
        }
    }
    catch {
        Add-HealthResult -Category 'StoragePool' -Name 'Pool enumeration' -Status 'Unknown' -Details $_.Exception.Message
    }

    try {
        foreach ($disk in Get-VirtualDisk) {
            $status = if ($disk.HealthStatus -eq 'Healthy' -and $disk.OperationalStatus -contains 'OK') {
                'Healthy'
            }
            elseif ($disk.HealthStatus -eq 'Healthy') {
                'Warning'
            }
            else {
                'Critical'
            }

            Add-HealthResult -Category 'VirtualDisk' -Name $disk.FriendlyName -Status $status -Details ("HealthStatus: {0}; OperationalStatus: {1}" -f $disk.HealthStatus, ($disk.OperationalStatus -join ', '))
        }
    }
    catch {
        Add-HealthResult -Category 'VirtualDisk' -Name 'Virtual disk enumeration' -Status 'Unknown' -Details $_.Exception.Message
    }

    try {
        foreach ($disk in Get-PhysicalDisk) {
            $status = if ($disk.HealthStatus -eq 'Healthy' -and $disk.OperationalStatus -contains 'OK') {
                'Healthy'
            }
            elseif ($disk.HealthStatus -eq 'Healthy') {
                'Warning'
            }
            else {
                'Critical'
            }

            Add-HealthResult -Category 'PhysicalDisk' -Name $disk.FriendlyName -Status $status -Details ("HealthStatus: {0}; OperationalStatus: {1}" -f $disk.HealthStatus, ($disk.OperationalStatus -join ', '))
        }
    }
    catch {
        Add-HealthResult -Category 'PhysicalDisk' -Name 'Physical disk enumeration' -Status 'Unknown' -Details $_.Exception.Message
    }
}

function Get-NetworkAtcHealth {
    if (-not (Test-CommandAvailable -Name 'Get-NetIntent')) {
        Add-HealthResult -Category 'NetworkATC' -Name 'Network ATC' -Status 'NotAvailable' -Details 'Get-NetIntent is not available on this system.'
        return
    }

    try {
        $intents = @(Get-NetIntent -ErrorAction Stop)
    }
    catch {
        Add-HealthResult -Category 'NetworkATC' -Name 'Network ATC' -Status 'Unknown' -Details $_.Exception.Message
        return
    }

    if ($intents.Count -eq 0) {
        Add-HealthResult -Category 'NetworkATC' -Name 'Network ATC' -Status 'Warning' -Details 'No Network ATC intents were detected.'
        return
    }

    $managementIntents = @($intents | Where-Object { $_.IsManagementIntent -eq $true })

    foreach ($intent in $intents) {
        $roles = [System.Collections.Generic.List[string]]::new()
        if ($intent.IsManagementIntent) { $roles.Add('Management') }
        if ($intent.IsComputeIntent) { $roles.Add('Compute') }
        if ($intent.IsStorageIntent) { $roles.Add('Storage') }

        $roleText = if ($roles.Count -gt 0) { $roles -join ', ' } else { 'Role metadata unavailable' }
        Add-HealthResult -Category 'NetworkATC' -Name ("Intent {0}" -f $intent.IntentName) -Status 'Healthy' -Details ("Detected intent roles: {0}" -f $roleText)
    }

    if ($managementIntents.Count -eq 0) {
        Add-HealthResult -Category 'ManagementVnic' -Name 'Management OS vNIC' -Status 'Warning' -Details 'Network ATC intents were detected, but none reported IsManagementIntent=True.'
        return
    }

    if (-not (Get-Command Test-AzureLocalManagementVnicState -ErrorAction SilentlyContinue)) {
        Add-HealthResult -Category 'ManagementVnic' -Name 'Management OS vNIC validation' -Status 'NotAvailable' -Details 'The shared Management OS vNIC validation helper is unavailable.'
        return
    }

    foreach ($intent in $managementIntents) {
        try {
            $vnicState = Test-AzureLocalManagementVnicState -IntentName $intent.IntentName
            Add-HealthResult -Category 'ManagementVnic' -Name $vnicState.ExpectedName -Status $vnicState.Status -Details $vnicState.Details
        }
        catch {
            Add-HealthResult -Category 'ManagementVnic' -Name ("Intent {0}" -f $intent.IntentName) -Status 'Unknown' -Details $_.Exception.Message
        }
    }
}

function Get-WdacHealth {
    if (-not (Get-Command Get-AzureLocalWdacState -ErrorAction SilentlyContinue)) {
        Add-HealthResult -Category 'WDAC' -Name 'Application Control mode' -Status 'NotAvailable' -Details 'The WDAC state helper is unavailable.'
        return
    }

    $wdacState = Get-AzureLocalWdacState

    if ($wdacState.Status -eq 'NotAvailable') {
        Add-HealthResult -Category 'WDAC' -Name 'Application Control mode' -Status 'NotAvailable' -Details ("Unable to query Win32_DeviceGuard: {0}" -f $wdacState.Error)
        return
    }

    Add-HealthResult -Category 'WDAC' -Name 'Application Control mode' -Status $wdacState.Status -Details ("Kernel-mode CI: {0}; User-mode CI: {1}" -f $wdacState.KernelMode, $wdacState.UserMode)
}

function Get-ArcAgentHealth {
    $azcmagent = Get-Command -Name 'azcmagent' -ErrorAction SilentlyContinue

    if (-not $azcmagent) {
        Add-HealthResult -Category 'Arc' -Name 'Azure Connected Machine Agent' -Status 'NotAvailable' -Details 'azcmagent was not found in PATH.'
        return
    }

    try {
        $output = & $azcmagent.Source show 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Add-HealthResult -Category 'Arc' -Name 'Azure Connected Machine Agent' -Status 'Healthy' -Details 'azcmagent show completed successfully.'
        }
        else {
            Add-HealthResult -Category 'Arc' -Name 'Azure Connected Machine Agent' -Status 'Warning' -Details ("azcmagent show returned exit code {0}. Output: {1}" -f $exitCode, (($output | Out-String).Trim()))
        }
    }
    catch {
        Add-HealthResult -Category 'Arc' -Name 'Azure Connected Machine Agent' -Status 'Unknown' -Details $_.Exception.Message
    }
}

function Export-HealthResults {
    param(
        [Parameter(Mandatory)]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Json', 'Csv')]
        [string]$ExportFormat
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    switch ($ExportFormat) {
        'Json' {
            $InputObject | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
        }
        'Csv' {
            $InputObject | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
        }
    }
}

Get-ClusterHealth
Get-StorageHealth
Get-NetworkAtcHealth
Get-WdacHealth
Get-ArcAgentHealth

$results | Sort-Object Category, Name | Format-Table -AutoSize

if ($OutputPath) {
    Export-HealthResults -InputObject $results.ToArray() -Path $OutputPath -ExportFormat $Format
    Write-Host ("Results exported to {0}" -f (Resolve-Path -LiteralPath $OutputPath))
}

$results.ToArray()
