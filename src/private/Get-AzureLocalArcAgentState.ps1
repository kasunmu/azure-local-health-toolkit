function ConvertFrom-AzureLocalArcAgentJson {
    <#
    .SYNOPSIS
        Converts `azcmagent show -j` output into a health result.

    .DESCRIPTION
        A zero exit code from azcmagent only means the command ran; it does not
        mean the machine is connected to Azure Arc. This function reads the
        agent's reported status instead. Only the status, agent version and
        last heartbeat are returned, so tenant, subscription and resource
        identifiers never reach the health output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Json,

        [Parameter()]
        [int]$ExitCode = 0
    )

    $result = [ordered]@{
        AgentStatus   = $null
        AgentVersion  = $null
        LastHeartbeat = $null
        Status        = 'Unknown'
        Details       = ''
    }

    if ([string]::IsNullOrWhiteSpace($Json)) {
        $result.Details = "azcmagent show returned no output (exit code $ExitCode)."
        return [pscustomobject]$result
    }

    try {
        $data = $Json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $result.Details = "Unable to parse azcmagent show output as JSON (exit code $ExitCode)."
        return [pscustomobject]$result
    }

    $names = @($data.PSObject.Properties.Name)

    foreach ($candidate in 'status', 'agentStatus') {
        if ($names -contains $candidate -and $data.$candidate) {
            $result.AgentStatus = [string]$data.$candidate
            break
        }
    }

    if ($names -contains 'agentVersion') { $result.AgentVersion = [string]$data.agentVersion }
    if ($names -contains 'lastHeartbeat') { $result.LastHeartbeat = [string]$data.lastHeartbeat }

    $result.Status = switch ($result.AgentStatus) {
        'Connected'    { 'Healthy' }
        'Disconnected' { 'Critical' }
        'Expired'      { 'Critical' }
        'Error'        { 'Critical' }
        default        { 'Unknown' }
    }

    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add(("Agent status: {0}" -f $(if ($result.AgentStatus) { $result.AgentStatus } else { 'not reported' })))
    if ($result.AgentVersion) { $parts.Add(("Version: {0}" -f $result.AgentVersion)) }
    if ($result.LastHeartbeat) { $parts.Add(("Last heartbeat: {0}" -f $result.LastHeartbeat)) }
    if ($ExitCode -ne 0) { $parts.Add(("Exit code: {0}" -f $ExitCode)) }
    $result.Details = $parts -join '; '

    [pscustomobject]$result
}

function Get-AzureLocalArcAgentState {
    <#
    .SYNOPSIS
        Reports Azure Connected Machine agent connectivity. Read-only.

    .DESCRIPTION
        Looks for azcmagent in PATH, then in the default install location used
        on Azure Local nodes, runs `azcmagent show -j`, and classifies the
        reported status.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AzcmagentPath
    )

    if (-not $AzcmagentPath) {
        $command = Get-Command -Name 'azcmagent' -ErrorAction SilentlyContinue
        if ($command) {
            $AzcmagentPath = $command.Source
        }
        elseif ($env:ProgramFiles) {
            $defaultPath = Join-Path $env:ProgramFiles 'AzureConnectedMachineAgent\azcmagent.exe'
            if (Test-Path -LiteralPath $defaultPath) {
                $AzcmagentPath = $defaultPath
            }
        }
    }

    if (-not $AzcmagentPath -or -not (Test-Path -LiteralPath $AzcmagentPath)) {
        return [pscustomobject]@{
            AgentStatus   = $null
            AgentVersion  = $null
            LastHeartbeat = $null
            Status        = 'NotAvailable'
            Details       = 'azcmagent was not found in PATH or the default install location.'
        }
    }

    try {
        $output = & $AzcmagentPath show -j 2>$null
        $exitCode = $LASTEXITCODE
        ConvertFrom-AzureLocalArcAgentJson -Json (($output | Out-String).Trim()) -ExitCode $exitCode
    }
    catch {
        [pscustomobject]@{
            AgentStatus   = $null
            AgentVersion  = $null
            LastHeartbeat = $null
            Status        = 'Unknown'
            Details       = $_.Exception.Message
        }
    }
}
