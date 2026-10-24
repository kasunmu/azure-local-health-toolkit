function New-AzureLocalUpdateResult {
    # Builds an in-memory result object only; nothing on the system changes.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Details
    )

    [pscustomobject]@{
        Category = 'Update'
        Name     = $Name
        Status   = $Status
        Details  = $Details
    }
}

function Get-AzureLocalObjectValue {
    # Returns a property value, or $null when the property does not exist.
    # Keeps the helpers safe under Set-StrictMode when update objects differ
    # between Azure Local releases.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function ConvertTo-AzureLocalUpdateEnvironmentResult {
    <#
    .SYNOPSIS
        Classifies Get-SolutionUpdateEnvironment output into health results.

    .DESCRIPTION
        Produces up to three results:
        - Overall update state of the system (State, CurrentVersion, SBE version)
        - Update readiness health checks (HealthState and HealthCheckDate)
        - Failed readiness checks, when HealthCheckResult contains any
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Environment,

        [Parameter()]
        [int]$HealthCheckMaxAgeDays = 7,

        [Parameter()]
        [datetime]$Now = (Get-Date)
    )

    $state = [string](Get-AzureLocalObjectValue $Environment 'State')
    $currentVersion = Get-AzureLocalObjectValue $Environment 'CurrentVersion'
    $sbeVersion = Get-AzureLocalObjectValue $Environment 'CurrentSbeVersion'

    $stateStatus = switch ($state) {
        'AppliedSuccessfully'   { 'Healthy' }
        'UpdateAvailable'       { 'Healthy' }
        'UpdateInProgress'      { 'Warning' }
        'PreparationInProgress' { 'Warning' }
        'NeedsAttention'        { 'Warning' }
        'UpdateFailed'          { 'Critical' }
        'PreparationFailed'     { 'Critical' }
        default                 { 'Unknown' }
    }

    $stateDetails = [System.Collections.Generic.List[string]]::new()
    $stateDetails.Add(("State: {0}" -f $(if ($state) { $state } else { 'not reported' })))
    if ($currentVersion) { $stateDetails.Add(("Solution version: {0}" -f $currentVersion)) }
    if ($sbeVersion) { $stateDetails.Add(("SBE version: {0}" -f $sbeVersion)) }

    switch ($state) {
        'UpdateInProgress'      { $stateDetails.Add('An update is running; avoid other maintenance until it completes') }
        'PreparationInProgress' { $stateDetails.Add('An update is being prepared') }
        'NeedsAttention'        { $stateDetails.Add('Review the update in the Azure portal or with Get-SolutionUpdate') }
        'UpdateFailed'          { $stateDetails.Add('Review the failed run with Get-SolutionUpdate | Get-SolutionUpdateRun') }
        'PreparationFailed'     { $stateDetails.Add('Update preparation failed; review the readiness checks') }
    }

    New-AzureLocalUpdateResult -Name 'Update state' -Status $stateStatus -Details ($stateDetails -join '; ')

    $healthState = [string](Get-AzureLocalObjectValue $Environment 'HealthState')
    $healthDate = Get-AzureLocalObjectValue $Environment 'HealthCheckDate'

    $healthStatus = switch ($healthState) {
        'Success'    { 'Healthy' }
        'Warning'    { 'Warning' }
        'InProgress' { 'Warning' }
        'Failure'    { 'Critical' }
        'Error'      { 'Critical' }
        default      { 'Unknown' }
    }

    $healthDetails = [System.Collections.Generic.List[string]]::new()
    $healthDetails.Add(("Readiness checks: {0}" -f $(if ($healthState) { $healthState } else { 'not reported' })))

    $parsedDate = $null
    if ($healthDate) {
        try { $parsedDate = [datetime]$healthDate } catch { $parsedDate = $null }
    }

    if ($parsedDate -and $parsedDate.Year -gt 1) {
        $ageDays = [math]::Floor(($Now - $parsedDate).TotalDays)
        $healthDetails.Add(("Last run: {0:yyyy-MM-dd HH:mm} ({1} day(s) ago)" -f $parsedDate, $ageDays))

        if ($ageDays -gt $HealthCheckMaxAgeDays -and $healthStatus -eq 'Healthy') {
            $healthStatus = 'Warning'
            $healthDetails.Add(("Results are older than {0} days; rerun the readiness checks before updating" -f $HealthCheckMaxAgeDays))
        }
    }
    elseif ($healthState) {
        $healthDetails.Add('Last run: never')
    }

    New-AzureLocalUpdateResult -Name 'Update readiness checks' -Status $healthStatus -Details ($healthDetails -join '; ')

    $checks = @(Get-AzureLocalObjectValue $Environment 'HealthCheckResult' | Where-Object { $null -ne $_ })
    $failedChecks = @(
        $checks | Where-Object {
            $checkStatus = [string](Get-AzureLocalObjectValue $_ 'Status')
            $checkStatus -and $checkStatus -ne 'SUCCESS'
        }
    )

    if ($failedChecks.Count -gt 0) {
        $critical = @($failedChecks | Where-Object { [string](Get-AzureLocalObjectValue $_ 'Severity') -eq 'CRITICAL' })
        $warning = @($failedChecks | Where-Object { [string](Get-AzureLocalObjectValue $_ 'Severity') -eq 'WARNING' })

        $failedStatus = if ($critical.Count -gt 0) { 'Critical' } else { 'Warning' }

        $titles = @(
            $failedChecks |
                ForEach-Object {
                    $title = Get-AzureLocalObjectValue $_ 'Title'
                    if (-not $title) { $title = Get-AzureLocalObjectValue $_ 'Name' }
                    if ($title) { [string]$title }
                } |
                Sort-Object -Unique |
                Select-Object -First 5
        )

        $summary = "{0} check(s) not passing ({1} critical, {2} warning)" -f $failedChecks.Count, $critical.Count, $warning.Count
        if ($titles.Count -gt 0) {
            $summary += ": " + ($titles -join '; ')
        }

        New-AzureLocalUpdateResult -Name 'Failed readiness checks' -Status $failedStatus -Details $summary
    }
}

function ConvertTo-AzureLocalSolutionUpdateResult {
    <#
    .SYNOPSIS
        Classifies Get-SolutionUpdate output into health results.

    .DESCRIPTION
        Installed updates are skipped. Each remaining update produces one
        result. When nothing is pending, a single Healthy result is returned.
        LatestRuns, if supplied, maps an update ResourceId to its most recent
        Get-SolutionUpdateRun object so failed runs can name the action plan
        instance ID needed for deeper troubleshooting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Update,

        [Parameter()]
        [hashtable]$LatestRuns = @{}
    )

    $pending = @(
        $Update | Where-Object {
            $_ -and ([string](Get-AzureLocalObjectValue $_ 'State')) -notin @('Installed', 'Obsolete', 'Recalled')
        }
    )

    if ($pending.Count -eq 0) {
        New-AzureLocalUpdateResult -Name 'Pending updates' -Status 'Healthy' -Details 'No pending or failed solution updates.'
        return
    }

    foreach ($item in $pending) {
        $state = [string](Get-AzureLocalObjectValue $item 'State')
        $version = Get-AzureLocalObjectValue $item 'Version'
        $displayName = Get-AzureLocalObjectValue $item 'DisplayName'
        $resourceId = [string](Get-AzureLocalObjectValue $item 'ResourceId')

        $label = if ($displayName) { [string]$displayName } elseif ($version) { "Update $version" } else { 'Solution update' }

        $status = switch -Wildcard ($state) {
            '*Failed'                   { 'Critical' }
            'Installing'                { 'Warning' }
            'Preparing'                 { 'Warning' }
            'Downloading'               { 'Warning' }
            'HealthChecking'            { 'Warning' }
            'AdditionalContentRequired' { 'Warning' }
            'Ready'                     { 'Healthy' }
            'ReadyToInstall'            { 'Healthy' }
            'HasPrerequisite'           { 'Warning' }
            default                     { 'Unknown' }
        }

        $details = [System.Collections.Generic.List[string]]::new()
        $details.Add(("State: {0}" -f $(if ($state) { $state } else { 'not reported' })))
        if ($version) { $details.Add(("Version: {0}" -f $version)) }

        $progress = Get-AzureLocalObjectValue $item 'UpdateStateProperties'
        if ($state -eq 'Installing' -and $progress) { $details.Add(("Progress: {0}" -f $progress)) }

        switch -Wildcard ($state) {
            'HealthCheckFailed'         { $details.Add('Readiness checks failed; fix them before installing') }
            '*Failed'                   {
                if ($state -ne 'HealthCheckFailed') {
                    $details.Add('Resume with Start-SolutionUpdate once the cause is fixed')
                }
            }
            'AdditionalContentRequired' { $details.Add('Solution Builder Extension content must be downloaded from the hardware vendor') }
            'HasPrerequisite'           { $details.Add('Another update must be installed first') }
        }

        if ($status -eq 'Critical' -and $resourceId -and $LatestRuns.ContainsKey($resourceId)) {
            $run = $LatestRuns[$resourceId]
            $runId = Get-AzureLocalObjectValue $run 'ResourceId'
            $runState = Get-AzureLocalObjectValue $run 'State'
            $runStarted = Get-AzureLocalObjectValue $run 'TimeStarted'
            if ($runState) { $details.Add(("Last run: {0}" -f $runState)) }
            if ($runStarted) { $details.Add(("Started: {0}" -f $runStarted)) }
            if ($runId) {
                $details.Add(("Action plan instance: {0} (see Start-MonitoringActionplanInstanceToComplete)" -f (Split-Path -Leaf ([string]$runId))))
            }
        }

        New-AzureLocalUpdateResult -Name $label -Status $status -Details ($details -join '; ')
    }
}

function Get-AzureLocalUpdateReadiness {
    <#
    .SYNOPSIS
        Read-only Azure Local update readiness check.

    .DESCRIPTION
        Uses the Lifecycle Manager cmdlets (Get-SolutionUpdateEnvironment,
        Get-SolutionUpdate, Get-SolutionUpdateRun) to report the overall update
        state, readiness check results and any pending or failed updates.

        If the Lifecycle Manager cmdlets are missing on a node that is part of
        a failover cluster, the most common cause is that the node is
        Arc-registered but the Azure Local deployment has not completed, so the
        check reports a Warning with that guidance rather than NotAvailable.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$HealthCheckMaxAgeDays = 7
    )

    if (-not (Get-Command -Name 'Get-SolutionUpdateEnvironment' -ErrorAction SilentlyContinue)) {
        $inCluster = $false
        if (Get-Command -Name 'Get-Cluster' -ErrorAction SilentlyContinue) {
            try {
                $null = Get-Cluster -ErrorAction Stop
                $inCluster = $true
            }
            catch {
                $inCluster = $false
            }
        }

        if ($inCluster) {
            New-AzureLocalUpdateResult -Name 'Lifecycle Manager' -Status 'Warning' -Details ('Get-SolutionUpdateEnvironment is not available on this cluster node. ' +
                'This usually means the node is Arc-registered but the Azure Local deployment has not completed, so solution updates cannot be managed yet. ' +
                'Check the deployment status in the Azure portal.')
        }
        else {
            New-AzureLocalUpdateResult -Name 'Lifecycle Manager' -Status 'NotAvailable' -Details 'Get-SolutionUpdateEnvironment is not available. Run this check on an Azure Local cluster node.'
        }
        return
    }

    try {
        $environment = Get-SolutionUpdateEnvironment -ErrorAction Stop | Select-Object -First 1
    }
    catch {
        New-AzureLocalUpdateResult -Name 'Update state' -Status 'Unknown' -Details ("Get-SolutionUpdateEnvironment failed: {0}" -f $_.Exception.Message)
        return
    }

    if ($null -eq $environment) {
        New-AzureLocalUpdateResult -Name 'Update state' -Status 'Unknown' -Details 'Get-SolutionUpdateEnvironment returned no data.'
    }
    else {
        ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -HealthCheckMaxAgeDays $HealthCheckMaxAgeDays
    }

    if (-not (Get-Command -Name 'Get-SolutionUpdate' -ErrorAction SilentlyContinue)) {
        return
    }

    try {
        $updates = @(Get-SolutionUpdate -ErrorAction Stop)
    }
    catch {
        New-AzureLocalUpdateResult -Name 'Pending updates' -Status 'Unknown' -Details ("Get-SolutionUpdate failed: {0}" -f $_.Exception.Message)
        return
    }

    $latestRuns = @{}
    if (Get-Command -Name 'Get-SolutionUpdateRun' -ErrorAction SilentlyContinue) {
        foreach ($item in $updates) {
            $itemState = [string](Get-AzureLocalObjectValue $item 'State')
            $itemId = [string](Get-AzureLocalObjectValue $item 'ResourceId')
            if ($itemState -like '*Failed' -and $itemId) {
                try {
                    $run = @($item | Get-SolutionUpdateRun -ErrorAction Stop) |
                        Sort-Object -Property { Get-AzureLocalObjectValue $_ 'TimeStarted' } -Descending |
                        Select-Object -First 1
                    if ($run) { $latestRuns[$itemId] = $run }
                }
                catch {
                    Write-Verbose ("Get-SolutionUpdateRun failed for {0}: {1}" -f $itemId, $_.Exception.Message)
                }
            }
        }
    }

    ConvertTo-AzureLocalSolutionUpdateResult -Update $updates -LatestRuns $latestRuns
}
