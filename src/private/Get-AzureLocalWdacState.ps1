function Get-AzureLocalWdacState {
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
            Status          = if ($modeMap.ContainsKey($kernelValue) -and $modeMap.ContainsKey($userValue)) { 'Healthy' } else { 'Unknown' }
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
