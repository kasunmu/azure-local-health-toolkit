function Get-AzureLocalWdacStatus {
    <#
    .SYNOPSIS
        Classifies WDAC / Code Integrity enforcement values into a health status.

    .DESCRIPTION
        Azure Local applies a WDAC base policy in enforced mode by default, so
        anything other than enforced kernel-mode and user-mode Code Integrity
        is reported as a Warning rather than Healthy. Values outside the known
        range are reported as Unknown.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[int]]$KernelModeValue,

        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[int]]$UserModeValue
    )

    $known = 0, 1, 2

    if ($null -eq $KernelModeValue -or $null -eq $UserModeValue) {
        return 'Unknown'
    }

    if ($known -notcontains $KernelModeValue -or $known -notcontains $UserModeValue) {
        return 'Unknown'
    }

    if ($KernelModeValue -eq 2 -and $UserModeValue -eq 2) {
        return 'Healthy'
    }

    return 'Warning'
}

function Get-AzureLocalWdacState {
    <#
    .SYNOPSIS
        Reads WDAC / Code Integrity enforcement state from Win32_DeviceGuard.

    .DESCRIPTION
        Read-only. Returns kernel-mode and user-mode enforcement values, their
        friendly names, and a health status. If Win32_DeviceGuard cannot be
        queried, Status is NotAvailable and Error holds the reason.
    #>
    [CmdletBinding()]
    param()

    $modeMap = @{
        0 = 'Off'
        1 = 'Audit'
        2 = 'Enforced'
    }

    try {
        $deviceGuard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName 'Win32_DeviceGuard' -ErrorAction Stop

        $kernelValue = [int]$deviceGuard.CodeIntegrityPolicyEnforcementStatus
        $userValue = [int]$deviceGuard.UsermodeCodeIntegrityPolicyEnforcementStatus

        [pscustomobject]@{
            KernelModeValue = $kernelValue
            KernelMode      = if ($modeMap.ContainsKey($kernelValue)) { $modeMap[$kernelValue] } else { "Unknown ($kernelValue)" }
            UserModeValue   = $userValue
            UserMode        = if ($modeMap.ContainsKey($userValue)) { $modeMap[$userValue] } else { "Unknown ($userValue)" }
            Status          = Get-AzureLocalWdacStatus -KernelModeValue $kernelValue -UserModeValue $userValue
            Error           = $null
        }
    }
    catch {
        [pscustomobject]@{
            KernelModeValue = $null
            KernelMode      = 'Unknown'
            UserModeValue   = $null
            UserMode        = 'Unknown'
            Status          = 'NotAvailable'
            Error           = $_.Exception.Message
        }
    }
}
